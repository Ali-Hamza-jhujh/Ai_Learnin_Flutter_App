export function isRateLimitError(err, status = 0) {
  if (status === 429 || status === 503) return true;

  const msg = (err?.message || String(err || "")).toLowerCase();
  return [
    "rate limit",
    "rate_limit",
    "quota exceeded",
    "too many requests",
    "resource exhausted",
    "ratelimitexceeded",
    "tokens per minute",
    "requests per minute",
    "model_rate_limit",
  ].some((pattern) => msg.includes(pattern));
}
