import axios from "axios";

const WIKI_HEADERS = {
  "User-Agent": "MedicalKnowledgeHub/1.0 (https://studyapp.com; contact@studyapp.com)",
};

// ── Non-medical image blocklist (shared logic with wikipediaService) ─────────

const NON_MEDICAL_BLOCKLIST = [
  "commons-logo", "ambox", "crystal", "nuvola", "wikimedia", "wikidata",
  "disambig", "merge", "unbalanced", "speedy", "cleanup", "stub",
  "notification", "ballot", "check mark", "red x", "green tick",
  "padlock", "lock-", "info", "question", "edit", "folder",
  "featured", "star-", "cscr-", "increase", "decrease", "steady",
  "audio", "sound", "speaker", "magnifying", "metadata", "search",
  "gate", "building", "monument", "architecture", "city", "skyline",
  "landscape", "portrait", "painting", "cartoon", "caricature",
  "coat of arms", "stamp", "medal", "ribbon", "trophy",
  "map of", "location map", "relief map", "political map",
  "logo", "icon", "flag", "symbol", "banner", "emblem",
  "cruikshank", "cruickshank", "fortifikation", "brandenburg",
];

// ── Category-aware search query builder ─────────────────────────────────────

function buildMedicalSearchQuery(query, category) {
  const categoryTerms = {
    "Diseases":             "clinical pathophysiology symptoms diagnosis",
    "Syndromes":            "clinical syndrome medical features",
    "Drugs":                "pharmaceutical chemical structure molecular",
    "Pharmacology":         "pharmacology mechanism receptor drug",
    "Anatomy":              "anatomical diagram structure cross-section",
    "Body Systems":         "anatomical system organ diagram",
    "Physiology":           "physiology mechanism biological process",
    "Biochemistry":         "biochemistry pathway molecular structure",
    "Histology":            "histology microscopy tissue staining",
    "Lab Values":           "laboratory test clinical diagnostic",
    "Procedures":           "surgical procedure medical technique",
    "Clinical Concepts":    "clinical medical concept diagram",
    "Medical Images":       "medical imaging radiograph scan",
  };

  const suffix = categoryTerms[category] || "medical clinical diagram";
  return `${query} ${suffix}`;
}

function isImageMedicallyRelevant(filename, caption) {
  const combined = `${filename} ${caption}`.toLowerCase();

  for (const blocked of NON_MEDICAL_BLOCKLIST) {
    if (combined.includes(blocked)) return false;
  }

  const ext = filename.split(".").pop().toLowerCase().split("?")[0];
  if (!["jpg", "jpeg", "png", "webp", "svg"].includes(ext)) return false;

  return true;
}

export async function fetchWikimediaImages(query, limit = 3, category = "") {
  const searchQuery = buildMedicalSearchQuery(query, category);

  // First try Wikipedia API image search (extremely reliable, zero connection resets)
  try {
    const wikiUrl = "https://en.wikipedia.org/w/api.php";
    const response = await axios.get(wikiUrl, {
      params: {
        action: "query",
        generator: "search",
        gsrsearch: searchQuery,
        gsrnamespace: 6,
        gsrlimit: 20,  // Fetch more candidates for better filtering
        prop: "imageinfo",
        iiprop: "url|extmetadata",
        iiurlwidth: 800,
        format: "json",
      },
      headers: WIKI_HEADERS,
      timeout: 6000,
    });

    const pages = response.data?.query?.pages;
    if (pages) {
      const imgs = parsePages(pages, limit);
      if (imgs.length > 0) return imgs;
    }
  } catch (e) {
    // proceed to commons fallback
  }

  // Second try Commons Wikimedia API with medical category filter
  const url = "https://commons.wikimedia.org/w/api.php";
  try {
    const response = await axios.get(url, {
      params: {
        action: "query",
        generator: "search",
        gsrsearch: searchQuery,
        gsrnamespace: 6,
        gsrlimit: 20,
        prop: "imageinfo",
        iiprop: "url|extmetadata",
        iiurlwidth: 800,
        format: "json",
      },
      headers: WIKI_HEADERS,
      timeout: 6000,
    });

    const pages = response.data?.query?.pages;
    if (pages) return parsePages(pages, limit);
  } catch (error) {
    console.error("⚠️ Wikimedia Commons Notice:", error.message);
  }

  return [];
}

function parsePages(pages, limit) {
  const images = [];
  for (const key of Object.keys(pages)) {
    const page = pages[key];
    const info = page.imageinfo?.[0];
    if (info && info.url) {
      const imageUrl = info.url;
      const metadata = info.extmetadata || {};
      const caption = metadata.ObjectName?.value || metadata.ImageDescription?.value || page.title.replace("File:", "");
      
      const cleanCaption = caption.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();

      // Check medical relevance before including
      if (!isImageMedicallyRelevant(page.title || "", cleanCaption)) continue;

      images.push({
        url: imageUrl,
        thumbnailUrl: info.thumburl || imageUrl,
        mediumUrl: info.thumburl || imageUrl,
        caption: cleanCaption.substring(0, 120) || "Medical illustration",
        creator: metadata.Artist?.value?.replace(/<[^>]*>/g, "") || "Wikimedia Commons",
        license: metadata.LicenseShortName?.value || "CC BY-SA 4.0",
        source: "Wikimedia Commons",
      });
    }
  }
  return images.slice(0, limit);
}
