const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

async function fetchWithTimeout(url, options) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(id);
    return response;
  } catch (err) {
    clearTimeout(id);
    if (err.name === "AbortError" || err.message === "The user aborted a request.") {
      const timeoutErr = new Error("Request timed out after 15 seconds");
      timeoutErr.status = 408;
      throw timeoutErr;
    }
    throw err;
  }
}

async function handleResponse(res) {
  if (!res.ok) {
    let errMsg = `Provider error ${res.status}`;
    try {
      const data = await res.json();
      errMsg = data?.error?.message || data?.error || errMsg;
    } catch (_) {}
    const err = new Error(errMsg);
    err.status = res.status;
    throw err;
  }
  return res.json();
}

export async function callGemini(prompt, apiKey) {
  const url = `${GEMINI_URL}?key=${encodeURIComponent(apiKey)}`;
  const res = await fetchWithTimeout(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 2048,
      },
    }),
  });

  const data = await handleResponse(res);
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    const err = new Error("Invalid Gemini response structure");
    err.status = 500;
    throw err;
  }
  return text;
}

export async function callGroq(prompt, apiKey) {
  const res = await fetchWithTimeout("https://api.groq.com/openai/v1/chat/completions", {
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
          content: "You are an expert educational content generator. Respond ONLY with valid JSON.",
        },
        { role: "user", content: prompt },
      ],
      temperature: 0.4,
      max_tokens: 2048,
    }),
  });

  const data = await handleResponse(res);
  const text = data?.choices?.[0]?.message?.content;
  if (!text) {
    const err = new Error("Invalid Groq response structure");
    err.status = 500;
    throw err;
  }
  return text;
}

export async function callCerebras(prompt, apiKey) {
  const res = await fetchWithTimeout("https://api.cerebras.ai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama3.3-70b",
      messages: [
        {
          role: "system",
          content: "You are an expert educational content generator. Respond ONLY with valid JSON.",
        },
        { role: "user", content: prompt },
      ],
      temperature: 0.4,
      max_tokens: 2048,
    }),
  });

  const data = await handleResponse(res);
  const text = data?.choices?.[0]?.message?.content;
  if (!text) {
    const err = new Error("Invalid Cerebras response structure");
    err.status = 500;
    throw err;
  }
  return text;
}

export async function callGeminiServer(prompt, serverKey) {
  return callGemini(prompt, serverKey);
}
