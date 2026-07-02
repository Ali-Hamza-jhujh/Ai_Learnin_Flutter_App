import { getProviderCooldowns } from "./fallbackEngine.js";

export function getProviderStatus(userId, userKeys = {}) {
  const cooldowns = getProviderCooldowns(userId);

  return ["gemini", "groq", "cerebras"].map((provider) => {
    const hasKey = Boolean(userKeys?.[provider]?.trim());
    const coolingDown = cooldowns[provider]?.coolingDown;

    let status = "inactive";
    if (hasKey && !coolingDown) status = "active";
    else if (hasKey && coolingDown) status = "cooling_down";
    else if (!hasKey) status = "no_key";

    return {
      provider,
      status,
      hasKey,
      coolingDown,
      until: cooldowns[provider]?.until || null,
    };
  });
}
