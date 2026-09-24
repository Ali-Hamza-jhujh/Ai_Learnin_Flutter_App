import axios from "axios";

const WIKI_HEADERS = {
  "User-Agent": "MedicalKnowledgeHub/1.0 (https://studyapp.com; contact@studyapp.com)",
};

export async function fetchWikipediaData(term) {
  const url = "https://en.wikipedia.org/w/api.php";
  try {
    // 1. Attempt exact title match with redirects
    let response = await axios.get(url, {
      params: {
        action: "query",
        titles: term,
        prop: "extracts",
        explaintext: true,
        format: "json",
        redirects: 1,
      },
      headers: WIKI_HEADERS,
      timeout: 7000,
    });

    let pages = response.data?.query?.pages;
    let pageId = pages ? Object.keys(pages)[0] : "-1";

    // 2. Fallback: Search Wikipedia for top matching article if title fails
    if (pageId === "-1") {
      let resolvedTerm = null;

      // Try opensearch first (great for prefix/typos)
      try {
        const openSearchRes = await axios.get(url, {
          params: {
            action: "opensearch",
            search: term,
            limit: 3,
            namespace: 0,
            format: "json",
          },
          headers: WIKI_HEADERS,
          timeout: 4000,
        });
        if (openSearchRes.data?.[1]?.length > 0) {
          resolvedTerm = openSearchRes.data[1][0];
        }
      } catch (e) {
        // ignore
      }

      // Try prefixsearch as second option
      if (!resolvedTerm) {
        try {
          const prefixRes = await axios.get(url, {
            params: {
              action: "query",
              list: "prefixsearch",
              pssearch: term,
              pslimit: 3,
              format: "json",
            },
            headers: WIKI_HEADERS,
            timeout: 4000,
          });
          const firstPrefix = prefixRes.data?.query?.prefixsearch?.[0]?.title;
          if (firstPrefix) {
            resolvedTerm = firstPrefix;
          }
        } catch (e) {
          // ignore
        }
      }

      // Try search suggestion as third option
      if (!resolvedTerm) {
        try {
          const suggestRes = await axios.get(url, {
            params: {
              action: "query",
              list: "search",
              srsearch: term,
              srinfo: "suggestion",
              format: "json",
              srlimit: 1,
            },
            headers: WIKI_HEADERS,
            timeout: 4000,
          });
          const suggestion = suggestRes.data?.query?.searchinfo?.suggestion;
          if (suggestion) {
            resolvedTerm = suggestion;
          } else {
            // Fallback to top hit from search list if any
            const topHit = suggestRes.data?.query?.search?.[0]?.title;
            if (topHit) {
              resolvedTerm = topHit;
            }
          }
        } catch (e) {
          // ignore
        }
      }

      // Final fallback: original search with keywords
      if (!resolvedTerm) {
        try {
          const searchRes = await axios.get(url, {
            params: {
              action: "query",
              list: "search",
              srsearch: `${term} medicine health`,
              format: "json",
              srlimit: 1,
            },
            headers: WIKI_HEADERS,
            timeout: 5000,
          });
          resolvedTerm = searchRes.data?.query?.search?.[0]?.title;
        } catch (e) {
          // ignore
        }
      }

      // If we resolved to a valid term, query the full page content
      if (resolvedTerm) {
        response = await axios.get(url, {
          params: {
            action: "query",
            titles: resolvedTerm,
            prop: "extracts",
            explaintext: true,
            format: "json",
            redirects: 1,
          },
          headers: WIKI_HEADERS,
          timeout: 7000,
        });
        pages = response.data?.query?.pages;
        pageId = pages ? Object.keys(pages)[0] : "-1";
      }
    }

    if (!pages || pageId === "-1") return null;

    const page = pages[pageId];
    const fullText = page.extract || "";
    const title = page.title || term;

    // Get intro definition (text before the first section header "==")
    const introEnd = fullText.indexOf("\n==");
    const definition = introEnd !== -1 ? fullText.substring(0, introEnd).trim() : fullText.trim();

    // Parse sections
    const sections = parseWikipediaSections(fullText);

    return {
      title,
      definition,
      sections,
    };
  } catch (error) {
    console.error("❌ Wikipedia API Error:", error.message);
    return null;
  }
}

