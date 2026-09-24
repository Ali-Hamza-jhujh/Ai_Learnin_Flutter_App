import { callGroq, callGemini, callCerebras } from "./providers.js";
import { isRateLimitError } from "./rateLimitDetector.js";
import { isCoolingDown, markCoolingDown } from "./providerState.js";

function parseJson(text) {
  let cleaned = (text || "").trim();
  
  // Strip ```json and ``` fences
  if (cleaned.startsWith("```json")) {
    cleaned = cleaned.substring(7);
  } else if (cleaned.startsWith("```")) {
    cleaned = cleaned.substring(3);
  }
  if (cleaned.endsWith("```")) {
    cleaned = cleaned.substring(0, cleaned.length - 3);
  }
  cleaned = cleaned.trim();

  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start === -1 || end === -1) {
    throw new Error("Malformed JSON: matching brackets not found");
  }
  const jsonStr = cleaned.substring(start, end + 1);
  return JSON.parse(jsonStr);
}

export async function generateWithFallback(prompt, userKeys, userId) {
  const providers = [
    { name: "groq", fn: callGroq },
    { name: "gemini", fn: callGemini },
    { name: "cerebras", fn: callCerebras },
  ];

  const attempted = [];

  for (const provider of providers) {
    const key = userKeys?.[provider.name];
    if (!key || key.trim().length === 0) {
      continue;
    }

    if (isCoolingDown(provider.name, userId)) {
      continue;
    }

    attempted.push(provider.name);

    let parsedResult = null;
    let success = false;
    let isRetry = false;

    // Retry the same provider ONCE if JSON parsing fails
    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        const rawResponse = await provider.fn(prompt, key.trim());
        try {
          parsedResult = parseJson(rawResponse);
          success = true;
          break; // Success! Exit the retry/parsing loop.
        } catch (jsonErr) {
          if (attempt === 1) {
            isRetry = true;
            continue; // Retry once
          } else {
            const wrapErr = new Error(`JSON parsing failed: ${jsonErr.message}`);
            wrapErr.status = 500;
            throw wrapErr;
          }
        }
      } catch (err) {
        if (isRetry && attempt === 1) {
          continue; // Run the second attempt
        }

        // Detect and handle rate limits
        if (isRateLimitError(err)) {
          markCoolingDown(provider.name, userId);
        }
        
        break; // Fail and skip to next provider
      }
    }

    if (success) {
      return { result: parsedResult, provider: provider.name, attempted };
    }
  }

  const err = new Error("ALL_PROVIDERS_EXHAUSTED");
  err.attempted = attempted;
  throw err;
}
