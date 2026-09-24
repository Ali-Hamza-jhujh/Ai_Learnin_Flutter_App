import express from "express";
import authMiddleware from "../Authentication/auth.js";
import prisma from "../prisma.js";
import upload from "../middleware/upload.js";
import { processPdfBuffer, getPdfCacheByHash, hashPdfBuffer } from "../utils/pdfHasher.js";
import { detectChapters, extractSelectedText } from "../utils/chapterDetector.js";
import { buildPrompt } from "../utils/promptBuilder.js";
import { generateWithFallback } from "../utils/fallbackEngine.js";
import { getProviderStatus } from "../utils/providerState.js";
import { awardXP } from "../services/xpService.js";
import { apiGenerateRateLimiter, generateRateLimiter } from "../middleware/rateLimiter.js";

const router = express.Router();
const MAX_PROMPT_CHARACTERS = 120000;
const MAX_OCR_TEXT_BYTES = 1024 * 1024;
const ON_DEVICE_OCR_LANGUAGES = new Set(["eng", "ara", "rus", "deu", "chi_sim"]);
const OCR_LANGUAGE_LABELS = {
  eng: "English",
  ara: "Arabic",
  rus: "Russian",
  deu: "German",
  chi_sim: "Simplified Chinese",
};

function generationLanguage(pdfLanguage) {
  return OCR_LANGUAGE_LABELS[pdfLanguage] || "English";
}

function storedNoteLanguage(pdfLanguage) {
  const aliases = {
    eng: "en",
    ara: "ar",
    rus: "ru",
    deu: "de",
    chi_sim: "zh",
  };
  return aliases[pdfLanguage] || "en";
}

async function resolveStoredNoteLanguage(pdfHash) {
  if (!pdfHash) return "en";
  const pdf = await getPdfCacheByHash(pdfHash);
  return storedNoteLanguage(pdf?.language);
}

function normalizeChapters(chapters = []) {
  return [...chapters].map((c) => c.trim()).filter(Boolean).sort();
}

function normalizeMcqs(rawMcqs = []) {
  return rawMcqs.map((q) => ({
    question: q.question,
    options: q.options || [],
    correctAnswer: q.answer || q.correctAnswer,
    answer: q.answer || q.correctAnswer,
    explanation: q.explanation || "",
    topic: q.topic || "",
  }));
}

function buildFlashcards(notes = []) {
  return notes.map((n) => ({
    front: n.heading || "Topic",
    back: n.content || "",
    nextReview: new Date(),
    easeFactor: 2.5,
  }));
}

function assertGenerationOutput(result, type) {
  if (type === "notes") {
    const valid = Array.isArray(result?.notes) && result.notes.some(
      (note) => typeof note?.heading === "string" && typeof note?.content === "string"
    );
    if (valid) return;
  }

  if (type === "mcq") {
    const valid = Array.isArray(result?.mcqs) && result.mcqs.some(
      (mcq) =>
        typeof mcq?.question === "string" &&
        Array.isArray(mcq?.options) &&
        mcq.options.length >= 2 &&
        typeof (mcq.answer || mcq.correctAnswer) === "string"
    );
    if (valid) return;
  }

  const error = new Error("The AI returned incomplete study content. Please try again.");
  error.code = "INVALID_AI_RESPONSE";
  throw error;
}

async function resolveGenerationPrompt(clientPrompt, metadata) {
  if (metadata.pdfHash) {
    const pdf = await getPdfCacheByHash(metadata.pdfHash);
    if (!pdf) {
      const error = new Error("This PDF is no longer available. Upload it again to continue.");
      error.statusCode = 404;
      throw error;
    }

    const text = extractSelectedText(
      pdf.text,
      pdf.chapters,
      metadata.selectedChapters
    );
    if (!text.trim()) {
      const error = new Error("No readable text was found in the selected material.");
      error.statusCode = 422;
      throw error;
    }

    return buildPrompt({
      text,
      numMcqs: metadata.numMcqs,
      difficulty: metadata.difficulty,
      chapterTitles: metadata.selectedChapters,
      summaryType: metadata.summaryType || "normal",
      language: generationLanguage(pdf.language),
      generateNotes: metadata.type === "notes",
      generateMcqs: metadata.type === "mcq",
    });
  }

  if (typeof clientPrompt === "string" && clientPrompt.trim()) {
    return clientPrompt;
  }

  const error = new Error("Upload a PDF before generating study content.");
  error.statusCode = 400;
  throw error;
}

