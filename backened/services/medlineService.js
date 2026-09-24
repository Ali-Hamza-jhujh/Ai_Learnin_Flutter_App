import axios from "axios";

export async function fetchMedlinePlusData(term, icdCode = null) {
  const baseUrl = "https://connect.medlineplus.gov/service";
  try {
    const params = {
      "informationRecipient.languageCode.c": "en",
      "replyMimeType": "application/json",
    };

    if (icdCode) {
      params["mainSearchCriteria.v.cs"] = "2.16.840.1.113883.6.90";
      params["mainSearchCriteria.v.c"] = icdCode;
    } else {
      params["mainSearchCriteria.v.cs"] = "2.16.840.1.113883.6.90";
      params["mainSearchCriteria.v.ky"] = term;
    }

    const response = await axios.get(baseUrl, { params, timeout: 5000 });
    const feed = response.data?.feed;
    const entries = feed?.entry || [];

    if (entries.length === 0) {
      return null;
    }

    // Extract title, definition/summary, and HTML links
    const firstEntry = entries[0];
    const title = firstEntry.title?._value || term;
    
    // Parse summary (strip HTML tags)
    const rawSummary = firstEntry.summary?._value || "";
    const summaryCleaned = rawSummary.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();

    // Try to extract symptoms, causes from summary or sub-sections if they exist
    // Otherwise we'll rely on Wikipedia fallback to populate detailed sections.
    const url = firstEntry.link?.find(l => l.rel === "alternate")?.href || "";

    return {
      title,
      definition: summaryCleaned,
      icdCode: icdCode || extractICDCode(firstEntry),
      url,
    };
  } catch (error) {
    console.error("❌ Medline Plus API Error:", error.message);
    return null;
  }
}

function extractICDCode(entry) {
  // Try to find ICD code in category or id fields if present
  const categories = entry.category || [];
  for (const cat of categories) {
    if (cat.scheme?.includes("ICD-10") || cat.term?.match(/^[A-Z]\d{2}/)) {
      return cat.term;
    }
  }
  return null;
}
