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
// HELPER FUNCTIONS (shared with notesRoutes)
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
    chapters[i].endIndex =
      i + 1 < chapters.length ? chapters[i + 1].startIndex : fullText.length;
  }

  return chapters;
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
    sections[i].endIndex =
      i + 1 < sections.length ? sections[i + 1].startIndex : fullText.length;
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

const extractDivisionText = (fullText, division) => {
  return fullText.slice(division.startIndex, division.endIndex).trim();
};

const chunkText = (text, chunkSize = 12000) => {
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

  return chunks.filter((chunk) => chunk.length > 50);
};

// ══════════════════════════════════════════
// MCQ-SPECIFIC HELPERS
// ══════════════════════════════════════════

const generateMCQsFromChunk = async (chunk, numQuestions, difficulty, userKeys = {}, retryCount = 0) => {
  const difficultyGuide = {
    easy: "Focus on basic definitions, facts, and simple recall questions.",
    medium: "Include application and comprehension questions. Mix recall with understanding.",
    hard: "Focus on analysis, inference, and deep understanding. Avoid surface-level questions.",
  };

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
      console.log(`Trying ${source} key for MCQ...`);
      
      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "llama-3.3-8b-instant",
          messages: [
            {
              role: "system",
              content: `You are an expert MCQ generator for students. 
Generate exactly ${numQuestions} multiple choice questions from the given text.
Difficulty level: ${difficulty}. ${difficultyGuide[difficulty]}

CRITICAL INSTRUCTIONS:
- Return ONLY a valid JSON array. No extra text, no markdown, no backticks, no explanations.
- Each object must have exactly these keys:
  "question" (string),
  "options" (array of exactly 4 strings — label them A) B) C) D) inside the string),
  "correctAnswer" (string — must exactly match one of the options),
  "explanation" (string — 1-2 sentences why the answer is correct)
- Make all 4 options plausible. Avoid obviously wrong distractors.
- Base every question strictly on the provided text.
- Do NOT include any introductory text like "Here are the questions:" or "Here is the JSON array:"
- Do NOT include any concluding text or explanations.
- Start your response directly with [ and end with ]`,
            },
            {
              role: "user",
              content: `Generate ${numQuestions} MCQs from this text:\n\n${chunk}`,
            },
          ],
          max_tokens: 2048,
          temperature: 0.4,
        }),
      });

      if (!res.ok) {
        const text = await res.text();
        console.log(`${source} key error for MCQ:`, res.status, text);
        
        if (res.status === 429) {
          console.log(`${source} key rate limited for MCQ, trying next key...`);
          continue;
        }
        
        if (res.status === 401) {
          console.log(`${source} key invalid for MCQ, trying next key...`);
          continue;
        }
        
        throw new Error(`${source} error: ${res.status}`);
      }

      const data = await res.json();
      const raw = data.choices[0].message.content.trim();
      console.log(`Success with ${source} key for MCQ`);

      let cleaned = raw.replace(/```json|```/g, "").trim();
      cleaned = cleaned.replace(/^[^\[\{]*/, "").replace(/[^\]\}]*$/, "");

      try {
        const parsed = JSON.parse(cleaned);
        return Array.isArray(parsed) ? parsed : [];
      } catch (e) {
        console.log("MCQ JSON parse error:", e.message, "\nRaw:", cleaned.slice(0, 500));
        
        const jsonMatch = cleaned.match(/\[[\s\S]*\]/);
        if (jsonMatch) {
          try {
            const extracted = JSON.parse(jsonMatch[0]);
            console.log("Successfully extracted JSON from text");
            return Array.isArray(extracted) ? extracted : [];
          } catch (e2) {
            console.log("Extracted JSON parse error:", e2.message);
          }
        }
        
        const objMatch = cleaned.match(/\{[\s\S]*\}/);
        if (objMatch) {
          try {
            const extracted = JSON.parse(objMatch[0]);
            console.log("Successfully extracted JSON object from text");
            return Array.isArray(extracted) ? extracted : [extracted];
          } catch (e3) {
            console.log("Extracted JSON object parse error:", e3.message);
          }
        }
        
        return [];
      }
      
    } catch (error) {
      console.log(`${source} key failed for MCQ:`, error.message);
    }
  }
  
  throw new Error("All API keys have reached their limits or are invalid. Please try again later or use the offline model.");
};

