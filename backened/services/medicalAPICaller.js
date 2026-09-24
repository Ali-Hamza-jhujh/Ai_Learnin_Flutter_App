// Medical API Caller — Unified service that orchestrates ALL external medical APIs
// Uses the existing, tested individual services instead of raw HTTP calls
// Handles ALL categories: Diseases, Drugs, Anatomy, Physiology, Lab Values, etc.

import { fetchPubMedPapers } from "./pubmedService.js";
import {
  fetchWikipediaData,
  fetchWikipediaPageImage,
  fetchWikipediaArticleImages,
  mapWikiSectionsToSchema,
} from "./wikipediaService.js";
import { fetchWikimediaImages } from "./wikimediaService.js";
import { fetchOpenFDAData } from "./openFDAService.js";
import { fetchRxNormData } from "./rxnormService.js";
import { fetchMedlinePlusData } from "./medlineService.js";
import { processTopicImages } from "./imagePipeline.js";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const slugify = (text) =>
  text
    .toString()
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^\w-]+/g, "")
    .replace(/--+/g, "-")
    .replace(/^-+/, "")
    .replace(/-+$/, "");

const generateKeywords = (title, category) => {
  const words = title.toLowerCase().split(/\s+/);
  const keywords = [title.toLowerCase()];
  if (words.length > 1) keywords.push(...words);

  const categoryKeywords = {
    Diseases: ["disease", "disorder", "symptoms", "condition"],
    Drugs: ["medication", "drug", "pill", "medicine"],
    Anatomy: ["anatomy", "structure", "body"],
    Physiology: ["physiology", "function", "process"],
    Biochemistry: ["biochemistry", "enzyme", "pathway"],
    Histology: ["histology", "tissue", "cell"],
    Pharmacology: ["pharmacology", "drug action", "mechanism"],
    "Lab Values": ["lab", "test", "value", "result"],
    Procedures: ["procedure", "surgery", "operation"],
    "Clinical Concepts": ["clinical", "concept", "diagnosis"],
  };

  if (categoryKeywords[category]) {
    keywords.push(...categoryKeywords[category]);
  }

  return [...new Set(keywords)];
};

// ─── Main Orchestrator ────────────────────────────────────────────────────────

/**
 * Fetches COMPLETE medical data for any topic from ALL relevant external APIs.
 * Returns a fully populated object ready to save to DictionaryItem.
 *
 * @param {string} title - Human-readable topic name (e.g. "Diabetes", "Metformin")
 * @param {string} category - Detected category (e.g. "Diseases", "Drugs")
 * @returns {Object} Complete data object matching DictionaryItem schema
 */
