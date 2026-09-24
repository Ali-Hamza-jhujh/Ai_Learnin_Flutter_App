import rateLimit from "express-rate-limit";

const generationKey = (req) =>
  req.user?.id?.toString() || ipKeyGenerator(req.ip);

export const globalRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: "Too many requests. Please try again later." },
});

export const generateRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: "Generation limit reached. Please wait before trying again." },
});

export const apiGenerateRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  keyGenerator: generationKey,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: "Too many requests to AI generation endpoints. Please try again in 15 minutes." },
});
