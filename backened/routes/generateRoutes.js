import express from "express";
import authMiddleware from "../Authentication/auth.js";
import User from "../models/users.js";
import dotenv from "dotenv";
dotenv.config();

const router = express.Router();

const buildPrompt = (text, numMcqs, difficulty) =>
  `You are an expert educational examiner.
Generate exactly ${numMcqs} MCQs (${difficulty} difficulty) and concise study notes from the text below.

Rules:
- Questions test understanding not memorization
- Wrong options must be plausible not obvious
- Notes must be clear and exam focused
- Respond in JSON only, no extra text

JSON format:
{
  "mcqs": [{"question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"answer":"A","explanation":"..."}],
  "notes": [{"heading":"...","content":"..."}]
}

TEXT:
${text}`;

const isRateLimitError = (err, status) => {
  if (status === 429 || status === 503) return true;
  const msg = (err?.message || "").toLowerCase();
  return ["rate limit","rate_limit","quota exceeded","quota_exceeded",
    "too many requests","requests per minute","tokens per minute",
    "resource exhausted","ratelimitexceeded","model_rate_limit",
    "per day","daily limit"].some(p => msg.includes(p));
};

const isInvalidKeyError = (status) => status === 401 || status === 403;

// Per-user cooldown (in-memory; use Redis for multi-instance)
const cooldowns = {};
const markCoolingDown = (provider, userId, ms = 60*60*1000) => {
  cooldowns[`${provider}_${userId}`] = Date.now() + ms;
};
const isCoolingDown = (provider, userId) => {
  const key = `${provider}_${userId}`;
  if (!cooldowns[key]) return false;
  if (Date.now() > cooldowns[key]) { delete cooldowns[key]; return false; }
  return true;
};

const TIMEOUT_MS = 15000;
const withTimeout = (p) => Promise.race([p,
  new Promise((_,r) => setTimeout(() =>
    r(Object.assign(new Error("timeout"),{status:0})), TIMEOUT_MS))]);

const callGemini = async (prompt, apiKey) => {
  const res = await withTimeout(fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
    { method:"POST", headers:{"Content-Type":"application/json"},
      body: JSON.stringify({contents:[{parts:[{text:prompt}]}],
        generationConfig:{temperature:0.4,maxOutputTokens:2048}}) }));
  if (!res.ok) {
    const d = await res.json().catch(()=>({}));
    const e = new Error(d?.error?.message || `Gemini ${res.status}`);
    e.status = res.status; throw e;
  }
  const d = await res.json();
  return d.candidates[0].content.parts[0].text;
};

const callGroq = async (prompt, apiKey) => {
  const res = await withTimeout(fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    { method:"POST",
      headers:{"Authorization":`Bearer ${apiKey}`,"Content-Type":"application/json"},
      body: JSON.stringify({model:"llama-3.3-70b-versatile",
        messages:[{role:"user",content:prompt}],
        max_tokens:2048,temperature:0.4}) }));
  if (!res.ok) {
    const d = await res.json().catch(()=>({}));
    const e = new Error(d?.error?.message || `Groq ${res.status}`);
    e.status = res.status; throw e;
  }
  const d = await res.json();
  return d.choices[0].message.content;
};

const callCerebras = async (prompt, apiKey) => {
  const res = await withTimeout(fetch(
    "https://api.cerebras.ai/v1/chat/completions",
    { method:"POST",
      headers:{"Authorization":`Bearer ${apiKey}`,"Content-Type":"application/json"},
      body: JSON.stringify({model:"llama3.3-70b",
        messages:[{role:"user",content:prompt}],
        max_tokens:2048,temperature:0.4}) }));
  if (!res.ok) {
    const d = await res.json().catch(()=>({}));
    const e = new Error(d?.error?.message || `Cerebras ${res.status}`);
    e.status = res.status; throw e;
  }
  const d = await res.json();
  return d.choices[0].message.content;
};

const parseAIResponse = (raw) => {
  const clean = raw.replace(/```json\s*/g,"").replace(/```\s*/g,"").trim();
  const parsed = JSON.parse(clean);
  return { mcqs: parsed.mcqs||[], notes: parsed.notes||[] };
};

const generateWithFallback = async (prompt, userKeys, userId) => {
  const providers = [
    { name:"gemini",   fn:callGemini   },
    { name:"groq",     fn:callGroq     },
    { name:"cerebras", fn:callCerebras },
  ];
  const attempted = [];
  for (const provider of providers) {
    const key = userKeys[provider.name];
    if (!key || !key.trim()) continue;
    if (isCoolingDown(provider.name, userId)) {
      console.log(`[${provider.name}] cooling — skip`); continue;
    }
    try {
      const raw = await provider.fn(prompt, key);
      const result = parseAIResponse(raw);
      return { ...result, provider: provider.name, attempted };
    } catch (err) {
      const status = err.status || 0;
      attempted.push(provider.name);
      console.log(`[${provider.name}] failed: ${err.message} (${status})`);
      if (isRateLimitError(err, status)) {
        markCoolingDown(provider.name, userId);
        continue;
      }
      if (isInvalidKeyError(status)) continue;
      continue;
    }
  }
  throw new Error("ALL_PROVIDERS_EXHAUSTED");
};

