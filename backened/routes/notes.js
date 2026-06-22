import express from "express";
import { createRequire } from "module";
import crypto from "crypto";
const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");
import upload from "../middleware/upload.js";
import Notes from "../models/notes.js";
import PdfCache from "../models/pdfCache.js";   // ← new model (see bottom)
import authMiddleware from "../Authentication/auth.js";
import User from "../models/users.js";
import dotenv from "dotenv";
import { awardXP } from "../services/xpService.js";
import { notifyNotesReady } from "../services/notificationService.js";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// GROQ KEY RESOLUTION
// Priority: user's own key (from request) → fallback shared key
// The fallback shared key allows exactly 1 free generation per user.
// After that the backend enforces key requirement server-side too.
// ══════════════════════════════════════════

const resolveGroqKey = async (req) => {
  // 1. Key sent by Flutter as a multipart field (highest priority)
  const keyFromBody = req.body?.groqApiKey?.trim();
  if (keyFromBody && keyFromBody.startsWith("gsk_")) return keyFromBody;

  // 2. Key sent as a header (for non-multipart endpoints)
  const keyFromHeader = req.headers["x-groq-api-key"]?.trim();
  if (keyFromHeader && keyFromHeader.startsWith("gsk_")) return keyFromHeader;

  // 3. No user key — check if free tier is still available for this user
  const userId = req.user.id;
  const user = await User.findById(userId).select("freeTierUsed");
  if (user?.freeTierUsed) {
    // Free tier already used — reject with clear message
    const err = new Error(
      "API key required. Your 1 free generation has been used. " +
      "Please add your Groq API key in Settings to continue."
    );
    err.statusCode = 402; // Payment/resource required
    throw err;
  }

  // 4. Use shared key for the free generation — mark it used atomically
  await User.findByIdAndUpdate(userId, { freeTierUsed: true });
  return process.env.GROQ_API_KEY; // Shared/fallback key
};

// ══════════════════════════════════════════
// PDF DEDUPLICATION
// We hash the PDF buffer with SHA-256.
// If we've seen this exact file before AND chapters are already extracted,
// we reuse the stored extraction — no Groq API call needed.
// ══════════════════════════════════════════

const hashBuffer = (buffer) => {
  return crypto.createHash("sha256").update(buffer).digest("hex");
};

// ══════════════════════════════════════════
// TEXT PROCESSING HELPERS
// ══════════════════════════════════════════

const extractTextFromPDF = async (bufferOrFile) => {
  const data = await pdfParse(bufferOrFile);
  return data.text;
};

const detectChapters = (fullText) => {
  const lines = fullText.split("\n");
  let currentIndex = 0;
  const chapters = [];

  for (const line of lines) {
    const trimmed = line.trim();
    const isChapter =
      /^chapter\s+\d+/i.test(trimmed) ||
      /^ch\.\s*\d+/i.test(trimmed) ||
      /^\d+\.\s+[A-Z]/i.test(trimmed);

    if (isChapter && trimmed.length > 3 && trimmed.length < 100) {
      const position = fullText.indexOf(trimmed, currentIndex);
      if (position !== -1) {
        chapters.push({ name: trimmed, startIndex: position });
        currentIndex = position + 1;
      }
    }
  }

  for (let i = 0; i < chapters.length; i++) {
    chapters[i].endIndex = i + 1 < chapters.length
      ? chapters[i + 1].startIndex
      : fullText.length;
  }
  return chapters;
};

const detectSections = (fullText) => {
  const lines = fullText.split("\n");
  let currentIndex = 0;
  const sections = [];

  for (const line of lines) {
    const trimmed = line.trim();
    const isSection =
      /^(introduction|abstract|conclusion|summary|overview|methodology|references|appendix)/i.test(trimmed) ||
      /^(section|part)\s+[\dA-Z]/i.test(trimmed) ||
      /^\d+\.\d*\s+[A-Z]/i.test(trimmed) ||
      /^[A-Z][A-Z\s]{4,40}$/.test(trimmed);

    if (isSection && trimmed.length > 3 && trimmed.length < 100) {
      const position = fullText.indexOf(trimmed, currentIndex);
      if (position !== -1) {
        sections.push({ name: trimmed, startIndex: position });
        currentIndex = position + 1;
      }
    }
  }

  for (let i = 0; i < sections.length; i++) {
    sections[i].endIndex = i + 1 < sections.length
      ? sections[i + 1].startIndex
      : fullText.length;
  }
  return sections;
};

