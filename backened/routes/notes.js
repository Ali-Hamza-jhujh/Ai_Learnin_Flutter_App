import express from "express";
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");
import upload from "../middleware/upload.js";
import prisma from "../prisma.js";
import authMiddleware from "../Authentication/auth.js";
import dotenv from "dotenv";
import { awardXP } from "../services/xpService.js";
import { cleanupPdfCacheIfOrphaned, processPdfBuffer } from "../utils/pdfHasher.js";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// HELPER FUNCTIONS
// ══════════════════════════════════════════

const extractTextFromPDF = async (bufferfile) => {
  const data = await pdfParse(bufferfile);
  return data.text;
};

const detectChapters = (fullText) => {
  const splittext = fullText.split("\n");
  let currentIndex = 0;
  const chapters = [];

  for (const line of splittext) {
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
    if (i + 1 < chapters.length) {
      chapters[i].endIndex = chapters[i + 1].startIndex;
    } else {
      chapters[i].endIndex = fullText.length;
    }
  }

  return chapters;
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
      if (lastPeriod > start + 1000) {
        end = lastPeriod + 1;
      }
    }
    chunks.push(text.slice(start, end).trim());
    start = end;
  }

  return chunks.filter(chunk => chunk.length > 50);
};

const sendChunkToBART = async (chunk, userKeys = {}, retryCount = 0) => {
  const keysToTry = [
    { key: userKeys.groq, source: 'user-groq' },
    { key: userKeys.gemini, source: 'user-gemini' },
    { key: userKeys.cerebras, source: 'user-cerebras' },
    { key: process.env.LUMIO_GROQ_KEY, source: 'server-groq' },
    { key: process.env.LUMIO_GEMINI_KEY, source: 'server-gemini' },
    { key: process.env.LUMIO_CEREBRAS_KEY, source: 'server-cerebras' },
  ].filter(k => k.key && k.key.trim());
  
  if (keysToTry.length === 0) {
    throw new Error("No API keys available. Please configure your API keys or use the offline model.");
  }
  
  for (const { key, source } of keysToTry) {
    try {
      console.log(`Trying ${source} key...`);
      
      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${key}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: [
            {
              role: "system",
              content: `You are an expert academic study notes generator. Create comprehensive, detailed, and well-structured study notes from the provided text. 

Your notes should include:
1. Clear headings and subheadings for organization
2. Detailed explanations of key concepts and theories
3. Important definitions with examples
4. Key points and main ideas in bullet points
5. Formulas, equations, or mathematical relationships (if applicable)
6. Diagrams or visual descriptions when helpful
7. Summary of the main topics covered
8. Important dates, names, or facts (if applicable)

Format the notes in a clean, readable structure using markdown. Be thorough and educational - these notes should help students deeply understand the material, not just provide a brief summary.`
            },
            {
              role: "user",
              content: `Generate study notes from this text:\n\n${chunk}`
            }
          ],
          max_tokens: 4096,
          temperature: 0.5
        })
      });

      if (!res.ok) {
        const text = await res.text();
        console.log(`${source} key error:`, res.status, text);
        
        if (res.status === 429) {
          console.log(`${source} key rate limited, trying next key...`);
          continue;
        }
        
        if (res.status === 401) {
          console.log(`${source} key invalid, trying next key...`);
          continue;
        }
        
        throw new Error(`${source} error: ${res.status}`);
      }

      const data = await res.json();
      console.log(`Success with ${source} key`);
      return data.choices[0].message.content;
      
    } catch (error) {
      console.log(`${source} key failed:`, error.message);
    }
  }
  
  throw new Error("All API keys have reached their limits or are invalid. Please try again later or use the offline model.");
};

