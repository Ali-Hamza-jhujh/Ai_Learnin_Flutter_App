export function isRateLimitError(err) {
  if (!err) return false;
  
  const status = err.status;
  if (status === 429 || status === 503) {
    return true;
  }

  const msg = (err.message || String(err)).toLowerCase();
  const patterns = [
    "rate limit",
    "rate_limit",
    "quota exceeded",
    "quota_exceeded",
    "too many requests",
    "requests per minute",
    "tokens per minute",
    "resource exhausted",
    "ratelimitexceeded",
    "model_rate_limit",
    "daily limit",
    "per day"
  ];

  return patterns.some((pattern) => msg.includes(pattern));
}
