import express from "express";
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");
import upload from "../middleware/upload.js";
import MCQ from "../models/mcqs.js";
import authMiddleware from "../Authentication/auth.js";
import dotenv from "dotenv";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// HELPER FUNCTIONS (shared with notesRoutes)
// ══════════════════════════════════════════

// 1. Extract text from PDF
const extractTextFromPDF = async (bufferfile) => {
  const data = await pdfParse(bufferfile);
  return data.text;
};

// 2. Detect chapters
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

// 3. Detect sections
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

// 4. Analyze document structure
const analyzeDocument = (fullText) => {
  const chapters = detectChapters(fullText);
  if (chapters.length > 0) return { type: "book", divisions: chapters };

  const sections = detectSections(fullText);
  if (sections.length > 0) return { type: "document", divisions: sections };

  return { type: "plain", divisions: [] };
};

// 5. Extract a division's text
const extractDivisionText = (fullText, division) => {
  return fullText.slice(division.startIndex, division.endIndex).trim();
};

// 6. Chunk text
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

// 7. Ask Groq to generate MCQs from a chunk
const generateMCQsFromChunk = async (chunk, numQuestions, difficulty) => {
  const difficultyGuide = {
    easy: "Focus on basic definitions, facts, and simple recall questions.",
    medium: "Include application and comprehension questions. Mix recall with understanding.",
    hard: "Focus on analysis, inference, and deep understanding. Avoid surface-level questions.",
  };

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama-3.1-8b-instant",
      messages: [
        {
          role: "system",
          content: `You are an expert MCQ generator for students. 
Generate exactly ${numQuestions} multiple choice questions from the given text.
Difficulty level: ${difficulty}. ${difficultyGuide[difficulty]}

STRICT RULES:
- Return ONLY a valid JSON array. No extra text, no markdown, no backticks.
- Each object must have exactly these keys:
  "question" (string),
  "options" (array of exactly 4 strings — label them A) B) C) D) inside the string),
  "correctAnswer" (string — must exactly match one of the options),
  "explanation" (string — 1-2 sentences why the answer is correct)
- Make all 4 options plausible. Avoid obviously wrong distractors.
- Base every question strictly on the provided text.`,
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
    console.log("Groq MCQ error:", res.status, text);
    throw new Error(`Groq error: ${res.status}`);
  }

  const data = await res.json();
  const raw = data.choices[0].message.content.trim();

  // Strip markdown code fences if model adds them
  const cleaned = raw.replace(/```json|```/g, "").trim();

  try {
    const parsed = JSON.parse(cleaned);
    return Array.isArray(parsed) ? parsed : [];
  } catch (e) {
    console.log("MCQ JSON parse error:", e.message, "\nRaw:", cleaned.slice(0, 300));
    return [];
  }
};

// 8. Process one division and collect MCQs
const processDivisionForMCQ = async (text, totalQuestions, difficulty) => {
  const chunks = chunkText(text);
  if (chunks.length === 0) return [];

  // Distribute questions evenly across chunks
  const questionsPerChunk = Math.ceil(totalQuestions / chunks.length);
  let allQuestions = [];

  for (let i = 0; i < chunks.length; i++) {
    console.log(`MCQ chunk ${i + 1}/${chunks.length}`);
    // Don't over-generate — last chunk gets the remainder
    const needed = Math.min(questionsPerChunk, totalQuestions - allQuestions.length);
    if (needed <= 0) break;

    const questions = await generateMCQsFromChunk(chunks[i], needed, difficulty);
    allQuestions = allQuestions.concat(questions);
  }

  // Trim to exactly the requested count
  return allQuestions.slice(0, totalQuestions);
};

// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── SCAN (reuse same scan logic as notes) ──
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
        divisions: divisions.map((c) => c.name),
      });
    }

    if (type === "document") {
      return res.status(200).json({
        message: `Document detected — found ${divisions.length} sections`,
        documentType: "document",
        divisions: divisions.map((s) => s.name),
      });
    }

    return res.status(200).json({
      message: "Plain document detected — MCQs will be generated from full text",
      documentType: "plain",
      divisions: [],
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GENERATE MCQs ─────────────────────────
//
// Body params:
//   title        (required) string
//   subject      (optional) string
//   mode         (required) "single" | "multiple" | "full"
//   chapter      (required if mode=single) string — division name
//   chapters     (required if mode=multiple) JSON string array
//   numQuestions (optional, default 10) number — total MCQs to generate
//   difficulty   (optional, default "medium") "easy" | "medium" | "hard"
//
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

    const totalQ = Math.min(Math.max(parseInt(numQuestions) || 10, 1), 50); // clamp 1–50

    const fullText = await extractTextFromPDF(req.file.buffer);
    const { type, divisions } = analyzeDocument(fullText);

    let allQuestions = [];
    let chapterLabel = "Full Document";

    // ── PLAIN DOCUMENT ────────────────────────────
    if (type === "plain" || (mode === "full" && divisions.length === 0)) {
      allQuestions = await processDivisionForMCQ(fullText, totalQ, difficulty);
      chapterLabel = "Full Document";

    // ── SINGLE CHAPTER / SECTION ──────────────────
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
      allQuestions = await processDivisionForMCQ(text, totalQ, difficulty);
      chapterLabel = found.name;

    // ── MULTIPLE CHAPTERS / SECTIONS ─────────────
    } else if (mode === "multiple") {
      const chapterList = JSON.parse(chapters);
      if (!chapterList || chapterList.length === 0) {
        return res.status(400).json({ message: "Please select at least one chapter or section" });
      }

      // Divide total questions evenly across selected chapters
      const qPerChapter = Math.ceil(totalQ / chapterList.length);

      for (const chName of chapterList) {
        const found = divisions.find((d) =>
          d.name.toLowerCase().includes(chName.toLowerCase())
        );
        if (!found) continue;

        const text = extractDivisionText(fullText, found);
        const needed = Math.min(qPerChapter, totalQ - allQuestions.length);
        if (needed <= 0) break;

        const questions = await processDivisionForMCQ(text, needed, difficulty);
        allQuestions = allQuestions.concat(questions);
      }

      chapterLabel = chapterList.join(", ");

    // ── FULL BOOK / FULL DOCUMENT ─────────────────
    } else if (mode === "full") {
      const qPerDivision = Math.ceil(totalQ / divisions.length);

      for (const division of divisions) {
        const text = extractDivisionText(fullText, division);
        if (text.length < 100) continue;

        const needed = Math.min(qPerDivision, totalQ - allQuestions.length);
        if (needed <= 0) break;

        const questions = await processDivisionForMCQ(text, needed, difficulty);
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

    const savedMCQ = await MCQ.create({
      userId: req.user.id,
      title,
      subject,
      chapter: chapterLabel,
      documentType: type,
      questions: allQuestions,
    });
awardXP(req.user.id, "GENERATE_MCQ").catch(console.error);

    res.status(201).json({
      message: `${allQuestions.length} MCQs generated successfully!`,
      mcq: savedMCQ,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET ALL MCQs (list, no questions array) ─
router.get("/my-mcqs", authMiddleware, async (req, res) => {
  try {
    const mcqs = await MCQ.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .select("-questions"); // exclude heavy questions array for list view
    res.status(200).json({ mcqs });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE MCQ (with all questions) ─────
router.get("/my-mcqs/:id", authMiddleware, async (req, res) => {
  try {
    const mcq = await MCQ.findById(req.params.id);
    if (!mcq) return res.status(404).json({ message: "MCQ set not found" });
    if (mcq.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    res.status(200).json({ mcq });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── DELETE MCQ ───────────────────────────────
router.delete("/delete-mcq/:id", authMiddleware, async (req, res) => {
  try {
    const mcq = await MCQ.findById(req.params.id);
    if (!mcq) return res.status(404).json({ message: "MCQ set not found" });
    if (mcq.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    await MCQ.findByIdAndDelete(req.params.id);
    res.status(200).json({ message: "MCQ set deleted successfully" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── SUBMIT TEST + SAVE RESULT ────────────────
//
// Body:
//   mcqId           (required) string
//   answers         (required) array of { questionIndex, selectedAnswer }
//   timeTakenSeconds (optional) number
//
// This scores the test and saves it to TestResult model
//
router.post("/submit", authMiddleware, async (req, res) => {
  try {
    const { mcqId, answers, timeTakenSeconds } = req.body;

    if (!mcqId || !answers || !Array.isArray(answers)) {
      return res.status(400).json({ message: "mcqId and answers array are required" });
    }

    const mcq = await MCQ.findById(mcqId);
    if (!mcq) return res.status(404).json({ message: "MCQ set not found" });

    let correct = 0;
    let wrong = 0;
    let skipped = 0;
    const detailedAnswers = [];

    for (let i = 0; i < mcq.questions.length; i++) {
      const q = mcq.questions[i];
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

    const total = mcq.questions.length;
    const scorePercent = Math.round((correct / total) * 100);

    // Simple prediction message
    let prediction = "";
    if (scorePercent >= 85) prediction = "Excellent! You are very well prepared for this topic.";
    else if (scorePercent >= 65) prediction = "Good performance. Review the topics you missed.";
    else if (scorePercent >= 40) prediction = "Needs improvement. Focus on weak areas before the exam.";
    else prediction = "Significant revision needed. Re-study this chapter thoroughly.";

    // Dynamically import TestResult to avoid circular issues
    const { default: TestResult } = await import("../models/testResult.js");

    const result = await TestResult.create({
      userId: req.user.id,
      mcqId,
      title: mcq.title,
      subject: mcq.subject,
      chapter: mcq.chapter,
      totalQuestions: total,
      correctAnswers: correct,
      wrongAnswers: wrong,
      skippedAnswers: skipped,
      scorePercent,
      timeTakenSeconds: timeTakenSeconds || 0,
      answers: detailedAnswers,
      prediction,
    });
 await awardXP(req.user.id, "COMPLETE_TEST");
 
 // Bonus XP based on score
 if (scorePercent >= 80) {
   await awardXP(req.user.id, "SCORE_ABOVE_80");
 } else if (scorePercent >= 60) {
   await awardXP(req.user.id, "SCORE_ABOVE_60");
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
        resultId: result._id,
      },
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET MY TEST HISTORY ──────────────────────
router.get("/my-results", authMiddleware, async (req, res) => {
  try {
    const { default: TestResult } = await import("../models/testResult.js");
    const results = await TestResult.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .select("-answers"); // exclude per-question detail for list view
    res.status(200).json({ results });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE TEST RESULT (full detail) ─────
router.get("/my-results/:id", authMiddleware, async (req, res) => {
  try {
    const { default: TestResult } = await import("../models/testResult.js");
    const result = await TestResult.findById(req.params.id);
    if (!result) return res.status(404).json({ message: "Result not found" });
    if (result.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    res.status(200).json({ result });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

export default router;