const processDivisionForMCQ = async (text, totalQuestions, difficulty, userKeys = {}) => {
  const chunks = chunkText(text);
  if (chunks.length === 0) return [];

  const questionsPerChunk = Math.ceil(totalQuestions / chunks.length);
  let allQuestions = [];

  for (let i = 0; i < chunks.length; i++) {
    console.log(`MCQ chunk ${i + 1}/${chunks.length}`);
    const needed = Math.min(questionsPerChunk, totalQuestions - allQuestions.length);
    if (needed <= 0) break;

    const questions = await generateMCQsFromChunk(chunks[i], needed, difficulty, userKeys);
    allQuestions = allQuestions.concat(questions);
  }

  return allQuestions.slice(0, totalQuestions);
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
    res.status(e.statusCode || 500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GENERATE MCQs ─────────────────────────
router.post("/generate", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Please upload a PDF file" });
    }

    const {
      title,
      subject,
      mode,
      chapter,
      chapters,
      numQuestions = 10,
      difficulty = "medium",
    } = req.body;

    if (!title || !mode) {
      return res.status(400).json({ message: "Title and mode are required" });
    }

    const validDifficulties = ["easy", "medium", "hard"];
    if (!validDifficulties.includes(difficulty)) {
      return res.status(400).json({ message: "Difficulty must be easy, medium, or hard" });
    }

    const totalQ = Math.min(Math.max(parseInt(numQuestions) || 10, 1), 50);

    const userKeys = {
      groq: req.headers["x-groq-key"] || "",
      gemini: req.headers["x-gemini-key"] || "",
      cerebras: req.headers["x-cerebras-key"] || "",
    };

    const fullText = await extractTextFromPDF(req.file.buffer);
    const { type, divisions } = analyzeDocument(fullText);

    let allQuestions = [];
    let chapterLabel = "Full Document";

    if (type === "plain" || (mode === "full" && divisions.length === 0)) {
      allQuestions = await processDivisionForMCQ(fullText, totalQ, difficulty, userKeys);
      chapterLabel = "Full Document";
    } else if (mode === "single") {
      if (!chapter) {
        return res.status(400).json({ message: "Please specify a chapter or section name" });
      }

      const found = divisions.find((d) =>
        d.name.toLowerCase().includes(chapter.toLowerCase())
      );
      if (!found) {
        return res.status(404).json({ message: `Chapter/section "${chapter}" not found in document` });
      }

      const text = extractDivisionText(fullText, found);
      allQuestions = await processDivisionForMCQ(text, totalQ, difficulty, userKeys);
      chapterLabel = found.name;
    } else if (mode === "multiple") {
      let chapterList;
      try {
        chapterList = JSON.parse(chapters);
      } catch (parseError) {
        return res.status(400).json({ message: "Invalid chapters format" });
      }
      if (!chapterList || chapterList.length === 0) {
        return res.status(400).json({ message: "Please select at least one chapter or section" });
      }

      const qPerChapter = Math.ceil(totalQ / chapterList.length);

      for (const chName of chapterList) {
        const found = divisions.find((d) =>
          d.name.toLowerCase().includes(chName.toLowerCase())
        );
        if (!found) continue;

        const text = extractDivisionText(fullText, found);
        const needed = Math.min(qPerChapter, totalQ - allQuestions.length);
        if (needed <= 0) break;

        const questions = await processDivisionForMCQ(text, needed, difficulty, userKeys);
        allQuestions = allQuestions.concat(questions);
      }

      chapterLabel = chapterList.join(", ");
    } else if (mode === "full") {
      const qPerDivision = Math.ceil(totalQ / divisions.length);

      for (const division of divisions) {
        const text = extractDivisionText(fullText, division);
        if (text.length < 100) continue;

        const needed = Math.min(qPerDivision, totalQ - allQuestions.length);
        if (needed <= 0) break;

        const questions = await processDivisionForMCQ(text, needed, difficulty, userKeys);
        allQuestions = allQuestions.concat(questions);
      }

      chapterLabel = "Full Document";
    } else {
      return res.status(400).json({ message: "Mode must be single, multiple, or full" });
    }

    if (allQuestions.length === 0) {
      return res.status(422).json({
        message: "Could not generate MCQs from this document. Try a different section or simpler difficulty.",
      });
    }

    const savedMCQ = await prisma.mCQ.create({
      data: {
        userId: req.user.id,
        title,
        subject: subject || null,
        chapter: chapterLabel,
        difficulty,
        numMcqs: totalQ,
        mode: mode || "practice",
        documentType: type,
        questions: allQuestions,
      },
    });
    
    awardXP(req.user.id, "GENERATE_MCQ").catch(err => console.error('XP award error:', err));

    res.status(201).json({
      message: `${allQuestions.length} MCQs generated successfully!`,
      mcq: { ...savedMCQ, _id: savedMCQ.id },
    });
  } catch (e) {
    console.error("MCQ generation error:", e);
    
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
      return res.status(500).json({ message: "Failed to process MCQ data. Please try again." });
    }
    
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to generate MCQs";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── GET ALL MCQs (list, no questions array) ─
router.get("/my-mcqs", authMiddleware, async (req, res) => {
  try {
    const mcqs = await prisma.mCQ.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        userId: true,
        title: true,
        subject: true,
        chapter: true,
        difficulty: true,
        numMcqs: true,
        mode: true,
        documentType: true,
        createdAt: true,
        updatedAt: true,
        pdfHash: true,
      },
    });
    const formatted = mcqs.map(m => ({ ...m, _id: m.id }));
    res.status(200).json({ mcqs: formatted });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE MCQ (with all questions) ─────
router.get("/my-mcqs/:id", authMiddleware, async (req, res) => {
  try {
    const mcq = await prisma.mCQ.findUnique({
      where: { id: req.params.id },
    });
    if (!mcq) return res.status(404).json({ message: "MCQ set not found" });
    
    const isOwner = mcq.userId === req.user.id;
    
    if (!isOwner) {
      const userGroups = await prisma.group.findMany();
      const hasSharedAccess = userGroups.some(group => {
        const members = Array.isArray(group.members) ? group.members : [];
        const isMember = members.some(m => (m.user?.toString() || m.user?.id || m.userId || m) === req.user.id);
        if (!isMember) return false;
        const sharedMcqs = Array.isArray(group.sharedMcqs) ? group.sharedMcqs : [];
        return sharedMcqs.some(sm => (sm.toString() || sm.id || sm._id) === req.params.id);
      });
      
      if (!hasSharedAccess) {
        return res.status(403).json({ message: "Not authorized" });
      }
    }
    
    res.status(200).json({ mcq: { ...mcq, _id: mcq.id } });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── DELETE MCQ ───────────────────────────────
router.delete("/delete-mcq/:id", authMiddleware, async (req, res) => {
  try {
    const mcq = await prisma.mCQ.findUnique({
      where: { id: req.params.id },
    });
    if (!mcq) return res.status(404).json({ message: "MCQ set not found" });
    if (mcq.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    const pdfHash = mcq.pdfHash;
    await prisma.mCQ.delete({
      where: { id: req.params.id },
    });
    if (pdfHash) await cleanupPdfCacheIfOrphaned(pdfHash);
    res.status(200).json({ message: "MCQ set deleted successfully" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── SUBMIT TEST + SAVE RESULT ────────────────
router.post("/submit", authMiddleware, async (req, res) => {
  try {
    const { mcqId, answers, timeTakenSeconds } = req.body;

    if (!mcqId || !answers || !Array.isArray(answers)) {
      return res.status(400).json({ message: "mcqId and answers array are required" });
    }

    const mcq = await prisma.mCQ.findUnique({
      where: { id: mcqId },
    });
    if (!mcq) return res.status(404).json({ message: "MCQ set not found" });

    const questionsList = Array.isArray(mcq.questions) ? mcq.questions : [];
    let correct = 0;
    let wrong = 0;
    let skipped = 0;
    const detailedAnswers = [];

    for (let i = 0; i < questionsList.length; i++) {
      const q = questionsList[i];
      const userAnswer = answers.find((a) => a.questionIndex === i);
      const selected = userAnswer ? userAnswer.selectedAnswer : null;

      const isCorrect = selected === q.correctAnswer;
      if (!selected) skipped++;
      else if (isCorrect) correct++;
      else wrong++;

      detailedAnswers.push({
        question: q.question,
        selectedAnswer: selected || "Skipped",
        correctAnswer: q.correctAnswer,
        isCorrect: !!isCorrect,
      });
    }

    const total = questionsList.length;
    const scorePercent = total > 0 ? Math.round((correct / total) * 100) : 0;

    let prediction = "";
    if (scorePercent >= 85) prediction = "Excellent! You are very well prepared for this topic.";
    else if (scorePercent >= 65) prediction = "Good performance. Review the topics you missed.";
    else if (scorePercent >= 40) prediction = "Needs improvement. Focus on weak areas before the exam.";
    else prediction = "Significant revision needed. Re-study this chapter thoroughly.";

    const result = await prisma.testResult.create({
      data: {
        userId: req.user.id,
        mcqId,
        title: mcq.title,
        subject: mcq.subject,
        chapter: mcq.chapter,
        totalQuestions: total,
        correctAnswers: correct,
        wrongAnswers: wrong,
        skippedAnswers: skipped,
        scorePercent: parseFloat(scorePercent),
        timeTakenSeconds: timeTakenSeconds || 0,
        answers: detailedAnswers,
        prediction,
      },
    });

    awardXP(req.user.id, "COMPLETE_TEST").catch(err => console.error('XP error:', err));
    
    if (scorePercent >= 80) {
      awardXP(req.user.id, "SCORE_ABOVE_80").catch(err => console.error('XP error:', err));
    } else if (scorePercent >= 60) {
      awardXP(req.user.id, "SCORE_ABOVE_60").catch(err => console.error('XP error:', err));
    }

    res.status(201).json({
      message: "Test submitted successfully!",
      result: {
        totalQuestions: total,
        correctAnswers: correct,
        wrongAnswers: wrong,
        skippedAnswers: skipped,
        scorePercent,
        prediction,
        resultId: result.id,
        _id: result.id,
      },
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET MY TEST HISTORY ──────────────────────
router.get("/my-results", authMiddleware, async (req, res) => {
  try {
    const results = await prisma.testResult.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        userId: true,
        mcqId: true,
        title: true,
        subject: true,
        chapter: true,
        totalQuestions: true,
        correctAnswers: true,
        wrongAnswers: true,
        skippedAnswers: true,
        scorePercent: true,
        timeTakenSeconds: true,
        prediction: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    const formatted = results.map(r => ({ ...r, _id: r.id }));
    res.status(200).json({ results: formatted });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE TEST RESULT (full detail) ─────
router.get("/my-results/:id", authMiddleware, async (req, res) => {
  try {
    const result = await prisma.testResult.findUnique({
      where: { id: req.params.id },
    });
    if (!result) return res.status(404).json({ message: "Result not found" });
    if (result.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    res.status(200).json({ result: { ...result, _id: result.id } });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

export default router;
