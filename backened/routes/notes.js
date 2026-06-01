import express from "express";
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");
import upload from "../middleware/upload.js";
import Notes from "../models/notes.js"        
import authMiddleware from "../Authentication/auth.js";
import dotenv from "dotenv";
import { awardXP } from "../services/xpService.js";
dotenv.config();

const router = express.Router();                   // fix: was importing router from user.js — wrong

// ══════════════════════════════════════════
// HELPER FUNCTIONS
// ══════════════════════════════════════════

// 1. Extract text from PDF
const extractTextFromPDF = async (bufferfile) => {
  const data = await pdfParse(bufferfile);          // fix: was missing await
  return data.text;
};

// 2. Detect chapters
const detectChapters = (fullText) => {             // fix: removed async — not needed
  const splittext = fullText.split("\n");
  let currentIndex = 0;                            // fix: was currentindex — JS is case sensitive
  const chapters = [];

  for (const line of splittext) {                  // fix: was "for in" — must be "for of" for arrays
    const trimmed = line.trim();                   // fix: was "trimed" then used "trimmed" — mismatch

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
    if (i + 1 < chapters.length) {
      chapters[i].endIndex = chapters[i + 1].startIndex; // fix: was endindex — case sensitive
    } else {
      chapters[i].endIndex = fullText.length;            // fix: was endindex
    }
  }

  return chapters;
};

// 3. Extract chapter text
const extractChapterText = (fullText, chapter) => { // fix: removed async — not needed
  return fullText.slice(chapter.startIndex, chapter.endIndex).trim(); // fix: was endindex
};

// 4. Chunk text
const chunkText = (text, chunkSize = 3000) => {    // fix: removed async — not needed
  const chunks = [];
  let start = 0;

  while (start < text.length) {
    let end = start + chunkSize;
    if (end < text.length) {
      const lastPeriod = text.lastIndexOf(".", end);
      if (lastPeriod > start + 1000) {
        end = lastPeriod + 1;
      }
    }
    chunks.push(text.slice(start, end).trim());
    start = end;
  }

  return chunks.filter(chunk => chunk.length > 50);
};

