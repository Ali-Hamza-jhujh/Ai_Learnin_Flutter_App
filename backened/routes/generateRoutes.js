import express from "express";
import authMiddleware from "../Authentication/auth.js";
import User from "../models/users.js";
import Notes from "../models/notes.js";
import MCQ from "../models/mcqs.js";
import upload from "../middleware/upload.js";
import { processPdfBuffer, getPdfCacheByHash } from "../utils/pdfHasher.js";
import { extractSelectedText } from "../utils/chapterDetector.js";
import { buildPrompt } from "../utils/promptBuilder.js";
import { generateWithFallback } from "../utils/fallbackEngine.js";
import { callGeminiServer } from "../utils/providers.js";
import { getProviderStatus } from "../utils/providerState.js";
import { awardXP } from "../services/xpService.js";
import { generateRateLimiter } from "../middleware/rateLimiter.js";

const router = express.Router();

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

async function findExistingContent({
  userId,
  pdfHash,
  requestedChapters,
  summaryType,
  difficulty,
  numMcqs,
  type,
}) {
  if (type === "notes") {
    return Notes.findOne({
      userId,
      pdfHash,
      requestedChapters,
      summaryType,
    }).lean();
  }

  return MCQ.findOne({
    userId,
    pdfHash,
    requestedChapters,
    difficulty,
    numMcqs,
  }).lean();
}

router.post("/pdf-cache", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file?.buffer) {
      return res.status(400).json({ message: "PDF file is required" });
    }

    const result = await processPdfBuffer(req.file.buffer);
    res.status(200).json(result);
  } catch (e) {
    res.status(500).json({ message: `PDF processing failed: ${e.message}` });
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

    res.status(200).json(cached);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get("/trial-status", authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("freeGenerationUsed");
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
    const userKeys = req.query || {};
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

router.post("/free", authMiddleware, generateRateLimiter, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    if (user.freeGenerationUsed) {
      return res.status(403).json({
        message: "Free trial already used",
        showDisclaimer: true,
      });
    }

    const {
      pdfHash,
      selectedChapters = [],
      summaryType = "normal",
      difficulty = "medium",
      numMcqs = 10,
      mode = "practice",
      type = "notes",
      title = "Generated Content",
    } = req.body;
    const chapters = normalizeChapters(selectedChapters);

    const serverKey = process.env.LUMIO_GEMINI_KEY || process.env.GEMINI_API_KEY;
    if (!serverKey) {
      return res.status(503).json({ message: "Server AI temporarily unavailable" });
    }

    const cached = await getPdfCacheByHash(pdfHash);
    if (!cached) {
      return res.status(400).json({ message: "PDF not found in cache. Upload PDF first." });
    }

    const text = extractSelectedText(
      cached.text,
      cached.chapters,
      chapters
    );

    const prompt = buildPrompt({
      text,
      numMcqs,
      difficulty,
      chapterTitles: chapters,
      summaryType,
      generateNotes: type === "notes",
      generateMcqs: type === "mcq",
    });

    let aiResult;
    try {
      aiResult = await callGeminiServer(prompt, serverKey);
    } catch (err) {
      return res.status(503).json({ message: "AI generation failed. Free trial not consumed." });
    }

    user.freeGenerationUsed = true;
    await user.save();

    const notesPayload = aiResult.notes || [];
    const mcqsPayload = normalizeMcqs(aiResult.mcqs || []);

    let saved;
    if (type === "mcq") {
      saved = await MCQ.create({
        userId: req.user.id,
        pdfHash,
        title,
        requestedChapters: chapters,
        difficulty,
        numMcqs,
        mode,
        questions: mcqsPayload,
        provider: "gemini_free_trial",
      });
      await awardXP(req.user.id, "GENERATE_MCQ");
    } else {
      saved = await Notes.create({
        userId: req.user.id,
        pdfHash,
        title,
        requestedChapters: chapters,
        summaryType,
        notes: notesPayload,
        chapters: notesPayload.map((n) => ({
          chapterName: n.heading,
          notes: n.content,
        })),
        flashcards: buildFlashcards(notesPayload),
        provider: "gemini_free_trial",
      });
      await awardXP(req.user.id, "GENERATE_NOTES");
    }

    res.status(200).json({
      message: "Generated successfully",
      showDisclaimer: true,
      provider: "gemini_free_trial",
      skipped: [],
      data: saved,
      notes: notesPayload,
      mcqs: mcqsPayload,
    });
  } catch (e) {
    if (e.code === 11000) {
      return res.status(409).json({ message: "Identical content already exists" });
    }
    res.status(500).json({ message: e.message });
  }
});

