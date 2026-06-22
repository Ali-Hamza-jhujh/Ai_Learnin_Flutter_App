import { fileURLToPath } from "url";
import { dirname, join } from "path";
import dotenv from "dotenv";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
dotenv.config({ path: join(__dirname, ".env") });

import express from "express";
import cors    from "cors";
import morgan  from "morgan";
import connectDB from "./db.js";

import router            from "./routes/user.js";
import notesRouter       from "./routes/notes.js";
import mcqRoutes         from "./routes/mcqRoutes.js";
import chatRoutes        from "./routes/chatRoutes.js";
import youtubeRoutes     from "./routes/youtubeRoutes.js";
import mlRoutes          from "./routes/mlRoutes.js";
import profileRoutes     from "./routes/profileRoutes.js";
import notificationRoutes from "./routes/notificationRoutes.js";
import generateRoutes    from "./routes/generateRoutes.js"; // ← NEW

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());
app.use(morgan("dev"));

connectDB();

app.get("/", (req, res) => {
  res.json({
    message: "StudyAI API is running 🚀",
    version: "1.0.0",
    endpoints: {
      auth:     "/api/auth",
      notes:    "/api/notes",
      mcq:      "/api/mcq",
      chat:     "/api/chat",
      generate: "/api/generate",   // ← NEW
    },
  });
});

app.use("/api/auth",          router);
app.use("/api/notes",         notesRouter);
app.use("/api/mcq",           mcqRoutes);
app.use("/api/chat",          chatRoutes);
app.use("/api/youtube",       youtubeRoutes);
app.use("/api/ml",            mlRoutes);
app.use("/api/profile",       profileRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/generate",      generateRoutes);   // ← NEW

app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.url} not found` });
});

app.use((err, req, res, next) => {
  console.error("❌ Server error:", err.message);
  res.status(err.status || 500).json({
    message: err.message || "Internal server error",
  });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`📡 http://localhost:${PORT}`);
});