const processChapter = async (chapterText, userKeys = {}) => {
  const chunks = chunkText(chapterText);
  const summaries = [];
  for (let i = 0; i < chunks.length; i++) {
    console.log(`Chunk ${i + 1}/${chunks.length}`);
    const summary = await sendChunkToBART(chunks[i], userKeys);
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
  if (chapters.length > 0) {
    return { type: "book", divisions: chapters };
  }

  const sections = detectSections(fullText);
  if (sections.length > 0) {
    return { type: "document", divisions: sections };
  }

  return { type: "plain", divisions: [] };
};

const processMultipleChapters = async (fullText, selectedChapterNames, detectedChapters, userKeys = {}) => {
  const results = [];

  for (const chapterName of selectedChapterNames) {
    const chapter = detectedChapters.find(c =>
      c.name.toLowerCase().includes(chapterName.toLowerCase())
    );

    if (!chapter) {
      results.push({ chapterName, notes: "Chapter not found in document" });
      continue;
    }

    const chapterText = extractChapterText(fullText, chapter);
    const notes = await processChapter(chapterText, userKeys);
    results.push({ chapterName: chapter.name, notes });
  }

  return results;
};

const processFullBook = async (fullText, detectedChapters, userKeys = {}) => {
  const results = [];

  for (const chapter of detectedChapters) {
    const chapterText = extractChapterText(fullText, chapter);

    if (chapterText.length < 100) continue;

    const notes = await processChapter(chapterText, userKeys);
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

    const pdf = await processPdfBuffer(req.file.buffer);
    const { type } = analyzeDocument(pdf.text);
    const divisions = pdf.chapters
      .map((chapter) => chapter.title)
      .filter((title) => title && title !== "Full Document");
    return res.status(200).json({
      message: pdf.cached ? "PDF found in cache" : "PDF scanned successfully",
      documentType: divisions.length === 0 ? "plain" : type,
      divisions,
      pdfHash: pdf.pdfHash,
      fullText: pdf.text,
      chapters: pdf.chapters,
      pageCount: pdf.pageCount,
      fromPdfCache: pdf.cached,
      ocrUsed: pdf.ocrUsed,
    });
  } catch (e) {
    console.error("Notes generation error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to generate notes";
    res.status(statusCode).json({ message: `Error: ${message}` });
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

    const userKeys = {
      groq: req.headers["x-groq-key"] || "",
      gemini: req.headers["x-gemini-key"] || "",
      cerebras: req.headers["x-cerebras-key"] || "",
    };

    const fullText = await extractTextFromPDF(req.file.buffer);
    const { type, divisions } = analyzeDocument(fullText);

    let processedChapters = [];

    if (type === "plain" || (mode === "full" && divisions.length === 0)) {
      const notes = await processChapter(fullText, userKeys);
      processedChapters = [{ chapterName: "Full Document", notes }];
    } else if (mode === "single") {
      if (!chapter) {
        return res.status(400).json({ message: "Please specify chapter or section name" });
      }
      processedChapters = await processMultipleChapters(fullText, [chapter], divisions, userKeys);
    } else if (mode === "multiple") {
      let chapterList;
      try {
        chapterList = JSON.parse(chapters);
      } catch (parseError) {
        return res.status(400).json({ message: "Invalid chapters format" });
      }
      if (!chapterList || chapterList.length === 0) {
        return res.status(400).json({ message: "Please select at least one section" });
      }
      processedChapters = await processMultipleChapters(fullText, chapterList, divisions, userKeys);
    } else if (mode === "full") {
      processedChapters = await processFullBook(fullText, divisions, userKeys);
    } else {
      return res.status(400).json({ message: "Mode must be single, multiple or full" });
    }

    const savedNotes = await prisma.note.create({
      data: {
        userId: req.user.id,
        title,
        subject: subject || null,
        mode,
        documentType: type,
        detectedChapters: divisions.map(c => c.name),
        chapters: processedChapters,
      },
    });
    
    awardXP(req.user.id, "GENERATE_NOTES").catch(err => console.error('XP award error:', err));

    res.status(201).json({
      message: "Notes generated successfully!",
      notes: { ...savedNotes, _id: savedNotes.id },
    });

  } catch (e) {
    console.error("Notes generation error:", e);
    
    if (e.message && e.message.includes('All API keys have reached their limits')) {
      return res.status(429).json({ 
        message: e.message,
        suggestOffline: true,
        error: "api_limits_exceeded"
      });
    }
    
    if (e.message && e.message.includes('API key')) {
      return res.status(401).json({ message: e.message });
    }
    
    if (e.message && e.message.includes('PDF')) {
      return res.status(400).json({ message: "Failed to parse PDF file. Please ensure it's a valid PDF." });
    }
    
    if (e.message && e.message.includes('JSON')) {
      return res.status(500).json({ message: "Failed to process notes data. Please try again." });
    }
    
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to generate notes";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── GET ALL NOTES ────────────────────────
router.get("/my-notes", authMiddleware, async (req, res) => {
  try {
    const notes = await prisma.note.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        userId: true,
        title: true,
        subject: true,
        mode: true,
        documentType: true,
        detectedChapters: true,
        isFavorite: true,
        createdAt: true,
        updatedAt: true,
        pdfHash: true,
      },
    });
    const formatted = notes.map(n => ({ ...n, _id: n.id }));
    res.status(200).json({ notes: formatted });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE NOTE ──────────────────────
router.get("/my-notes/:id", authMiddleware, async (req, res) => {
  try {
    const note = await prisma.note.findUnique({
      where: { id: req.params.id },
    });
    if (!note) return res.status(404).json({ message: "Note not found" });
    
    const isOwner = note.userId === req.user.id;
    
    if (!isOwner) {
      const userGroups = await prisma.group.findMany();
      const hasSharedAccess = userGroups.some(group => {
        const members = Array.isArray(group.members) ? group.members : [];
        const isMember = members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === req.user.id);
        if (!isMember) return false;
        const sharedNotes = Array.isArray(group.sharedNotes) ? group.sharedNotes : [];
        return sharedNotes.some(sn => (sn.toString() || sn.id || sn._id) === req.params.id);
      });
      
      if (!hasSharedAccess) {
        return res.status(403).json({ message: "Not authorized" });
      }
    }
    
    res.status(200).json({ note: { ...note, _id: note.id } });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── DELETE NOTE ──────────────────────────
router.delete("/delete-notes/:id", authMiddleware, async (req, res) => {
  try {
    const note = await prisma.note.findUnique({
      where: { id: req.params.id },
    });
    if (!note) return res.status(404).json({ message: "Note not found" });
    if (note.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    const pdfHash = note.pdfHash;
    await prisma.note.delete({
      where: { id: req.params.id },
    });
    if (pdfHash) await cleanupPdfCacheIfOrphaned(pdfHash);
    res.status(200).json({ message: "Note deleted successfully" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── UPDATE NOTE ──────────────────────────
router.put("/:id", authMiddleware, async (req, res) => {
  const { title, subject } = req.body;
  try {
    const note = await prisma.note.findUnique({
      where: { id: req.params.id },
    });
    if (!note) return res.status(404).json({ message: "Note not found" });
    if (note.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    const updated = await prisma.note.update({
      where: { id: req.params.id },
      data: {
        ...(title !== undefined && { title }),
        ...(subject !== undefined && { subject }),
      },
    });
    res.status(200).json({ message: "Note updated", note: { ...updated, _id: updated.id } });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── EXTRACT TEXT FOR SMART READER ────────
router.post("/extract-text", upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "No file uploaded" });
    }
    const ext = req.file.originalname.split(".").pop().toLowerCase();
    if (ext === "pdf") {
      const pageList = [];
      const options = {
        pagerender: function (pageData) {
          return pageData.getTextContent({ includeMarkedContent: false }).then(function (textContent) {
            let pageText = "";
            let lastY = null;
            let lastX = null;
            for (let item of textContent.items) {
              const str = item.str || "";
              if (str.length === 0) continue;

              // Detect line-break: item has hasEOL flag OR significant Y-position jump
              const curY = item.transform ? item.transform[5] : null;
              const curX = item.transform ? item.transform[4] : null;
              const isNewLine = item.hasEOL ||
                (lastY !== null && curY !== null && Math.abs(curY - lastY) > 3);

              if (isNewLine && pageText.length > 0) {
                // End the previous line cleanly
                const trimmed = pageText.trimEnd();
                pageText = trimmed + "\n";
              } else if (lastX !== null && curX !== null && curX - lastX > 15 && pageText.length > 0) {
                // Large horizontal gap within the same line → word boundary
                pageText += " ";
              }

              pageText += str;
              if (curY !== null) lastY = curY;
              if (curX !== null) lastX = curX + (str.length * 6); // rough estimate
            }
            pageList.push({
              pageNumber: pageData.pageIndex + 1,
              text: pageText.trim(),
            });
            return pageText;
          });
        },
      };
      const data = await pdfParse(req.file.buffer, options);
      return res.status(200).json({
        text: data.text || "",
        pages: pageList,
        totalPages: data.numpages || pageList.length,
        fileName: req.file.originalname,
      });
    } else {
      const text = req.file.buffer.toString("utf-8");
      return res.status(200).json({
        text: text || "",
        pages: [{ pageNumber: 1, text }],
        totalPages: 1,
        fileName: req.file.originalname,
      });
    }
  } catch (e) {
    res.status(500).json({ message: `Extraction failed: ${e.message}` });
  }
});

export default router;
