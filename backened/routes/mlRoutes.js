import express from "express";
import authMiddleware from "../Authentication/auth.js";
import dotenv from "dotenv";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// CONFIG
// ══════════════════════════════════════════

const ML_SERVICE_URL = process.env.ML_SERVICE_URL || "http://localhost:8000";

// ══════════════════════════════════════════
// HELPER — call the Python ML service
// ══════════════════════════════════════════

const callML = async (endpoint, body) => {
  const res = await fetch(`${ML_SERVICE_URL}${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: "ML service error" }));
    throw new Error(err.detail || `ML service error: ${res.status}`);
  }

  return res.json();
};

// Load user's test results from MongoDB
const getUserResults = async (userId) => {
  const { default: TestResult } = await import("../models/testResult.js");
  const results = await TestResult.find({ userId })
    .sort({ createdAt: 1 }) // oldest first — important for trend analysis
    .select(
      "subject chapter totalQuestions correctAnswers wrongAnswers skippedAnswers scorePercent timeTakenSeconds"
    )
    .lean();

  // Map to the shape Python expects
  return results.map((r) => ({
    subject: r.subject || "Unknown",
    chapter: r.chapter || "General",
    totalQuestions: r.totalQuestions || 0,
    correctAnswers: r.correctAnswers || 0,
    wrongAnswers: r.wrongAnswers || 0,
    skippedAnswers: r.skippedAnswers || 0,
    scorePercent: r.scorePercent || 0,
    timeTakenSeconds: r.timeTakenSeconds || 0,
    difficulty: r.difficulty || "medium",
  }));
};

// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── HEALTH CHECK ─────────────────────────
// Check if Python ML service is running
router.get("/health", async (req, res) => {
  try {
    const response = await fetch(`${ML_SERVICE_URL}/health`);
    const data = await response.json();
    res.status(200).json({ mlService: data });
  } catch (e) {
    res.status(503).json({
      message: "ML service is not running",
      hint: "Start it with: cd ml-service && python app.py",
    });
  }
});

// ─── EXAM SCORE PREDICTION ────────────────
//
// Predicts what score the user will get in an upcoming exam
// for a specific subject/chapter based on their test history.
//
// Body:
//   targetSubject  (required) string
//   targetChapter  (optional) string
//
router.post("/predict", authMiddleware, async (req, res) => {
  try {
    const { targetSubject, targetChapter } = req.body;

    if (!targetSubject) {
      return res.status(400).json({ message: "targetSubject is required" });
    }

    const results = await getUserResults(req.user.id);

    const data = await callML("/predict", {
      results,
      targetSubject,
      targetChapter: targetChapter || "",
      educationLevel: req.user.educationLevel || "undergraduate",
    });

    res.status(200).json(data);
  } catch (e) {
    if (e.message.includes("fetch failed") || e.message.includes("ECONNREFUSED")) {
      return res.status(503).json({
        message: "ML service is offline. Start it with: python app.py",
      });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── WEAK TOPIC DETECTION ─────────────────
//
// Returns subjects/chapters where the user consistently scores poorly.
// No body needed — uses user's full test history automatically.
//
router.get("/weak-topics", authMiddleware, async (req, res) => {
  try {
    const results = await getUserResults(req.user.id);

    if (results.length === 0) {
      return res.status(200).json({
        weakTopics: [],
        message: "No test history found. Complete some MCQ tests first.",
      });
    }

    const data = await callML("/weak-topics", { results });
    res.status(200).json(data);
  } catch (e) {
    if (e.message.includes("fetch failed") || e.message.includes("ECONNREFUSED")) {
      return res.status(503).json({ message: "ML service is offline." });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── PERFORMANCE ANALYSIS ─────────────────
//
// Full breakdown — overall stats, per-subject trends,
// best/worst subjects, score history, difficulty breakdown.
//
router.get("/performance", authMiddleware, async (req, res) => {
  try {
    const results = await getUserResults(req.user.id);

    if (results.length === 0) {
      return res.status(200).json({
        analysis: null,
        message: "No test history found. Complete some MCQ tests first.",
      });
    }

    const data = await callML("/performance", { results });
    res.status(200).json(data);
  } catch (e) {
    if (e.message.includes("fetch failed") || e.message.includes("ECONNREFUSED")) {
      return res.status(503).json({ message: "ML service is offline." });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── STUDY RECOMMENDATIONS ────────────────
//
// Prioritized list of what the user should study next
// based on their weak topics + performance trends.
//
router.get("/recommendations", authMiddleware, async (req, res) => {
  try {
    const results = await getUserResults(req.user.id);

    if (results.length === 0) {
      return res.status(200).json({
        recommendations: [
          {
            priority: 1,
            type: "get_started",
            subject: "Any subject",
            chapter: "General",
            reason: "No test history yet",
            action: "Upload a PDF and generate your first MCQ test to get personalized recommendations.",
            estimatedStudyHours: 1,
          },
        ],
      });
    }

    const data = await callML("/recommendations", { results });
    res.status(200).json(data);
  } catch (e) {
    if (e.message.includes("fetch failed") || e.message.includes("ECONNREFUSED")) {
      return res.status(503).json({ message: "ML service is offline." });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── FULL DASHBOARD ───────────────────────
//
// Combines prediction + weak topics + performance + recommendations
// in a single call — ideal for the Flutter dashboard screen.
//
// Query param: subject (optional) — for prediction
//
router.get("/dashboard", authMiddleware, async (req, res) => {
  try {
    const { subject } = req.query;
    const results = await getUserResults(req.user.id);

    if (results.length === 0) {
      return res.status(200).json({
        hasData: false,
        message: "Complete some MCQ tests to unlock your AI dashboard.",
      });
    }

    // Run all 3 analyses in parallel — much faster than sequential
    const [weakData, perfData, recsData] = await Promise.all([
      callML("/weak-topics", { results }),
      callML("/performance", { results }),
      callML("/recommendations", { results }),
    ]);

    // Prediction is optional — only if subject provided
    let predictionData = null;
    if (subject) {
      predictionData = await callML("/predict", {
        results,
        targetSubject: subject,
        educationLevel: req.user.educationLevel || "undergraduate",
      });
    }

    res.status(200).json({
      hasData: true,
      totalTests: results.length,
      weakTopics: weakData.weakTopics,
      performance: perfData.analysis,
      recommendations: recsData.recommendations,
      prediction: predictionData?.prediction || null,
    });
  } catch (e) {
    if (e.message.includes("fetch failed") || e.message.includes("ECONNREFUSED")) {
      return res.status(503).json({ message: "ML service is offline." });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

export default router;