import { fileURLToPath } from "url";
import { dirname, join } from "path";
import dotenv from "dotenv";

// ── Load .env FIRST before any other imports ──
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, ".env") });

// ── Now import everything else ─────────────────
import express from "express";
import cors from "cors";
import morgan from "morgan";
import helmet from "helmet";
import connectDB from "./db.js";
import { globalRateLimiter } from "./middleware/rateLimiter.js";

import router from "./routes/user.js";
import notesRouter from "./routes/notes.js";
import mcqRoutes from "./routes/mcqRoutes.js";
import chatRoutes from "./routes/chatRoutes.js";
import youtubeRoutes from "./routes/youtubeRoutes.js";
import mlRoutes from "./routes/mlRoutes.js";
import profileRoutes from "./routes/profileRoutes.js";
import generateRoutes from "./routes/generateRoutes.js";
import achievementRoutes from "./routes/achievementRoutes.js";
import groupRoutes from "./routes/groupRoutes.js";
import analyticsRoutes from "./routes/analyticsRoutes.js";
import communityRoutes from "./routes/communityRoutes.js";
import battleRoutes from "./routes/battleRoutes.js";
import bookmarkRoutes from "./routes/bookmarkRoutes.js";
import dictionaryRoutes from "./routes/dictionaryRoutes.js";
import medicalSearchRoutes from "./routes/medicalSearchRoutes.js";
import { startDictionarySyncJob } from "./background-jobs/dictionarySync.js";

const app = express();

const allowedOrigins = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" },
  })
);

app.use(
  cors({
    origin: allowedOrigins.length > 0 ? allowedOrigins : true,
    credentials: true,
  })
);

// JSON endpoints contain metadata and chat messages, not PDF files. Keeping a
// small limit protects each server process from oversized request bodies.
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true, limit: "2mb" }));
app.use(morgan("dev"));
app.use(globalRateLimiter);

// ── Connect to PostgreSQL via Prisma ───────────────
connectDB();

// ── Routes ─────────────────────────────────────
app.get("/", (req, res) => {
  res.json({
    message: "Lumio API is running 🚀",
    version: "1.0.0",
    endpoints: {
      auth: "/api/auth",
      notes: "/api/notes",
      mcq: "/api/mcq",
      chat: "/api/chat",
      generate: "/api/generate",
    },
  });
});

app.use("/api/auth", router);
app.use("/api/notes", notesRouter);
app.use("/api/mcq", mcqRoutes);
app.use("/api/chat", chatRoutes);
app.use("/api/youtube", youtubeRoutes);
app.use("/api/ml", mlRoutes);
app.use("/api/profile", profileRoutes);
app.use("/api/generate", generateRoutes);
app.use("/api/achievements", achievementRoutes);
app.use("/api/groups", groupRoutes);
app.use("/api/analytics", analyticsRoutes);
app.use("/api/community", communityRoutes);
app.use("/api/battle", battleRoutes);
app.use("/api/bookmarks", bookmarkRoutes);
app.use("/api/dictionary", dictionaryRoutes);
app.use("/api/medical", medicalSearchRoutes);

// ── 404 Handler ────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.url} not found` });
});

// ── Global Error Handler ───────────────────────
app.use((err, req, res, next) => {
  if (err.code === "LIMIT_FILE_SIZE") {
    return res.status(413).json({ message: "The uploaded file is too large." });
  }
  if (err.name === "MulterError") {
    return res.status(400).json({ message: "The uploaded file could not be processed." });
  }
  console.error("❌ Server error:", err.message);
  res.status(err.status || 500).json({
    message: err.message || "Internal server error",
  });
});

// ── Start Server ───────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`📡 http://localhost:${PORT}`);
  startDictionarySyncJob();
});