export async function fetchWikipediaPageImage(title) {
  const url = "https://en.wikipedia.org/w/api.php";
  try {
    const response = await axios.get(url, {
      params: {
        action: "query",
        titles: title,
        prop: "pageimages",
        piprop: "original|thumbnail",
        pithumbsize: 800,
        format: "json",
      },
      headers: WIKI_HEADERS,
      timeout: 7000,
    });

    const pages = response.data?.query?.pages;
    if (!pages) return null;
    const pageId = Object.keys(pages)[0];
    const page = pages[pageId];
    const imgUrl = page?.thumbnail?.source || page?.original?.source;

    if (imgUrl) {
      return {
        url: imgUrl,
        caption: `Clinical diagram for ${title}`,
        source: "Wikipedia",
      };
    }
    return null;
  } catch (error) {
    console.error("❌ Wikipedia Page Image Error:", error.message);
    return null;
  }
}

// ── Medical image relevance helpers ──────────────────────────────────────────

const NON_MEDICAL_BLOCKLIST = [
  // Wikipedia UI / metadata images
  "commons-logo", "ambox", "crystal", "nuvola", "wikimedia", "wikidata",
  "disambig", "merge", "unbalanced", "speedy", "cleanup", "stub",
  "notification", "ballot", "check mark", "red x", "green tick",
  "padlock", "lock-", "info", "question", "edit", "folder",
  "featured", "star-", "cscr-", "increase", "decrease", "steady",
  "audio", "sound", "speaker", "magnifying", "metadata", "search",
  // Non-medical content
  "gate", "building", "monument", "architecture", "city", "skyline",
  "landscape", "portrait", "painting", "cartoon", "caricature",
  "coat of arms", "stamp", "medal", "ribbon", "trophy",
  "map of", "location map", "relief map", "political map",
  "logo", "icon", "flag", "symbol", "banner", "emblem",
  "headache", "head ache", // Cruikshank cartoon specifically
  "cruikshank", "cruickshank",
  "fortifikation", "fortification (migr", // Brandenburg Gate/migraine art
  "brandenburg",
];

const MEDICAL_IMAGE_KEYWORDS = [
  "diagram", "anatomy", "histolog", "ct scan", "ct-scan", "mri",
  "x-ray", "xray", "radiograph", "scan", "microscop", "patholog",
  "clinical", "medical", "cross-section", "cross section", "illustration",
  "cell", "tissue", "organ", "brain", "nerve", "muscle", "artery", "vein",
  "bone", "skeletal", "cardiac", "pulmonary", "renal", "hepatic",
  "gastric", "dermat", "ophthal", "neur", "pharmac",
  "lesion", "tumor", "tumour", "biopsy", "stain", "slide",
  "electrocardiogram", "ecg", "eeg", "emg",
  "ultrasound", "sonograph", "doppler", "angiograph",
  "endoscop", "arthroscop", "laparoscop",
  "anterior", "posterior", "lateral", "medial", "superior", "inferior",
  "sagittal", "coronal", "transverse", "axial",
  "dissection", "cadaver", "specimen", "section",
  "symptom", "sign", "rash", "swelling", "inflammation",
  "fracture", "dislocation", "wound", "incision",
  "blood", "vessel", "capillary", "lymph",
  "surgical", "procedure", "technique", "operation",
  "aura", "migraine", "headache", // actual medical visualizations
  "visual field", "scotoma", "photophobia",
  "fiber", "fibre", "tendon", "ligament", "fascia", "insertion", "origin",
  "surface anatomy", "gray", "netter", "sobotta", "atlas",
];