router.post("/with-keys", authMiddleware, generateRateLimiter, async (req, res) => {
  try {
    const {
      pdfHash,
      selectedChapters = [],
      summaryType = "normal",
      difficulty = "medium",
      numMcqs = 10,
      mode = "practice",
      type = "notes",
      title = "Generated Content",
      userKeys = {},
    } = req.body;
    const chapters = normalizeChapters(selectedChapters);

    const hasAnyKey = ["gemini", "groq", "cerebras"].some(
      (p) => userKeys?.[p]?.trim()
    );
    if (!hasAnyKey) {
      return res.status(400).json({ message: "At least one provider key is required" });
    }

    const existing = await findExistingContent({
      userId: req.user.id,
      pdfHash,
      requestedChapters: chapters,
      summaryType,
      difficulty,
      numMcqs,
      type,
    });

    if (existing) {
      return res.status(200).json({
        message: "Returned cached result",
        cached: true,
        provider: existing.provider,
        skipped: [],
        data: existing,
      });
    }

    const cached = await getPdfCacheByHash(pdfHash);
    if (!cached) {
      return res.status(400).json({ message: "PDF not found in cache. Upload PDF first." });
    }

    const text = extractSelectedText(
      cached.text,
      cached.chapters,
      chapters
    );

    const prompt = buildPrompt({
      text,
      numMcqs,
      difficulty,
      chapterTitles: chapters,
      summaryType,
      generateNotes: type === "notes",
      generateMcqs: type === "mcq",
    });

    let aiResult;
    let provider;
    let skipped = [];

    try {
      const generation = await generateWithFallback(prompt, userKeys, req.user.id);
      aiResult = generation.result;
      provider = generation.provider;
      skipped = generation.skipped;
    } catch (err) {
      return res.status(503).json({
        message: "All providers exhausted",
        skipped: err.skipped || [],
      });
    }

    const notesPayload = aiResult.notes || [];
    const mcqsPayload = normalizeMcqs(aiResult.mcqs || []);

    let saved;
    if (type === "mcq") {
      saved = await MCQ.create({
        userId: req.user.id,
        pdfHash,
        title,
        requestedChapters: chapters,
        difficulty,
        numMcqs,
        mode,
        questions: mcqsPayload,
        provider,
      });
      await awardXP(req.user.id, "GENERATE_MCQ");
    } else {
      saved = await Notes.create({
        userId: req.user.id,
        pdfHash,
        title,
        requestedChapters: chapters,
        summaryType,
        notes: notesPayload,
        chapters: notesPayload.map((n) => ({
          chapterName: n.heading,
          notes: n.content,
        })),
        flashcards: buildFlashcards(notesPayload),
        provider,
      });
      await awardXP(req.user.id, "GENERATE_NOTES");
    }

    res.status(200).json({
      message: "Generated successfully",
      cached: false,
      provider,
      skipped,
      data: saved,
      notes: notesPayload,
      mcqs: mcqsPayload,
    });
  } catch (e) {
    if (e.code === 11000) {
      return res.status(409).json({ message: "Identical content already exists" });
    }
    res.status(500).json({ message: e.message });
  }
});

export default router;
