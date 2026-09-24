import axios from "axios";

export async function fetchOpenFDAData(drugName) {
  const apiKey = process.env.OPENFDA_API_KEY;
  const baseUrl = "https://api.fda.gov/drug/label.json";

  try {
    const response = await axios.get(baseUrl, {
      params: {
        api_key: apiKey,
        search: `openfda.generic_name:"${drugName}" OR openfda.brand_name:"${drugName}" OR brand_name:"${drugName}"`,
        limit: 1,
      },
      timeout: 5000,
    });

    const results = response.data?.results?.[0];
    if (!results) {
      // Try generic search
      const fallbackResponse = await axios.get(baseUrl, {
        params: {
          api_key: apiKey,
          search: `${drugName}`,
          limit: 1,
        },
        timeout: 5000,
      });
      const fallbackResult = fallbackResponse.data?.results?.[0];
      if (!fallbackResult) return null;
      return parseFdaResult(fallbackResult);
    }

    return parseFdaResult(results);
  } catch (error) {
    console.error("❌ OpenFDA API Error:", error.message);
    return null;
  }
}

function parseFdaResult(res) {
  return {
    uses: cleanFdaField(res.indications_and_usage || res.purpose),
    warnings: cleanFdaField(res.warnings || res.warnings_and_precautions),
    contraindications: cleanFdaField(res.contraindications),
    sideEffects: cleanFdaField(res.adverse_reactions || res.side_effects),
    interactions: cleanFdaField(res.drug_interactions),
  };
}

function cleanFdaField(field) {
  if (!field) return [];
  if (Array.isArray(field)) {
    return field.map(str => str.replace(/\[.*?\]/g, "").trim()).filter(Boolean);
  }
  return [field.toString().replace(/\[.*?\]/g, "").trim()];
}