export async function fetchCompleteTopicData(title, category) {
  console.log(`\n🔍 [MedicalAPICaller] Fetching COMPLETE data for: "${title}" (${category})\n`);

  const slug = slugify(title);
  const dataSource = {
    medlineplus: false,
    wikipedia: false,
    wikimedia: false,
    pubmed: false,
    openfda: false,
    rxnorm: false,
    lastSyncedAt: new Date(),
  };

  // Start with defaults
  let resolvedTitle = title;
  let description = `${title} — Medical reference entry under ${category}`;
  let overview = { definition: "", classification: "", synonyms: [], icdCodes: [] };
  let clinicalInfo = {};
  let rawImages = [];
  let references = [];
  let researchPapers = [];
  let relatedTopics = [];

  // ───────────────────────────────────────────────────────────────────────────
  // Phase 1: Category-specific API calls
  // ───────────────────────────────────────────────────────────────────────────

  if (category === "Drugs") {
    // RxNorm for drug identification
    try {
      const rxNorm = await fetchRxNormData(title);
      if (rxNorm) {
        resolvedTitle = rxNorm.name || resolvedTitle;
        clinicalInfo.brandNames = rxNorm.brandNames || [];
        clinicalInfo.drugClass = rxNorm.drugClass || "";
        clinicalInfo.doseForms = rxNorm.doseForms || [];
        clinicalInfo.strength = rxNorm.strength || [];
        dataSource.rxnorm = true;
        console.log(`   ✅ RxNorm: Got ${rxNorm.brandNames?.length || 0} brand names`);
      }
    } catch (e) {
      console.log(`   ⚠️ RxNorm: ${e.message}`);
    }

    // OpenFDA for clinical drug data
    try {
      const fda = await fetchOpenFDAData(title);
      if (fda) {
        clinicalInfo.uses = fda.uses || [];
        clinicalInfo.warnings = fda.warnings || [];
        clinicalInfo.contraindications = fda.contraindications || [];
        clinicalInfo.sideEffects = fda.sideEffects || [];
        clinicalInfo.interactions = fda.interactions || [];
        dataSource.openfda = true;
        console.log(`   ✅ OpenFDA: Got uses, warnings, side effects`);
      }
    } catch (e) {
      console.log(`   ⚠️ OpenFDA: ${e.message}`);
    }
  } else if (category === "Diseases" || category === "Syndromes") {
    // MedlinePlus for official NIH data
    try {
      const medline = await fetchMedlinePlusData(title);
      if (medline) {
        resolvedTitle = medline.title || resolvedTitle;
        overview.definition = medline.definition || "";
        if (medline.icdCode) overview.icdCodes = [medline.icdCode];
        if (medline.url) {
          references.push({
            title: `${medline.title || title} — MedlinePlus`,
            source: "MedlinePlus (NIH Official)",
            url: medline.url,
            type: "government",
          });
        }
        dataSource.medlineplus = true;
        console.log(`   ✅ MedlinePlus: Got definition (${overview.definition.length} chars)`);
      }
    } catch (e) {
      console.log(`   ⚠️ MedlinePlus: ${e.message}`);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Phase 2: Wikipedia (works for ALL categories — richest free data source)
  // ───────────────────────────────────────────────────────────────────────────

  try {
    const wiki = await fetchWikipediaData(title);
    if (wiki) {
      resolvedTitle = wiki.title || resolvedTitle;

      // Use Wikipedia definition if we don't have one from MedlinePlus
      if (!overview.definition || overview.definition.length < 20) {
        overview.definition = wiki.definition || "";
      }

      // Generate a good description
      if (wiki.definition) {
        description = wiki.definition.length > 200
          ? wiki.definition.substring(0, 200) + "..."
          : wiki.definition;
      }

      // Extract REAL clinical data from Wikipedia sections
      const mappedInfo = mapWikiSectionsToSchema(wiki, category);
      clinicalInfo = { ...clinicalInfo, ...mappedInfo };

      // Add Wikipedia reference
      references.push({
        title: `${wiki.title} — Wikipedia`,
        source: "Wikipedia",
        url: `https://en.wikipedia.org/wiki/${encodeURIComponent(wiki.title)}`,
        type: "reference",
      });

      // Get main page image + article images (X-rays, CT scans, histology slides, diagrams)
      const pageImg = await fetchWikipediaPageImage(wiki.title);
      if (pageImg) rawImages.push(pageImg);

      const articleImgs = await fetchWikipediaArticleImages(wiki.title, 5);
      if (articleImgs && articleImgs.length > 0) {
        rawImages.push(...articleImgs);
      }

      dataSource.wikipedia = true;
      console.log(`   ✅ Wikipedia: Definition (${overview.definition.length} chars), ${Object.keys(mappedInfo).length} clinical sections, ${rawImages.length} images`);
    }
  } catch (e) {
    console.log(`   ⚠️ Wikipedia: ${e.message}`);
  }

  // Guarantee a definition exists
  if (!overview.definition || overview.definition.trim().length < 10) {
    overview.definition = `${resolvedTitle} is a medical topic classified under ${category}. Clinical information, research literature, and reference materials are provided below.`;
    description = overview.definition;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Phase 3: PubMed research papers (works for ALL categories)
  // ───────────────────────────────────────────────────────────────────────────

  try {
    researchPapers = await fetchPubMedPapers(resolvedTitle);
    if (researchPapers && researchPapers.length > 0) {
      dataSource.pubmed = true;
      console.log(`   ✅ PubMed: ${researchPapers.length} research papers with abstracts`);
    }
  } catch (e) {
    console.log(`   ⚠️ PubMed: ${e.message}`);
    researchPapers = [];
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Phase 4: Wikimedia Commons images (works for ALL categories)
  // ───────────────────────────────────────────────────────────────────────────

  try {
    const wikiImages = await fetchWikimediaImages(resolvedTitle, 3, category);
    if (wikiImages && wikiImages.length > 0) {
      rawImages.push(...wikiImages);
      dataSource.wikimedia = true;
      console.log(`   ✅ Wikimedia: ${wikiImages.length} medical images`);
    }
  } catch (e) {
    console.log(`   ⚠️ Wikimedia: ${e.message}`);
  }

  // Filter unique images by URL
  const uniqueImagesMap = new Map();
  for (const img of rawImages) {
    if (img.url && !uniqueImagesMap.has(img.url)) {
      uniqueImagesMap.set(img.url, img);
    }
  }
  const uniqueRawImages = Array.from(uniqueImagesMap.values());

  // ───────────────────────────────────────────────────────────────────────────
  // Phase 5: Upload images to Cloudinary (up to 5 images per topic)
  // ───────────────────────────────────────────────────────────────────────────

  let processedImages = [];
  if (uniqueRawImages.length > 0) {
    try {
      processedImages = await processTopicImages(uniqueRawImages.slice(0, 5), category, slug);
      console.log(`   ✅ Cloudinary: ${processedImages.length} images processed`);
    } catch (e) {
      console.log(`   ⚠️ Cloudinary upload failed, using raw URLs: ${e.message}`);
      processedImages = uniqueRawImages.slice(0, 5).map((img) => ({
        url: img.url,
        thumbnailUrl: img.thumbnailUrl || img.url,
        mediumUrl: img.mediumUrl || img.url,
        caption: img.caption || "Medical illustration",
        creator: img.creator || "Wikimedia Commons",
        license: img.license || "CC BY-SA 4.0",
        source: img.source || "Wikimedia Commons",
      }));
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Phase 6: Generate related topics
  // ───────────────────────────────────────────────────────────────────────────

  relatedTopics = generateRelatedTopics(resolvedTitle, category, clinicalInfo);

  // ───────────────────────────────────────────────────────────────────────────
  // Final assembly
  // ───────────────────────────────────────────────────────────────────────────

  const result = {
    title: resolvedTitle,
    slug,
    description,
    category,
    overview,
    clinicalInfo,
    images: processedImages,
    references,
    researchPapers,
    keywords: generateKeywords(resolvedTitle, category),
    relatedTopics,
    searchCount: 1,
    viewCount: 1,
    lastRefreshed: new Date(),
    dataSource,
  };

  console.log(`\n✨ [MedicalAPICaller] COMPLETE DATA SUMMARY for "${resolvedTitle}":`);
  console.log(`   • Definition:  ${overview.definition.length} chars`);
  console.log(`   • Clinical:    ${Object.keys(clinicalInfo).length} sections`);
  console.log(`   • Images:      ${processedImages.length}`);
  console.log(`   • Papers:      ${researchPapers.length}`);
  console.log(`   • References:  ${references.length}`);
  console.log(`   • Keywords:    ${result.keywords.length}`);
  console.log(`   • APIs used:   ${Object.entries(dataSource).filter(([k, v]) => v === true).map(([k]) => k).join(", ")}\n`);

  return result;
}

// ─── Related Topics Generator ─────────────────────────────────────────────────

function generateRelatedTopics(title, category, clinicalInfo) {
  const list = [];

  if (category === "Drugs") {
    if (clinicalInfo.drugClass) list.push(clinicalInfo.drugClass);
    list.push("Pharmacology", "Drug Interactions");
  } else if (category === "Diseases" || category === "Syndromes") {
    list.push("Pathology", "Internal Medicine");
    if (clinicalInfo.treatment?.length) list.push("Treatment Options");
    if (clinicalInfo.complications?.length) list.push("Complications");
  } else if (category === "Anatomy") {
    list.push("Physiology", "Gross Anatomy", "Clinical Anatomy");
  } else if (category === "Physiology") {
    list.push("Anatomy", "Biochemistry", "Homeostasis");
  } else if (category === "Biochemistry") {
    list.push("Physiology", "Metabolism", "Molecular Biology");
  } else if (category === "Lab Values") {
    list.push("Clinical Chemistry", "Diagnostic Testing");
  } else if (category === "Procedures") {
    list.push("Surgical Techniques", "Clinical Skills");
  } else if (category === "Histology") {
    list.push("Anatomy", "Pathology", "Cell Biology");
  } else {
    list.push("Clinical Medicine", "Medical Sciences");
  }

  return [...new Set(list)];
}

// ─── Quick Search (lighter, for search results) ──────────────────────────────

/**
 * Lighter version for search results — just Wikipedia + basic data.
 * Used when we need quick results without full API orchestration.
 */
export async function fetchQuickTopicData(title, category) {
  console.log(`⚡ [MedicalAPICaller] Quick fetch for: "${title}"`);

  const slug = slugify(title);
  let description = `${title} — ${category}`;
  let overview = { definition: "", classification: "", synonyms: [], icdCodes: [] };

  try {
    const wiki = await fetchWikipediaData(title);
    if (wiki) {
      overview.definition = wiki.definition || "";
      description = wiki.definition
        ? wiki.definition.substring(0, 200) + "..."
        : description;
    }
  } catch (e) {
    // Silent fallback
  }

  if (!overview.definition || overview.definition.length < 10) {
    overview.definition = `${title} is a medical topic classified under ${category}.`;
    description = overview.definition;
  }

  return {
    title,
    slug,
    description,
    category,
    overview,
    clinicalInfo: {},
    images: [],
    references: [],
    researchPapers: [],
    keywords: generateKeywords(title, category),
    relatedTopics: [],
    searchCount: 0,
    viewCount: 0,
    lastRefreshed: new Date(),
    dataSource: { lastSyncedAt: new Date() },
  };
}