function isMedicallyRelevant(filename, caption) {
  const combined = `${filename} ${caption}`.toLowerCase();

  // Block non-medical images
  for (const blocked of NON_MEDICAL_BLOCKLIST) {
    if (combined.includes(blocked)) return { relevant: false, score: -1 };
  }

  // Must be an actual image file
  const ext = filename.split(".").pop().toLowerCase().split("?")[0];
  if (!["jpg", "jpeg", "png", "webp", "svg"].includes(ext)) {
    return { relevant: false, score: -1 };
  }

  // Score by medical keyword matches
  let score = 0;
  for (const kw of MEDICAL_IMAGE_KEYWORDS) {
    if (combined.includes(kw)) score += 1;
  }

  // Baseline: even without medical keywords, allow images that aren't blocked
  // (they might be relevant clinical photos without obvious keywords)
  return { relevant: true, score };
}

export async function fetchWikipediaArticleImages(title, limit = 5) {
  const url = "https://en.wikipedia.org/w/api.php";
  try {
    const imagesRes = await axios.get(url, {
      params: {
        action: "query",
        titles: title,
        prop: "images",
        imlimit: 50,  // Fetch more so we can filter aggressively
        format: "json",
        redirects: 1,
      },
      headers: WIKI_HEADERS,
      timeout: 7000,
    });

    const pages = imagesRes.data?.query?.pages || {};
    const pageId = Object.keys(pages)[0];
    if (pageId === "-1") return [];

    const rawImages = pages[pageId]?.images || [];
    
    // Filter using medical relevance check
    const scoredFiles = rawImages
      .map(img => {
        const { relevant, score } = isMedicallyRelevant(img.title, "");
        return { ...img, relevant, score };
      })
      .filter(img => img.relevant)
      .sort((a, b) => b.score - a.score);  // Most medically relevant first

    if (scoredFiles.length === 0) return [];

    // Fetch info for top candidates (get more than limit to re-score with captions)
    const candidateCount = Math.min(scoredFiles.length, limit * 3);
    const fileTitles = scoredFiles.slice(0, candidateCount).map(f => f.title).join("|");
    const infoRes = await axios.get(url, {
      params: {
        action: "query",
        titles: fileTitles,
        prop: "imageinfo",
        iiprop: "url|extmetadata",
        iiurlwidth: 800,
        format: "json",
      },
      headers: WIKI_HEADERS,
      timeout: 7000,
    });

    const infoPages = infoRes.data?.query?.pages || {};
    const candidateImages = [];

    for (const id of Object.keys(infoPages)) {
      const p = infoPages[id];
      const info = p.imageinfo?.[0];
      if (info && info.url) {
        const metadata = info.extmetadata || {};
        const rawCaption = metadata.ObjectName?.value || metadata.ImageDescription?.value || p.title.replace("File:", "").replace(/\.\w+$/, "");
        const cleanCaption = rawCaption.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();

        // Re-check with full caption for better filtering
        const { relevant, score } = isMedicallyRelevant(p.title || "", cleanCaption);
        if (!relevant) continue;

        candidateImages.push({
          url: info.url,
          thumbnailUrl: info.thumburl || info.url,
          mediumUrl: info.thumburl || info.url,
          caption: cleanCaption.substring(0, 150) || `Medical diagram for ${title}`,
          creator: metadata.Artist?.value?.replace(/<[^>]*>/g, "") || "Wikipedia Medical",
          license: metadata.LicenseShortName?.value || "CC BY-SA 4.0",
          source: "Wikipedia Article",
          _relevanceScore: score,
        });
      }
    }

    // Sort by relevance score and return top results
    candidateImages.sort((a, b) => b._relevanceScore - a._relevanceScore);
    return candidateImages.slice(0, limit).map(({ _relevanceScore, ...img }) => img);
  } catch (e) {
    console.error("❌ Wikipedia Article Images Error:", e.message);
    return [];
  }
}

