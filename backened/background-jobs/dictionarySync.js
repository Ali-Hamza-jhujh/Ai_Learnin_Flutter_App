import prisma from "../prisma.js";
import { fetchRxNormData } from "../services/rxnormService.js";
import { fetchOpenFDAData } from "../services/openFDAService.js";
import { fetchMedlinePlusData } from "../services/medlineService.js";
import { fetchPubMedPapers } from "../services/pubmedService.js";
import { fetchWikipediaData, fetchWikipediaPageImage, mapWikiSectionsToSchema } from "../services/wikipediaService.js";
import { fetchWikimediaImages } from "../services/wikimediaService.js";
import { processTopicImages } from "../services/imagePipeline.js";

export async function refreshStaleDictionaryItems() {
  console.log("🔄 Running Background Job: Refreshing Stale Medical Dictionary Items...");
  
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  try {
    const staleItems = await prisma.dictionaryItem.findMany({
      where: {
        lastRefreshed: { lt: thirtyDaysAgo },
      },
      take: 5,
    });

    console.log(`🔄 Found ${staleItems.length} stale dictionary items to update.`);

    for (const item of staleItems) {
      console.log(`🔄 Refreshing topic: ${item.title} (${item.category})`);
      
      let title = item.title;
      let clinicalInfo = typeof item.clinicalInfo === 'object' && item.clinicalInfo !== null ? { ...item.clinicalInfo } : {};
      let overview = typeof item.overview === 'object' && item.overview !== null ? { ...item.overview } : {};
      let rawImages = [];
      let researchPapers = Array.isArray(item.researchPapers) ? [...item.researchPapers] : [];
      let images = Array.isArray(item.images) ? [...item.images] : [];

      if (item.category === "Drugs") {
        const rxNorm = await fetchRxNormData(title);
        if (rxNorm) {
          clinicalInfo.brandNames = rxNorm.brandNames;
          clinicalInfo.drugClass = rxNorm.drugClass;
          clinicalInfo.doseForms = rxNorm.doseForms;
          clinicalInfo.strength = rxNorm.strength;
        }

        const fda = await fetchOpenFDAData(title);
        if (fda) {
          clinicalInfo.uses = fda.uses;
          clinicalInfo.warnings = fda.warnings;
          clinicalInfo.contraindications = fda.contraindications;
          clinicalInfo.sideEffects = fda.sideEffects;
          clinicalInfo.interactions = fda.interactions;
        }
      } else if (item.category === "Diseases") {
        const icd = overview.icdCodes?.[0] || null;
        const medline = await fetchMedlinePlusData(title, icd);
        if (medline) {
          overview.definition = medline.definition;
          if (medline.icdCode) {
            overview.icdCodes = [medline.icdCode];
          }
        }
      }

      const wiki = await fetchWikipediaData(title);
      if (wiki) {
        overview.definition = wiki.definition;
        const mappedInfo = mapWikiSectionsToSchema(wiki, item.category);
        clinicalInfo = { ...clinicalInfo, ...mappedInfo };
        
        const pageImg = await fetchWikipediaPageImage(wiki.title);
        if (pageImg) rawImages.push(pageImg);
      }

      const papers = await fetchPubMedPapers(title);
      if (papers && papers.length > 0) {
        researchPapers = papers;
      }

      if (images.length === 0) {
        const wikiCommonsImgs = await fetchWikimediaImages(title, 2);
        rawImages.push(...wikiCommonsImgs);
        if (rawImages.length > 0) {
          const processed = await processTopicImages(rawImages, item.category, item.slug);
          if (processed.length > 0) {
            images = processed;
          }
        }
      }

      await prisma.dictionaryItem.update({
        where: { id: item.id },
        data: {
          clinicalInfo,
          overview,
          researchPapers,
          images,
          lastRefreshed: new Date(),
        },
      });

      console.log(`✅ Successfully refreshed topic: ${item.title}`);
    }
  } catch (error) {
    console.error("❌ Background refresh job error:", error);
  }
}

export function startDictionarySyncJob() {
  setInterval(refreshStaleDictionaryItems, 12 * 60 * 60 * 1000);
}