async function cacheGeneration({ userId, chapterKey, mcqs, notes, provider }) {
  if (!chapterKey) return;

  try {
    await prisma.generationCache.upsert({
      where: {
        userId_chapterKey: { userId, chapterKey },
      },
      update: {},
      create: {
        userId,
        chapterKey,
        mcqs,
        notes,
        provider,
        generatedAt: new Date(),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });
  } catch (err) {
    console.error("Cache generation upsert error:", err.message);
  }
}

async function materializeCachedContent(userId, cached, metadata) {
  const requestedChapters = normalizeChapters(metadata.selectedChapters || []);

  if (metadata.type === "mcq") {
    const existing = await prisma.mCQ.findFirst({
      where: {
        userId,
        pdfHash: metadata.pdfHash || "",
        difficulty: metadata.difficulty || "medium",
        numMcqs: metadata.numMcqs || 10,
      },
    });
    if (existing) return { ...existing, _id: existing.id };

    const created = await prisma.mCQ.create({
      data: {
        userId,
        pdfHash: metadata.pdfHash || "",
        requestedChapters,
        difficulty: metadata.difficulty || "medium",
        numMcqs: metadata.numMcqs || 10,
        title: metadata.title || "Generated Quiz",
        subject: metadata.subject || "",
        mode: "practice",
        questions: normalizeMcqs(cached.mcqs || []),
        provider: cached.provider,
      },
    });
    return { ...created, _id: created.id };
  }

  if (metadata.type === "notes") {
    const summaryType = metadata.summaryType || "normal";
    const existing = await prisma.note.findFirst({
      where: {
        userId,
        pdfHash: metadata.pdfHash || "",
        summaryType,
      },
    });
    if (existing) return { ...existing, _id: existing.id };

    const notesPayload = Array.isArray(cached.notes) ? cached.notes : [];
    const created = await prisma.note.create({
      data: {
        userId,
        pdfHash: metadata.pdfHash || "",
        requestedChapters,
        summaryType,
        title: metadata.title || "Generated Notes",
        subject: metadata.subject || "",
        mode: metadata.mode || "full",
        notes: notesPayload,
        chapters: notesPayload.map((note) => ({
          chapterName: note.heading,
          notes: note.content,
        })),
        flashcards: buildFlashcards(notesPayload),
        provider: cached.provider,
        language: metadata.noteLanguage || "en",
      },
    });
    return { ...created, _id: created.id };
  }

  return null;
}

// ── GET CACHE CHECK (GET /api/generate/cache) ──
router.get("/cache", authMiddleware, async (req, res) => {
  try {
    const { key } = req.query;
    if (!key) {
      return res.status(400).json({ message: "Cache key is required" });
    }

    const cached = await prisma.generationCache.findUnique({
      where: {
        userId_chapterKey: {
          userId: req.user.id,
          chapterKey: key,
        },
      },
    });

    if (!cached) {
      return res.status(404).json({ cached: false });
    }

    res.status(200).json({
      cached: true,
      mcqs: cached.mcqs,
      notes: cached.notes,
      provider: cached.provider,
      fromCache: true,
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ── FREE GENERATION HELPER ──
async function handleFreeGeneration(req, res, prompt, metadata = {}, chapterCacheKey = null) {
  metadata.selectedChapters = normalizeChapters(metadata.selectedChapters || []);
  const user = await prisma.user.findUnique({
    where: { id: req.user.id },
  });
  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }

  if (user.freeGenerationUsed === true) {
    return res.status(403).json({
      error: "free_generation_used",
      message: "Free generation already used",
    });
  }

  const serverKeys = {
    groq: process.env.LUMIO_GROQ_KEY,
    gemini: process.env.LUMIO_GEMINI_KEY,
    cerebras: process.env.LUMIO_CEREBRAS_KEY,
  };

  const hasServerKeys = ["groq", "gemini", "cerebras"].some((k) => serverKeys[k]?.trim());
  if (!hasServerKeys) {
    return res.status(503).json({ error: "server_ai_unavailable", message: "Server AI keys not configured" });
  }

  try {
    const generation = await generateWithFallback(prompt, serverKeys, req.user.id);
    const { result, provider } = generation;
    assertGenerationOutput(result, metadata.type);

    await prisma.user.update({
      where: { id: req.user.id },
      data: {
        freeGenerationUsed: true,
        freeGenerationUsedAt: new Date(),
      },
    });

    if (chapterCacheKey) {
      await cacheGeneration({
        userId: req.user.id,
        chapterKey: chapterCacheKey,
        mcqs: result.mcqs || [],
        notes: result.notes || [],
        provider: `${provider}_server_free`,
      });
    }

    let savedData = null;
    if (metadata.type === "mcq") {
      const createdMcq = await prisma.mCQ.create({
        data: {
          userId: req.user.id,
          pdfHash: metadata.pdfHash || "",
          title: metadata.title || "Generated Quiz",
          subject: metadata.subject || "",
          requestedChapters: metadata.selectedChapters,
          questions: normalizeMcqs(result.mcqs || []),
          difficulty: metadata.difficulty || "medium",
          numMcqs: metadata.numMcqs || 10,
          mode: "practice",
          provider: `${provider}_server_free`,
        },
      });
      savedData = { ...createdMcq, _id: createdMcq.id };
      awardXP(req.user.id, "GENERATE_MCQ").catch(err => console.error('XP error:', err));
    } else if (metadata.type === "notes") {
      const notesPayload = result.notes || [];
      const createdNote = await prisma.note.create({
        data: {
          userId: req.user.id,
          pdfHash: metadata.pdfHash || "",
          title: metadata.title || "Generated Notes",
          subject: metadata.subject || "",
          mode: metadata.mode || "full",
          requestedChapters: metadata.selectedChapters,
          summaryType: metadata.summaryType || "normal",
          notes: notesPayload,
          chapters: notesPayload.map((n) => ({
            chapterName: n.heading,
            notes: n.content,
          })),
          flashcards: buildFlashcards(notesPayload),
          provider: `${provider}_server_free`,
          language: metadata.noteLanguage || "en",
        },
      });
      savedData = { ...createdNote, _id: createdNote.id };
      awardXP(req.user.id, "GENERATE_NOTES").catch(err => console.error('XP error:', err));
    }

    return res.status(200).json({
      result,
      mcqs: result.mcqs,
      notes: result.notes,
      provider: `${provider}_server_free`,
      isFreeGeneration: true,
      data: savedData,
    });
  } catch (e) {
    if (e.code === "INVALID_AI_RESPONSE") {
      return res.status(502).json({ message: e.message });
    }
    return res.status(503).json({ error: "server_ai_unavailable", message: e.message });
  }
}

// ── GENERATE WITH OWN KEYS OR FALLBACK (POST /api/generate) ──
router.post("/", authMiddleware, apiGenerateRateLimiter, async (req, res) => {
  try {
    const { prompt: clientPrompt, userKeys, chapterCacheKey, ...metadata } = req.body;
    if (!["notes", "mcq"].includes(metadata.type)) {
      return res.status(400).json({ message: "Generation type must be notes or mcq" });
    }
    if (!["easy", "medium", "hard"].includes(metadata.difficulty)) {
      return res.status(400).json({ message: "Difficulty must be easy, medium, or hard" });
    }
    if (!["quick", "normal", "deep"].includes(metadata.summaryType || "normal")) {
      return res.status(400).json({ message: "Summary type must be quick, normal, or deep" });
    }
    metadata.selectedChapters = normalizeChapters(metadata.selectedChapters || []);
    metadata.numMcqs = Math.min(Math.max(Number(metadata.numMcqs) || 10, 1), 50);
    metadata.noteLanguage = await resolveStoredNoteLanguage(metadata.pdfHash);

    if (chapterCacheKey) {
      const cached = await prisma.generationCache.findUnique({
        where: {
          userId_chapterKey: {
            userId: req.user.id,
            chapterKey: chapterCacheKey,
          },
        },
      });

      if (cached) {
        const savedData = await materializeCachedContent(
          req.user.id,
          cached,
          metadata
        );
        return res.status(200).json({
          result: { mcqs: cached.mcqs, notes: cached.notes },
          mcqs: cached.mcqs,
          notes: cached.notes,
          provider: cached.provider,
          fromCache: true,
          isOffline: false,
          isFreeGeneration: false,
          attempted: [],
          data: savedData,
        });
      }
    }

    const prompt = await resolveGenerationPrompt(clientPrompt, metadata);
    if (prompt.length > MAX_PROMPT_CHARACTERS) {
      return res.status(413).json({
        message: "Selected material is too large. Choose fewer chapters or generate them separately.",
      });
    }

    const hasKeys = userKeys && ["gemini", "groq", "cerebras"].some((p) => userKeys[p]?.trim());
    if (hasKeys) {
      try {
        const generation = await generateWithFallback(prompt, userKeys, req.user.id);
        const { result, provider, attempted } = generation;
        assertGenerationOutput(result, metadata.type);

        if (chapterCacheKey) {
          await cacheGeneration({
            userId: req.user.id,
            chapterKey: chapterCacheKey,
            mcqs: result.mcqs || [],
            notes: result.notes || [],
            provider,
          });
        }

        let savedData = null;
        if (metadata.type === "mcq") {
          const createdMcq = await prisma.mCQ.create({
            data: {
              userId: req.user.id,
              pdfHash: metadata.pdfHash || "",
              title: metadata.title || "Generated Quiz",
              subject: metadata.subject || "",
              requestedChapters: metadata.selectedChapters,
              questions: normalizeMcqs(result.mcqs || []),
              difficulty: metadata.difficulty || "medium",
              numMcqs: metadata.numMcqs || 10,
              mode: "practice",
              provider,
            },
          });
          savedData = { ...createdMcq, _id: createdMcq.id };
          awardXP(req.user.id, "GENERATE_MCQ").catch(err => console.error('XP error:', err));
        } else if (metadata.type === "notes") {
          const notesPayload = result.notes || [];
          const createdNote = await prisma.note.create({
            data: {
              userId: req.user.id,
              pdfHash: metadata.pdfHash || "",
              title: metadata.title || "Generated Notes",
              subject: metadata.subject || "",
              mode: metadata.mode || "full",
              requestedChapters: metadata.selectedChapters,
              summaryType: metadata.summaryType || "normal",
              notes: notesPayload,
              chapters: notesPayload.map((n) => ({
                chapterName: n.heading,
                notes: n.content,
              })),
              flashcards: buildFlashcards(notesPayload),
              provider,
              language: metadata.noteLanguage || "en",
            },
          });
          savedData = { ...createdNote, _id: createdNote.id };
          awardXP(req.user.id, "GENERATE_NOTES").catch(err => console.error('XP error:', err));
        }

        return res.status(200).json({
          result,
          mcqs: result.mcqs,
          notes: result.notes,
          provider,
          attempted,
          fromCache: false,
          isOffline: false,
          isFreeGeneration: false,
          data: savedData,
        });
      } catch (err) {
        if (err.message === "ALL_PROVIDERS_EXHAUSTED") {
          return res.status(503).json({
            error: "all_providers_exhausted",
            attempted: err.attempted || [],
          });
        }
        throw err;
      }
    }

    return handleFreeGeneration(req, res, prompt, metadata, chapterCacheKey);
  } catch (e) {
    if (e.statusCode) {
      return res.status(e.statusCode).json({ message: e.message });
    }
    if (e.code === "INVALID_AI_RESPONSE") {
      return res.status(502).json({ message: e.message });
    }
    if (e.code === "P2002") {
      return res.status(409).json({ message: "Identical content already exists" });
    }
    res.status(500).json({ message: e.message });
  }
});

// ── SERVER FREE GENERATION (POST /api/generate/free) ──
router.post("/free", authMiddleware, apiGenerateRateLimiter, async (req, res) => {
  try {
    const { prompt, chapterCacheKey, ...metadata } = req.body;
    metadata.noteLanguage = await resolveStoredNoteLanguage(metadata.pdfHash);
    return handleFreeGeneration(req, res, prompt, metadata, chapterCacheKey);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ── UTILITY ENDPOINTS FOR BACKGROUND COMPATIBILITY ──
router.post("/pdf-cache", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file?.buffer) {
      return res.status(400).json({ message: "PDF file is required" });
    }

    const result = await processPdfBuffer(req.file.buffer);
    res.status(200).json(result);
  } catch (e) {
    res.status(e.statusCode || 500).json({ message: `PDF processing failed: ${e.message}` });
  }
});

router.post("/ocr-cache", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file?.buffer) {
      return res.status(400).json({ message: "PDF file is required" });
    }

    const language = String(req.body.language || "").trim();
    if (!ON_DEVICE_OCR_LANGUAGES.has(language)) {
      return res.status(400).json({ message: "Unsupported on-device OCR language" });
    }

    const ocrText = typeof req.body.ocrText === "string" ? req.body.ocrText.trim() : "";
    if (!ocrText) {
      return res.status(422).json({ message: "No readable text was found on this device" });
    }
    if (Buffer.byteLength(ocrText, "utf8") > MAX_OCR_TEXT_BYTES) {
      return res.status(413).json({
        message: "Recognized text is too large. Split the scanned PDF into smaller parts.",
      });
    }

    const pageCount = Number(req.body.pageCount);
    if (!Number.isInteger(pageCount) || pageCount < 1 || pageCount > 30) {
      return res.status(400).json({ message: "Invalid on-device OCR page count" });
    }

    const pdfHash = hashPdfBuffer(req.file.buffer);
    let cached = await getPdfCacheByHash(pdfHash);
    const foundInCache = cached != null;

    if (!cached) {
      const chapters = detectChapters(ocrText).map(({ title, startIndex, endIndex }) => ({
        title,
        startIndex,
        endIndex,
      }));

      await prisma.pdfCache.upsert({
        where: { pdfHash },
        update: {},
        create: {
          pdfHash,
          fullText: ocrText,
          chapters,
          pageCount,
          language,
          ocrUsed: true,
          ocrProvider: "on_device_tesseract",
        },
      });
      cached = await getPdfCacheByHash(pdfHash);
    }

    const chapters = cached.chapters || [];
    const divisions = chapters
      .map((chapter) => chapter.title)
      .filter((title) => title && title !== "Full Document");

    return res.status(200).json({
      message: foundInCache
        ? "On-device OCR found in cache"
        : "On-device OCR completed",
      documentType: divisions.length > 0 ? "book" : "plain",
      divisions,
      pdfHash: cached.pdfHash,
      fullText: cached.text,
      chapters,
      pageCount: cached.pageCount,
      fromPdfCache: foundInCache,
      ocrUsed: cached.ocrUsed,
      ocrProvider: cached.ocrProvider,
    });
  } catch (e) {
    if (e.code === "P2002") {
      return res.status(409).json({ message: "PDF cache could not be created. Please retry." });
    }
    return res.status(e.statusCode || 500).json({ message: `On-device OCR cache failed: ${e.message}` });
  }
});

router.post("/pdf-cache/check", authMiddleware, async (req, res) => {
  try {
    const { pdfHash } = req.body;
    if (!pdfHash) {
      return res.status(400).json({ message: "pdfHash is required" });
    }

    const cached = await getPdfCacheByHash(pdfHash);
    if (!cached) {
      return res.status(404).json({ message: "PDF cache miss", cached: false });
    }

    res.status(200).json({
      cached: true,
      pdfHash: cached.pdfHash,
      chapters: cached.chapters,
      pageCount: cached.pageCount,
      language: cached.language,
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get("/trial-status", authMiddleware, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { freeGenerationUsed: true },
    });
    if (!user) return res.status(404).json({ message: "User not found" });

    res.status(200).json({
      used: user.freeGenerationUsed === true,
      remaining: user.freeGenerationUsed ? 0 : 1,
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get("/provider-status", authMiddleware, async (req, res) => {
  try {
    res.status(200).json({
      providers: getProviderStatus(req.user.id, {
        gemini: req.headers["x-gemini-key"] || "",
        groq: req.headers["x-groq-key"] || "",
        cerebras: req.headers["x-cerebras-key"] || "",
      }),
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post("/with-keys", authMiddleware, generateRateLimiter, async (req, res) => {
  try {
    const { prompt, userKeys } = req.body;
    const generation = await generateWithFallback(prompt, userKeys, req.user.id);
    res.status(200).json({
      message: "Generated successfully",
      cached: false,
      provider: generation.provider,
      skipped: generation.skipped,
      data: generation.result,
      notes: generation.result.notes,
      mcqs: generation.result.mcqs,
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

export default router;
