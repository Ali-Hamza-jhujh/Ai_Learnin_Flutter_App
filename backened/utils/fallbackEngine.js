import { callGemini, callGroq, callCerebras } from "./providers.js";
import { isRateLimitError } from "./rateLimitDetector.js";

const TIMEOUT_MS = 15000;
const COOLDOWN_MS = 60 * 60 * 1000;

const cooldowns = new Map();

export function getProviderCooldowns(userId) {
  const now = Date.now();
  const result = {};

  for (const provider of ["gemini", "groq", "cerebras"]) {
    const key = `${provider}_${userId}`;
    const until = cooldowns.get(key);
    result[provider] = {
      coolingDown: Boolean(until && now < until),
      until: until && now < until ? until : null,
    };
  }

  return result;
}

export async function generateWithFallback(prompt, userKeys, userId) {
  const providers = [
    { name: "gemini", fn: callGemini },
    { name: "groq", fn: callGroq },
    { name: "cerebras", fn: callCerebras },
  ];

  const skipped = [];

  for (const provider of providers) {
    const key = userKeys?.[provider.name];
    if (!key?.trim()) continue;

    const cooldownKey = `${provider.name}_${userId}`;
    if (cooldowns.has(cooldownKey) && Date.now() < cooldowns.get(cooldownKey)) {
      skipped.push({ provider: provider.name, reason: "cooling_down" });
      continue;
    }

    try {
      const result = await Promise.race([
        provider.fn(prompt, key.trim()),
        new Promise((_, reject) =>
          setTimeout(() => reject(Object.assign(new Error("timeout"), { status: 408 })), TIMEOUT_MS)
        ),
      ]);

      return { result, provider: provider.name, skipped };
    } catch (err) {
      const status = err.status || 0;

      if (isRateLimitError(err, status)) {
        cooldowns.set(cooldownKey, Date.now() + COOLDOWN_MS);
        skipped.push({ provider: provider.name, reason: "rate_limit" });
      } else if (status === 401 || status === 403) {
        skipped.push({ provider: provider.name, reason: "invalid_key" });
      } else {
        skipped.push({ provider: provider.name, reason: "error" });
      }
    }
  }

  const error = new Error("ALL_PROVIDERS_EXHAUSTED");
  error.skipped = skipped;
  throw error;
}