const analyzeDocument = (fullText) => {
  const chapters = detectChapters(fullText);
  if (chapters.length > 0) return { type: "book", divisions: chapters };
  const sections = detectSections(fullText);
  if (sections.length > 0) return { type: "document", divisions: sections };
  return { type: "plain", divisions: [] };
};

const extractChapterText = (fullText, chapter) => {
  return fullText.slice(chapter.startIndex, chapter.endIndex).trim();
};

const chunkText = (text, chunkSize = 3000) => {
  const chunks = [];
  let start = 0;
  while (start < text.length) {
    let end = start + chunkSize;
    if (end < text.length) {
      const lastPeriod = text.lastIndexOf(".", end);
      if (lastPeriod > start + 1000) end = lastPeriod + 1;
    }
    chunks.push(text.slice(start, end).trim());
    start = end;
  }
  return chunks.filter((c) => c.length > 50);
};

// ── Groq call — uses the resolved key ────
const sendToGroq = async (chunk, groqKey) => {
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${groqKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama-3.1-8b-instant",
      messages: [
        {
          role: "system",
          content:
            "You are a study notes generator. Summarize the given text into " +
            "clear, concise, well-structured study notes with key points and " +
            "important concepts.",
        },
        {
          role: "user",
          content: `Generate study notes from this text:\n\n${chunk}`,
        },
      ],
      max_tokens: 1024,
      temperature: 0.3,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Groq error ${res.status}: ${text}`);
  }
  const data = await res.json();
  return data.choices[0].message.content;
};

const processChapter = async (chapterText, groqKey) => {
  const chunks = chunkText(chapterText);
  const summaries = [];
  for (let i = 0; i < chunks.length; i++) {
    console.log(`  Chunk ${i + 1}/${chunks.length}`);
    summaries.push(await sendToGroq(chunks[i], groqKey));
  }
  return summaries.join("\n\n");
};

const processMultipleChapters = async (fullText, selectedNames, detectedDivisions, groqKey) => {
  const results = [];
  for (const name of selectedNames) {
    const division = detectedDivisions.find((d) =>
      d.name.toLowerCase().includes(name.toLowerCase())
    );
    if (!division) {
      results.push({ chapterName: name, notes: "Chapter not found in document." });
      continue;
    }
    const text = extractChapterText(fullText, division);
    const notes = await processChapter(text, groqKey);
    results.push({ chapterName: division.name, notes });
  }
  return results;
};

const processFullBook = async (fullText, detectedDivisions, groqKey) => {
  const results = [];
  for (const division of detectedDivisions) {
    const text = extractChapterText(fullText, division);
    if (text.length < 100) continue;
    const notes = await processChapter(text, groqKey);
    results.push({ chapterName: division.name, notes });
  }
  return results;
};

// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── SCAN ─────────────────────────────────
// Analyses the PDF structure without generating anything.
// Checks deduplication cache first.
router.post("/scan", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Please upload a PDF file." });
    }

    const pdfHash = hashBuffer(req.file.buffer);

    // Check cache — if we've seen this PDF before, return stored structure
    const cached = await PdfCache.findOne({ pdfHash });
    if (cached) {
      console.log(`Cache hit on scan: ${pdfHash.slice(0, 8)}...`);
      return res.status(200).json({
        message: `${cached.documentType === "book" ? "Book" : "Document"} already in cache — ${cached.divisions.length} divisions found.`,
        documentType: cached.documentType,
        divisions: cached.divisions,
        fromCache: true,
        cacheId: cached._id,
      });
    }

    // Not cached — extract and analyse
    const fullText = await extractTextFromPDF(req.file.buffer);
    const { type, divisions } = analyzeDocument(fullText);
    const divisionNames = divisions.map((d) => d.name);

    // Store in cache for future use
    await PdfCache.create({
      pdfHash,
      documentType: type,
      divisions: divisionNames,
      fullText,              // stored for chapter extraction in /generate
      createdAt: new Date(),
    });

    return res.status(200).json({
      message: type === "plain"
        ? "Plain document — full notes will be generated."
        : `${type === "book" ? "Book" : "Document"} detected — ${divisions.length} divisions found.`,
      documentType: type,
      divisions: divisionNames,
      fromCache: false,
    });
  } catch (e) {
    console.error("Scan error:", e.message);
    res.status(e.statusCode || 500).json({ message: e.message });
  }
});

// ─── GENERATE ─────────────────────────────
// Main generation endpoint.
// 1. Resolves Groq key (user's own or shared free-tier)
// 2. Checks PDF cache — reuses stored text extraction
// 3. If chapters already generated for this PDF, returns cached result
// 4. Generates and saves new notes
router.post("/generate", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Please upload a PDF file." });
    }

    const { title, subject, mode, chapter, chapters } = req.body;
    if (!title || !mode) {
      return res.status(400).json({ message: "Title and mode are required." });
    }

    // ── 1. Resolve Groq key ──────────────
    let groqKey;
    try {
      groqKey = await resolveGroqKey(req);
    } catch (keyErr) {
      return res.status(keyErr.statusCode || 400).json({ message: keyErr.message });
    }

    // ── 2. PDF deduplication ─────────────
    const pdfHash = hashBuffer(req.file.buffer);
    let pdfCache = await PdfCache.findOne({ pdfHash });
    let fullText;
    let docType;
    let allDivisions; // raw {name, startIndex, endIndex} array

    if (pdfCache) {
      // Reuse stored full text — no re-extraction needed
      console.log(`Cache hit on generate: ${pdfHash.slice(0, 8)}...`);
      fullText = pdfCache.fullText;
      docType = pdfCache.documentType;
      // Re-run detect to get startIndex/endIndex (not stored in cache to save space)
      const analysis = analyzeDocument(fullText);
      allDivisions = analysis.divisions;
    } else {
      // First time seeing this PDF — extract and cache
      fullText = await extractTextFromPDF(req.file.buffer);
      const analysis = analyzeDocument(fullText);
      docType = analysis.type;
      allDivisions = analysis.divisions;

      pdfCache = await PdfCache.create({
        pdfHash,
        documentType: docType,
        divisions: allDivisions.map((d) => d.name),
        fullText,
        createdAt: new Date(),
      });
    }

    // ── 3. Smart chapter cache ───────────
    // If this exact PDF + these exact chapters were already generated
    // by ANY user, we reuse the text chunks — saves Groq API calls.
    // We do NOT share generated notes between users (privacy), but
    // we avoid re-calling Groq for identical text.
    const requestedChapters = mode === "single"
      ? [chapter]
      : mode === "multiple"
        ? (() => { try { return JSON.parse(chapters); } catch { return chapters?.split(",").map(c => c.trim()) ?? []; } })()
        : allDivisions.map((d) => d.name); // full mode

    // Check if this user already has notes for this PDF + mode + chapters
    const existingNote = await Notes.findOne({
      userId: req.user.id,
      pdfHash,
      mode,
      // For single/multiple, check same chapter selection
      ...(mode !== "full" && {
        requestedChapters: { $all: requestedChapters, $size: requestedChapters.length },
      }),
    });

    if (existingNote) {
      console.log(`User already has notes for this PDF+mode — returning existing.`);
      return res.status(200).json({
        message: "Notes already generated for this document — returning existing.",
        notes: existingNote,
        fromCache: true,
      });
    }

    // ── 4. Generate notes ────────────────
    console.log(`Generating notes — mode: ${mode}, key: ${groqKey === process.env.GROQ_API_KEY ? "shared" : "user"}`);
    let processedChapters = [];

    if (docType === "plain" || (mode === "full" && allDivisions.length === 0)) {
      const notes = await processChapter(fullText, groqKey);
      processedChapters = [{ chapterName: "Full Document", notes }];

    } else if (mode === "single") {
      if (!chapter) {
        return res.status(400).json({ message: "Please specify a chapter name." });
      }
      processedChapters = await processMultipleChapters(fullText, [chapter], allDivisions, groqKey);

    } else if (mode === "multiple") {
      const chapterList = (() => {
        try { return JSON.parse(chapters); }
        catch { return chapters?.split(",").map((c) => c.trim()) ?? []; }
      })();
      if (!chapterList.length) {
        return res.status(400).json({ message: "Please select at least one chapter." });
      }
      processedChapters = await processMultipleChapters(fullText, chapterList, allDivisions, groqKey);

    } else if (mode === "full") {
      processedChapters = await processFullBook(fullText, allDivisions, groqKey);

    } else {
      return res.status(400).json({ message: "Mode must be single, multiple, or full." });
    }

    // ── 5. Save notes ────────────────────
    const savedNotes = await Notes.create({
      userId: req.user.id,
      pdfHash,                                    // link to PDF cache
      title,
      subject: subject ?? "",
      mode,
      documentType: docType,
      detectedChapters: allDivisions.map((d) => d.name),
      requestedChapters,                          // for dedup lookup
      chapters: processedChapters,
    });

    // Award XP and notify (non-blocking)
    awardXP(req.user.id, "GENERATE_NOTES").catch(console.error);
    const user = await User.findById(req.user.id).select("fcmToken");
    if (user?.fcmToken) notifyNotesReady(user.fcmToken, title).catch(console.error);

    return res.status(201).json({
      message: "Notes generated successfully!",
      notes: savedNotes,
      fromCache: false,
    });
  } catch (e) {
    console.error("Generate error:", e.message);
    res.status(e.statusCode || 500).json({ message: e.message });
  }
});

// ─── GET ALL NOTES (this user only) ────────
router.get("/my-notes", authMiddleware, async (req, res) => {
  try {
    // Strictly scoped to req.user.id — never returns other users' notes
    const notes = await Notes.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .select("-chapters.notes -fullText"); // strip heavy fields for list view
    res.status(200).json({ notes });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ─── GET SINGLE NOTE ──────────────────────
router.get("/my-notes/:id", authMiddleware, async (req, res) => {
  try {
    const note = await Notes.findById(req.params.id);
    if (!note) return res.status(404).json({ message: "Note not found." });
    // Ownership check — prevents users from reading each other's notes by ID
    if (note.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Access denied." });
    }
    res.status(200).json({ note });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ─── DELETE NOTE ──────────────────────────
// Deletes the note AND cleans up:
//  - If no other notes reference the PDF hash, deletes the PdfCache entry too
//  - Cascades to MCQs if they reference the same document
router.delete("/delete-notes/:id", authMiddleware, async (req, res) => {
  try {
    const note = await Notes.findById(req.params.id);
    if (!note) return res.status(404).json({ message: "Note not found." });
    if (note.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Access denied." });
    }

    const pdfHash = note.pdfHash;
    const userId = req.user.id;

    // 1. Delete the note itself
    await Notes.findByIdAndDelete(req.params.id);

    // 2. Check if any other records by this user still reference this PDF
    if (pdfHash) {
      const [remainingNotes, remainingMCQs] = await Promise.all([
        Notes.countDocuments({ userId, pdfHash }),
        // MCQModel if you have one — skip if not
        Promise.resolve(0),
      ]);

      // 3. If no more references from ANY user, remove the PDF cache too
      // (saves DB storage — the text can always be re-extracted from a re-upload)
      const globalRefs = await Notes.countDocuments({ pdfHash });
      if (globalRefs === 0) {
        await PdfCache.findOneAndDelete({ pdfHash });
        console.log(`PdfCache cleaned for hash ${pdfHash.slice(0, 8)}...`);
      }
    }

    res.status(200).json({ message: "Note and associated cache deleted successfully." });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ─── UPDATE NOTE ──────────────────────────
router.put("/:id", authMiddleware, async (req, res) => {
  const { title, subject } = req.body;
  try {
    const note = await Notes.findById(req.params.id);
    if (!note) return res.status(404).json({ message: "Note not found." });
    if (note.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Access denied." });
    }
    const updated = await Notes.findByIdAndUpdate(
      req.params.id,
      { title, subject },
      { new: true }
    );
    res.status(200).json({ message: "Note updated.", note: updated });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

export default router;

// ══════════════════════════════════════════
// PDFCACHE MODEL  (save as models/pdfCache.js)
// ══════════════════════════════════════════
/*
import mongoose from "mongoose";

const pdfCacheSchema = new mongoose.Schema({
  pdfHash:      { type: String, required: true, unique: true, index: true },
  documentType: { type: String, enum: ["book", "document", "plain"], default: "plain" },
  divisions:    [String],      // chapter/section names only
  fullText:     { type: String, required: true },  // extracted text for re-use
  createdAt:    { type: Date, default: Date.now, expires: "90d" }, // auto-delete after 90 days
});

export default mongoose.model("PdfCache", pdfCacheSchema);
*/

// ══════════════════════════════════════════
// NOTES MODEL UPDATE  (add to models/notes.js)
// Add these fields to your existing Notes schema:
// ══════════════════════════════════════════
/*
  pdfHash:           { type: String, index: true },   // links to PdfCache
  requestedChapters: [String],                        // for dedup lookup
  documentType:      { type: String, default: "plain" },
*/