function parseWikipediaSections(text) {
  const sections = {};
  const regex = /^==+\s*(.*?)\s*==+/gm;
  let match;
  const matches = [];

  while ((match = regex.exec(text)) !== null) {
    matches.push({
      title: match[1].trim().toLowerCase(),
      index: match.index,
      headerLength: match[0].length,
    });
  }

  for (let i = 0; i < matches.length; i++) {
    const start = matches[i].index + matches[i].headerLength;
    const end = i + 1 < matches.length ? matches[i + 1].index : text.length;
    const sectionText = text.substring(start, end).trim();
    sections[matches[i].title] = sectionText;
  }

  return sections;
}

export function mapWikiSectionsToSchema(wikiData, category) {
  const sections = wikiData.sections || {};
  const definition = wikiData.definition || "";
  const clinicalInfo = {};

  // ── helpers ──────────────────────────────────────────────────────────────────

  const findSection = (...keywordSets) => {
    for (const keywords of keywordSets) {
      for (const key of Object.keys(sections)) {
        if (keywords.some(kw => key.toLowerCase().includes(kw))) {
          return sections[key];
        }
      }
    }
    return null;
  };

  const splitIntoPoints = (text, limit = 15) => {
    if (!text) return [];
    // Split on newlines or sentence boundaries
    return text
      .split(/\n+|\. (?=[A-Z])/)
      .map(p => p.replace(/^[=\s*•-]+/, "").trim())
      .filter(p => p.length > 8 && !p.startsWith("==") && !p.startsWith("{{") && !p.startsWith("See also") && !p.startsWith("Main article"))
      .slice(0, limit);
  };

  const firstParagraph = (text, maxChars = 1000) => {
    if (!text) return "";
    const para = text.split("\n\n")[0] || text;
    return para.trim().substring(0, maxChars);
  };

  // ── Category-specific mapping ─────────────────────────────────────────────

  if (category === "Diseases" || category === "Syndromes") {
    clinicalInfo.symptoms = splitIntoPoints(
      findSection(["symptom", "sign", "presentation", "clinical feature", "manifestation", "clinical manifestation"])
    );
    clinicalInfo.causes = splitIntoPoints(
      findSection(["cause", "etiology", "aetiology", "risk factor", "pathogenesis", "pathophysiology", "mechanism"])
    );
    clinicalInfo.diagnosis = splitIntoPoints(
      findSection(["diagnos", "workup", "test", "investigation", "differential", "evaluation", "assessment", "criteria"])
    );
    clinicalInfo.treatment = splitIntoPoints(
      findSection(["treatment", "management", "therapy", "intervention", "medication", "pharmacotherapy", "surgical"])
    );
    clinicalInfo.complications = splitIntoPoints(
      findSection(["complication", "prognosis", "outcome", "sequela", "morbidity", "mortality"])
    );
    clinicalInfo.prevention = splitIntoPoints(
      findSection(["prevention", "prophylaxis", "screening", "vaccination", "immunization"])
    );
    // Epidemiology as extra context in clinicalImportance
    const epidText = findSection(["epidemiology", "prevalence", "incidence", "demographics", "distribution"]);
    if (epidText) {
      clinicalInfo.clinicalImportance = firstParagraph(epidText, 800);
    }
    // Synonym / classification from overview
    if (category === "Syndromes") {
      clinicalInfo.functions = splitIntoPoints(
        findSection(["feature", "characteristic", "manifestation", "hallmark"])
      );
    }

  } else if (category === "Anatomy" || category === "Body Systems") {
    // Try multiple section heading variants that Wikipedia uses
    const structureText = findSection(
      ["structure", "anatomy", "course", "location", "description", "gross anatomy", "topography"],
      ["relation", "surface", "position", "attachment", "composition"]
    );
    const functionText = findSection(
      ["function", "role", "action", "physiology", "movement"],
      ["biomechanic", "contraction", "activity"]
    );
    const clinicalText = findSection(
      ["clinical significance", "clinical relevance", "injury", "applied", "importance", "pathology", "disease"],
      ["disorder", "clinical", "surgical"]
    );
    const bloodText = findSection(["blood supply", "blood", "vasculature", "arterial", "venous"]);
    const nerveText = findSection(["nerve supply", "innervation", "nerve", "neural"]);
    const developText = findSection(["development", "embryology", "embryo"]);
    const variationText = findSection(["variation", "variant", "anomal"]);

    clinicalInfo.origin      = extractAnatomicalTerm(structureText, ["originates", "arises from", "origin:", "origin ", "proximal attachment", "originat"]);
    clinicalInfo.insertion   = extractAnatomicalTerm(structureText, ["inserts", "attaches to", "insertion:", "insertion ", "distal attachment", "insert"]);
    clinicalInfo.bloodSupply = extractAnatomicalTerm(bloodText || structureText, ["blood supply", "artery", "arterial supply", "arterial", "vascular", "supplied by"]);
    clinicalInfo.nerveSupply = extractAnatomicalTerm(nerveText || structureText, ["nerve", "innervation", "innervated by", "supplied by", "motor nerve", "sensory nerve"]);
    clinicalInfo.functions   = splitIntoPoints(functionText);
    clinicalInfo.clinicalImportance = firstParagraph(clinicalText, 1000);
    clinicalInfo.symptoms    = splitIntoPoints(findSection(["disorder", "disease", "condition", "abnormality", "pathology", "injury", "fracture", "tear", "rupture"]));

    // If functions empty, try to extract from structure text (some articles embed function info there)
    if ((!clinicalInfo.functions || clinicalInfo.functions.length === 0) && structureText) {
      const funcSentences = structureText.split(/\. (?=[A-Z])/)
        .filter(s => /function|role|action|movement|flex|extend|abduct|adduct|rotat|contract|stabil/i.test(s))
        .map(s => s.trim())
        .filter(s => s.length > 8);
      if (funcSentences.length > 0) clinicalInfo.functions = funcSentences.slice(0, 10);
    }

    // Add development and variation info if available
    if (developText) {
      clinicalInfo.development = firstParagraph(developText, 500);
    }
    if (variationText) {
      clinicalInfo.variations = firstParagraph(variationText, 500);
    }

  } else if (category === "Physiology") {
    clinicalInfo.functions   = splitIntoPoints(findSection(["function", "role", "process", "mechanism", "overview", "description", "step", "phase"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["regulation", "control", "feedback", "modulation", "stimulus", "trigger", "factor"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["clinical", "significance", "application", "relevance", "medical", "therapeutic"]));
    clinicalInfo.complications = splitIntoPoints(findSection(["disorder", "abnormality", "pathology", "dysfunction", "failure", "impairment"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["clinical significance", "importance", "medical significance"]), 800
    );

  } else if (category === "Biochemistry") {
    clinicalInfo.functions   = splitIntoPoints(findSection(["function", "role", "reaction", "pathway", "process", "step", "overview", "description"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["mechanism", "enzyme", "substrate", "product", "cofactor", "coenzyme", "catalyst"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["clinical", "significance", "disease", "disorder", "medical", "therapeutic"]));
    clinicalInfo.symptoms    = splitIntoPoints(findSection(["deficiency", "excess", "abnormality", "disorder", "toxicity", "poisoning"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["clinical significance", "importance", "application", "medical significance"]), 800
    );
    clinicalInfo.normalRange = firstParagraph(findSection(["normal", "reference", "level", "concentration", "serum"]), 500);

  } else if (category === "Histology") {
    clinicalInfo.functions   = splitIntoPoints(findSection(["function", "role", "characteristic", "feature", "property"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["structure", "composition", "layer", "cell type", "component", "matrix", "classification"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["staining", "microscopy", "appearance", "identification", "histochemistry"]));
    clinicalInfo.symptoms    = splitIntoPoints(findSection(["pathology", "abnormality", "disease", "disorder", "neoplasm", "tumor", "cancer"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["clinical significance", "importance", "application", "clinical relevance"]), 800
    );

  } else if (category === "Pharmacology") {
    clinicalInfo.uses        = splitIntoPoints(findSection(["use", "indication", "application", "treatment", "therapeutic", "approved"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["mechanism", "action", "pharmacodynamic", "receptor", "target", "binding"]));
    clinicalInfo.functions   = splitIntoPoints(findSection(["pharmacokinetic", "absorption", "distribution", "metabolism", "excretion", "adme", "bioavailability", "half-life"]));
    clinicalInfo.sideEffects = splitIntoPoints(findSection(["side effect", "adverse", "toxicity", "unwanted", "reaction"]));
    clinicalInfo.contraindications = splitIntoPoints(findSection(["contraindication", "warning", "precaution", "caution", "interaction"]));
    clinicalInfo.drugClass   = firstParagraph(findSection(["class", "classification", "group", "category"]), 300);
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["clinical significance", "importance", "clinical use"]), 800
    );

  } else if (category === "Drugs") {
    // Drug-specific clinical data supplemented by OpenFDA / RxNorm in Phase 1 —
    // Wikipedia fills in remaining sections
    clinicalInfo.causes      = splitIntoPoints(findSection(["mechanism", "action", "pharmacodynamic", "mode of action"]));
    clinicalInfo.functions   = splitIntoPoints(findSection(["pharmacokinetic", "absorption", "distribution", "metabolism", "excretion", "adme"]));
    clinicalInfo.symptoms    = splitIntoPoints(findSection(["overdose", "poisoning", "toxicity", "toxic"]));
    if (!clinicalInfo.uses || clinicalInfo.uses.length === 0) {
      clinicalInfo.uses      = splitIntoPoints(findSection(["use", "indication", "approved", "therapeutic", "medical use"]));
    }
    if (!clinicalInfo.sideEffects || clinicalInfo.sideEffects.length === 0) {
      clinicalInfo.sideEffects = splitIntoPoints(findSection(["side effect", "adverse", "reaction", "unwanted"]));
    }

  } else if (category === "Lab Values") {
    clinicalInfo.normalRange         = firstParagraph(findSection(["normal", "reference range", "level", "reference", "value"]), 500);
    clinicalInfo.clinicalSignificance = firstParagraph(
      findSection(["clinical significance", "interpretation", "use", "clinical use", "diagnostic"]), 800
    );
    clinicalInfo.highValues  = splitIntoPoints(findSection(["high", "elevated", "increase", "raised", "above normal"]));
    clinicalInfo.lowValues   = splitIntoPoints(findSection(["low", "decreased", "reduction", "deficiency", "below normal"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["cause", "etiology", "associated", "condition"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["management", "treatment", "correction", "therapy"]));

  } else if (category === "Procedures") {
    clinicalInfo.uses        = splitIntoPoints(findSection(["indication", "use", "purpose", "application", "reason"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["technique", "procedure", "step", "method", "approach", "protocol"]));
    clinicalInfo.complications = splitIntoPoints(findSection(["complication", "risk", "adverse", "contraindication", "hazard"]));
    clinicalInfo.functions   = splitIntoPoints(findSection(["preparation", "setup", "equipment", "prerequisite", "requirement"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["clinical significance", "importance", "outcome", "efficacy", "result"]), 800
    );

  } else if (category === "Clinical Concepts") {
    clinicalInfo.functions   = splitIntoPoints(findSection(["definition", "concept", "principle", "overview", "description"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["cause", "etiology", "mechanism", "pathophysiology"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["management", "application", "clinical use", "treatment", "therapy"]));
    clinicalInfo.symptoms    = splitIntoPoints(findSection(["feature", "presentation", "finding", "sign", "symptom", "criterion", "criteria"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["significance", "importance", "relevance", "clinical significance"]), 800
    );

  } else if (category === "Medical Images") {
    clinicalInfo.functions   = splitIntoPoints(findSection(["indication", "use", "application", "purpose", "diagnostic"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["technique", "procedure", "modality", "method", "protocol"]));
    clinicalInfo.complications = splitIntoPoints(findSection(["limitation", "contraindication", "risk", "artifact", "pitfall"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["clinical significance", "interpretation", "clinical use"]), 800
    );

  } else if (category === "Research Papers") {
    clinicalInfo.functions   = splitIntoPoints(findSection(["finding", "result", "conclusion", "outcome", "summary"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["method", "design", "population", "methodology"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["significance", "implication", "discussion", "impact"]), 800
    );

  } else {
    // Fallback: extract whatever Wikipedia has — with expanded keywords
    clinicalInfo.symptoms    = splitIntoPoints(findSection(["symptom", "sign", "presentation", "feature", "manifestation", "finding"]));
    clinicalInfo.causes      = splitIntoPoints(findSection(["cause", "mechanism", "etiology", "pathogenesis", "pathophysiology"]));
    clinicalInfo.treatment   = splitIntoPoints(findSection(["treatment", "management", "therapy", "intervention", "medication"]));
    clinicalInfo.functions   = splitIntoPoints(findSection(["function", "role", "purpose", "action", "overview", "description"]));
    clinicalInfo.complications = splitIntoPoints(findSection(["complication", "risk", "adverse", "prognosis", "outcome"]));
    clinicalInfo.clinicalImportance = firstParagraph(
      findSection(["significance", "importance", "application", "clinical significance", "relevance"]), 800
    );
  }

  // ── Fallback: if major sections are empty, try extracting from full text ──
  const majorEmpty = !clinicalInfo.functions?.length && !clinicalInfo.symptoms?.length && !clinicalInfo.causes?.length && !clinicalInfo.treatment?.length;
  if (majorEmpty && definition && definition.length > 100) {
    // Split definition into meaningful sentences as "functions" fallback
    const defPoints = definition
      .split(/\. (?=[A-Z])/)
      .map(s => s.trim())
      .filter(s => s.length > 15)
      .slice(0, 8);
    if (defPoints.length > 0) {
      clinicalInfo.functions = defPoints;
    }
  }

  // ── Universal: if definition is long, use it to seed missing clinical importance ──
  if ((!clinicalInfo.clinicalImportance || clinicalInfo.clinicalImportance.length < 20) && definition.length > 200) {
    clinicalInfo.clinicalImportance = definition.substring(0, 500);
  }

  // ── Strip empty arrays/strings to avoid polluting DB ──
  for (const key of Object.keys(clinicalInfo)) {
    if (Array.isArray(clinicalInfo[key]) && clinicalInfo[key].length === 0) {
      delete clinicalInfo[key];
    } else if (typeof clinicalInfo[key] === "string" && clinicalInfo[key].trim() === "") {
      delete clinicalInfo[key];
    }
  }

  return clinicalInfo;
}

function extractAnatomicalTerm(text, triggers) {
  if (!text) return "";
  // Try splitting by sentences first for more precise extraction
  const sentences = text.split(/\. (?=[A-Z])/).map(s => s.trim()).filter(s => s.length > 5);
  for (const sentence of sentences) {
    for (const trigger of triggers) {
      if (sentence.toLowerCase().includes(trigger)) {
        return sentence.substring(0, 200);
      }
    }
  }
  // Fallback: try line-by-line
  const lines = text.split("\n").filter(l => l.trim().length > 5);
  for (const line of lines) {
    for (const trigger of triggers) {
      if (line.toLowerCase().includes(trigger)) {
        return line.trim().substring(0, 200);
      }
    }
  }
  return lines[0]?.trim().substring(0, 200) || "";
}
