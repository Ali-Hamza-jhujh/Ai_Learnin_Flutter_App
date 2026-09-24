// In-memory object storing cooldown timestamps: { 'groq_userId123': timestamp }
// NOTE: For production environments with multiple server instances, 
// a distributed store like Redis should be used instead of this in-memory object.
const cooldowns = {};

export function markCoolingDown(provider, userId, durationMs = 3600000) {
  const key = `${provider}_${userId}`;
  cooldowns[key] = Date.now() + durationMs;
}

export function isCoolingDown(provider, userId) {
  const key = `${provider}_${userId}`;
  const expiry = cooldowns[key];
  if (expiry && Date.now() < expiry) {
    return true;
  }
  return false;
}

export function getProviderStatus(userId, userKeys = {}) {
  const providers = ["groq", "gemini", "cerebras"];
  return providers.map((provider) => {
    const coolingDown = isCoolingDown(provider, userId);
    const coolsDownAt = coolingDown ? cooldowns[`${provider}_${userId}`] : null;
    
    const hasKey = userKeys[provider] ? userKeys[provider].trim().length > 0 : false;
    const available = !coolingDown;

    return {
      provider,
      available,
      coolsDownAt,
      hasKey,
      status: coolingDown ? "cooling_down" : (hasKey ? "active" : "no_key"),
    };
  });
}
