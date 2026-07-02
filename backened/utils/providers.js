const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

function extractJson(text) {
  const trimmed = (text || "").trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1) {
    throw new Error("Invalid AI response format");
  }
  return JSON.parse(trimmed.slice(start, end + 1));
}

async function parseProviderResponse(res) {
  if (!res.ok) {
    const err = new Error(`Provider error ${res.status}`);
    err.status = res.status;
    throw err;
  }

  const data = await res.json();
  const text =
    data?.candidates?.[0]?.content?.parts?.[0]?.text ||
    data?.choices?.[0]?.message?.content ||
    "";

  return extractJson(text);
}

export async function callGemini(prompt, apiKey) {
  const res = await fetch(`${GEMINI_URL}?key=${encodeURIComponent(apiKey)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 8192,
      },
    }),
  });

  return parseProviderResponse(res);
}

export async function callGroq(prompt, apiKey) {
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      messages: [
        {
          role: "system",
          content:
            "You are an expert educational content generator. Respond ONLY with valid JSON.",
        },
        { role: "user", content: prompt },
      ],
      temperature: 0.4,
      max_tokens: 8192,
    }),
  });

  return parseProviderResponse(res);
}

export async function callCerebras(prompt, apiKey) {
  const res = await fetch("https://api.cerebras.ai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama3.1-70b",
      messages: [
        {
          role: "system",
          content:
            "You are an expert educational content generator. Respond ONLY with valid JSON.",
        },
        { role: "user", content: prompt },
      ],
      temperature: 0.4,
      max_tokens: 8192,
    }),
  });

  return parseProviderResponse(res);
}

export async function callGeminiServer(prompt, serverKey) {
  return callGemini(prompt, serverKey);
}
