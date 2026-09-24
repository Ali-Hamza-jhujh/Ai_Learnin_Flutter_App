import axios from "axios";

export async function fetchRxNormData(drugName) {
  try {
    // 1. Search drug name to get RxCUI
    const searchRes = await axios.get(`https://rxnav.nlm.nih.gov/REST/rxcui.json`, {
      params: { name: drugName },
      timeout: 5000,
    });
    let rxnormId = searchRes.data?.idGroup?.rxnormId?.[0];

    // Fallback: approximate term search for brand names (e.g. Disprin, Panadol)
    if (!rxnormId) {
      const approxRes = await axios.get(`https://rxnav.nlm.nih.gov/REST/approximateTerm.json`, {
        params: { term: drugName, maxEntries: 1 },
        timeout: 5000,
      });
      rxnormId = approxRes.data?.approximateGroup?.candidate?.[0]?.rxcui;
    }

    if (!rxnormId) return null;

    // 2. Fetch properties
    const propRes = await axios.get(`https://rxnav.nlm.nih.gov/REST/rxcui/${rxnormId}/properties.json`, {
      timeout: 5000,
    });
    const properties = propRes.data?.properties || {};

    // 3. Fetch related dosage forms
    const relatedRes = await axios.get(`https://rxnav.nlm.nih.gov/REST/rxcui/${rxnormId}/allrelated.json`, {
      timeout: 5000,
    });

    const relatedGroups = relatedRes.data?.allRelatedGroup?.conceptGroup || [];
    const doseForms = [];
    const strengths = [];
    const brandNames = [];

    for (const group of relatedGroups) {
      if (group.conceptProperties) {
        for (const prop of group.conceptProperties) {
          if (group.tty === "DF" || group.tty === "SBDg") {
            doseForms.push(prop.name);
          } else if (group.tty === "SCDC" || group.tty === "SCD") {
            strengths.push(prop.name);
          } else if (group.tty === "BN") {
            brandNames.push(prop.name);
          }
        }
      }
    }

    return {
      rxcui: rxnormId,
      name: properties.name || drugName,
      drugClass: properties.ttyName || "Ingredient",
      brandNames: [...new Set(brandNames)].slice(0, 10),
      doseForms: [...new Set(doseForms)].slice(0, 10),
      strength: [...new Set(strengths)].slice(0, 10),
    };
  } catch (error) {
    console.error("❌ RxNorm API Error:", error.message);
    return null;
  }
}