// 5. Send chunk to BART
const sendChunkToBART = async (chunk) => {
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.GROQ_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "llama-3.1-8b-instant",
      messages: [
        {
          role: "system",
          content: "You are a study notes generator. Summarize the given text into clear, concise, well-structured study notes with key points and important concepts."
        },
        {
          role: "user",
          content: `Generate study notes from this text:\n\n${chunk}`
        }
      ],
      max_tokens: 1024,
      temperature: 0.3
    })
  });

  if (!res.ok) {
    const text = await res.text();
    console.log("Groq error:", res.status, text);
    throw new Error(`Groq error: ${res.status}`);
  }

  const data = await res.json();
  return data.choices[0].message.content;
};
// 6. Process one chapter
const processChapter = async (chapterText) => {
  const chunks = chunkText(chapterText);           // fix: was calling chunkText as async — it is not
  const summaries = [];
  for (let i = 0; i < chunks.length; i++) {
    console.log(`Chunk ${i + 1}/${chunks.length}`);
    const summary = await sendChunkToBART(chunks[i]);
    summaries.push(summary);
  }
  return summaries.join("\n\n");
};
const detectSections = (fullText) => {
  const sections = [];
  const lines = fullText.split("\n");
  let currentIndex = 0;

  for (const line of lines) {
    const trimmed = line.trim();

    const isSection =
      /^(introduction|abstract|conclusion|summary|overview|methodology|references|appendix)/i.test(trimmed) ||
      /^(section|part)\s+[\dA-Z]/i.test(trimmed) ||   // "Section 1", "Part A"
      /^\d+\.\d*\s+[A-Z]/i.test(trimmed) ||            // "1.1 Overview"
      /^[A-Z][A-Z\s]{4,40}$/.test(trimmed);            // "INTRODUCTION" all caps

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
  // try chapters first
  const chapters = detectChapters(fullText);
  if (chapters.length > 0) {
    return { type: "book", divisions: chapters };
  }

  // try sections
  const sections = detectSections(fullText);
  if (sections.length > 0) {
    return { type: "document", divisions: sections };
  }

  // nothing found — plain document
  return { type: "plain", divisions: [] };
};
// 7. Process multiple chapters
const processMultipleChapters = async (fullText, selectedChapterNames, detectedChapters) => {
  const results = [];                              // fix: was "result" then used "results" — mismatch

  for (const chapterName of selectedChapterNames) { // fix: was "for in" — must be "for of"
    const chapter = detectedChapters.find(c =>
      c.name.toLowerCase().includes(chapterName.toLowerCase())
    );

    if (!chapter) {
      results.push({ chapterName, notes: "Chapter not found in document" });
      continue;
    }

    const chapterText = extractChapterText(fullText, chapter);
    const notes = await processChapter(chapterText); // fix: was missing await
    results.push({ chapterName: chapter.name, notes });
  }

  return results;
};

// 8. Process full book
const processFullBook = async (fullText, detectedChapters) => { // fix: was using selectedChapterNames — wrong param
  const results = [];

  for (const chapter of detectedChapters) {       // fix: was "for in" and wrong variable
    const chapterText = extractChapterText(fullText, chapter);

    if (chapterText.length < 100) continue;

    const notes = await processChapter(chapterText); // fix: was missing await
    results.push({ chapterName: chapter.name, notes });
  }

  return results;
};

// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── SCAN ─────────────────────────────────
router.post("/scan", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Please upload a PDF file" });
    }

    const fullText = await extractTextFromPDF(req.file.buffer);
    const { type, divisions } = analyzeDocument(fullText);

    if (type === "book") {
      return res.status(200).json({
        message: `Book detected — found ${divisions.length} chapters`,
        documentType: "book",
        divisions: divisions.map(c => c.name),
      });
    }

    if (type === "document") {
      return res.status(200).json({
        message: `Document detected — found ${divisions.length} sections`,
        documentType: "document",
        divisions: divisions.map(s => s.name),
      });
    }

    // plain document — no structure found
    return res.status(200).json({
      message: "Plain document detected — will generate notes for full document",
      documentType: "plain",
      divisions: [],
    });

  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GENERATE ─────────────────────────────
router.post("/generate", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Please upload a PDF file" });
    }

    const { title, subject, mode, chapter, chapters } = req.body;

    if (!title || !mode) {
      return res.status(400).json({ message: "Title and mode are required" });
    }

    const fullText = await extractTextFromPDF(req.file.buffer);
    const { type, divisions } = analyzeDocument(fullText);

    let processedChapters = [];

    // ── PLAIN DOCUMENT — no chapters or sections ──
    if (type === "plain" || (mode === "full" && divisions.length === 0)) {
      const notes = await processChapter(fullText);
      processedChapters = [{ chapterName: "Full Document", notes }];

    // ── SINGLE CHAPTER OR SECTION ─────────────────
    } else if (mode === "single") {
      if (!chapter) {
        return res.status(400).json({ message: "Please specify chapter or section name" });
      }
      processedChapters = await processMultipleChapters(fullText, [chapter], divisions);

    // ── MULTIPLE CHAPTERS OR SECTIONS ─────────────
    } else if (mode === "multiple") {
      const chapterList = JSON.parse(chapters);
      if (!chapterList || chapterList.length === 0) {
        return res.status(400).json({ message: "Please select at least one section" });
      }
      processedChapters = await processMultipleChapters(fullText, chapterList, divisions);

    // ── FULL BOOK OR FULL DOCUMENT ─────────────────
    } else if (mode === "full") {
      processedChapters = await processFullBook(fullText, divisions);

    } else {
      return res.status(400).json({ message: "Mode must be single, multiple or full" });
    }

    const savedNotes = await Notes.create({
      userId: req.user.id,
      title,
      subject,
      mode,
      documentType: type,                          // save document type
      detectedChapters: divisions.map(c => c.name),
      chapters: processedChapters,
    });
awardXP(req.user.id, "GENERATE_NOTES").catch(console.error);


    res.status(201).json({
      message: "Notes generated successfully!",
      notes: savedNotes,
    });

  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});
// ─── GET ALL NOTES ────────────────────────
router.get("/my-notes", authMiddleware, async (req, res) => { // fix: was missing "/" before my-notes
  try {
    const notes = await Notes.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .select("-chapters.notes");
    res.status(200).json({ notes });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE NOTE ──────────────────────
router.get("/my-notes/:id", authMiddleware, async (req, res) => {
  try {
    const note = await Notes.findById(req.params.id); // fix: was "notes" then used "note" — mismatch
    if (!note) return res.status(404).json({ message: "Note not found" });
    if (note.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    res.status(200).json({ note });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── DELETE NOTE ──────────────────────────
router.delete("/delete-notes/:id", authMiddleware, async (req, res) => {
  try {
    const note = await Notes.findById(req.params.id); // fix: was "notes" then used "note" — mismatch
    if (!note) return res.status(404).json({ message: "Note not found" });
    if (note.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    await Notes.findByIdAndDelete(req.params.id);
    res.status(200).json({ message: "Note deleted successfully" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── UPDATE NOTE ──────────────────────────
router.put("/:id", authMiddleware, async (req, res) => {
  const { title, subject } = req.body;
  try {
    const note = await Notes.findById(req.params.id);
    if (!note) return res.status(404).json({ message: "Note not found" });
    if (note.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    const updated = await Notes.findByIdAndUpdate(
      req.params.id,
      { title, subject },
      { new: true }
    );
    res.status(200).json({ message: "Note updated", note: updated });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});



export default router;