const getFreeTrialStatus = async (userId) => {
  const user = await User.findById(userId).select("freeGenerationUsed freeTierUsed");
  const used = user?.freeGenerationUsed || user?.freeTierUsed || false;
  return { exhausted: used, remaining: used ? 0 : 1 };
};

const consumeFreeTrial = async (userId) => {
  await User.findByIdAndUpdate(userId, { freeGenerationUsed:true, freeTierUsed:true });
};

// ── POST /api/generate/free ───────────────
router.post("/free", authMiddleware, async (req, res) => {
  try {
    const { text, numMcqs=10, difficulty="medium", keys={} } = req.body;
    const userId = req.user.id;

    if (!text || text.trim().length < 50)
      return res.status(400).json({ message:"Text too short" });

    const totalQ = Math.min(Math.max(parseInt(numMcqs)||10, 1), 30);
    const diff   = ["easy","medium","hard"].includes(difficulty) ? difficulty : "medium";
    const prompt = buildPrompt(text.trim(), totalQ, diff);
    const trial  = await getFreeTrialStatus(userId);

    // Case 1: free trial available — use Lumio server key
    if (!trial.exhausted) {
      const serverKey = process.env.LUMIO_GEMINI_KEY || process.env.GROQ_API_KEY;
      if (!serverKey) return res.status(503).json({ message:"Server key not configured" });
      try {
        let raw, provider;
        if (process.env.LUMIO_GEMINI_KEY) {
          raw = await callGemini(prompt, process.env.LUMIO_GEMINI_KEY);
          provider = "gemini";
        } else {
          raw = await callGroq(prompt, process.env.GROQ_API_KEY);
          provider = "groq";
        }
        const result = parseAIResponse(raw);
        await consumeFreeTrial(userId);
        const remaining = trial.remaining - 1;
        return res.status(200).json({
          ...result, provider, attempted:[],
          isFreeTrialUse:true, trialRemaining:remaining,
          showDisclaimer: remaining === 0,
        });
      } catch (err) {
        console.error("Server key failed:", err.message);
        // fall through to user keys
      }
    }

    // Case 2: free trial used, no user keys
    const hasKey = Object.values(keys).some(k => k && k.trim());
    if (!hasKey) {
      return res.status(402).json({
        error:"free_trial_exhausted", showDisclaimer:true,
        message:"Free generation used. Add your free API key for unlimited access.",
      });
    }

    // Case 3: run fallback chain with user keys
    try {
      const { mcqs, notes, provider, attempted } =
        await generateWithFallback(prompt, keys, userId);
      return res.status(200).json({
        mcqs, notes, provider, attempted,
        isFreeTrialUse:false, showDisclaimer:false,
      });
    } catch (err) {
      if (err.message === "ALL_PROVIDERS_EXHAUSTED") {
        return res.status(503).json({
          error:"all_providers_exhausted",
          message:"All AI providers are busy. Using offline AI instead.",
        });
      }
      throw err;
    }
  } catch (e) {
    console.error("Generate error:", e.message);
    res.status(500).json({ message:`Server error: ${e.message}` });
  }
});

// ── GET /api/generate/provider-status ─────
router.get("/provider-status", authMiddleware, async (req, res) => {
  const uid = req.user.id;
  res.status(200).json({ providers:
    ["gemini","groq","cerebras"].map(p => ({
      provider: p,
      available: !isCoolingDown(p, uid),
      coolsDownAt: cooldowns[`${p}_${uid}`] || null,
    }))
  });
});

// ── Validation endpoints ──────────────────
router.post("/validate-gemini", authMiddleware, async (req, res) => {
  try {
    const { geminiApiKey } = req.body;
    if (!geminiApiKey) return res.status(400).json({ valid:false });
    const r = await withTimeout(fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`,
      { method:"POST", headers:{"Content-Type":"application/json"},
        body: JSON.stringify({contents:[{parts:[{text:"Hi"}]}],
          generationConfig:{maxOutputTokens:5}}) }));
    res.status(200).json({ valid: r.ok });
  } catch (_) { res.status(200).json({ valid:false }); }
});

router.post("/validate-groq", authMiddleware, async (req, res) => {
  try {
    const { groqApiKey } = req.body;
    if (!groqApiKey || !groqApiKey.startsWith("gsk_"))
      return res.status(400).json({ valid:false });
    const r = await withTimeout(fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      { method:"POST",
        headers:{"Authorization":`Bearer ${groqApiKey}`,"Content-Type":"application/json"},
        body: JSON.stringify({model:"llama-3.3-70b-versatile",
          messages:[{role:"user",content:"Hi"}], max_tokens:5}) }));
    res.status(200).json({ valid: r.ok });
  } catch (_) { res.status(200).json({ valid:false }); }
});

router.post("/validate-cerebras", authMiddleware, async (req, res) => {
  try {
    const { cerebrasApiKey } = req.body;
    if (!cerebrasApiKey) return res.status(400).json({ valid:false });
    const r = await withTimeout(fetch(
      "https://api.cerebras.ai/v1/chat/completions",
      { method:"POST",
        headers:{"Authorization":`Bearer ${cerebrasApiKey}`,"Content-Type":"application/json"},
        body: JSON.stringify({model:"llama3.3-70b",
          messages:[{role:"user",content:"Hi"}], max_tokens:5}) }));
    res.status(200).json({ valid: r.ok });
  } catch (_) { res.status(200).json({ valid:false }); }
});

export default router;