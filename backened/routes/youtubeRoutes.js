import express from "express";
import authMiddleware from "../Authentication/auth.js";
import { searchVideos, getVideoDetails } from "../services/youtubeService.js";
import User from "../models/users.js";
import dotenv from "dotenv";
import SavedVideo from '../models/youtubemodel.js'
dotenv.config();

const router = express.Router();



// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── SEARCH VIDEOS ────────────────────────
//
// Query params:
//   q              (required) search query string
//   maxResults     (optional, default 10, max 20)
//   educationLevel (optional) "school" | "undergraduate" | "postgraduate"
//
// Example: GET /api/youtube/search?q=calculus+derivatives&maxResults=8
//
router.get("/search", authMiddleware, async (req, res) => {
  try {
    const { q, maxResults, educationLevel } = req.query;

    if (!q || !q.trim()) {
      return res.status(400).json({ message: "Search query is required" });
    }

    const limit = Math.min(parseInt(maxResults) || 10, 20); // cap at 20

    const videos = await searchVideos(q.trim(), limit, educationLevel || "");

    if (videos.length === 0) {
      return res.status(200).json({
        message: "No videos found for this query",
        videos: [],
        total: 0,
      });
    }

    res.status(200).json({
      message: `Found ${videos.length} videos`,
      query: q.trim(),
      videos,
      total: videos.length,
    });
  } catch (e) {
    // YouTube API quota exceeded — friendly message
    if (e.message.includes("quota")) {
      return res.status(429).json({
        message: "YouTube API quota exceeded. Please try again tomorrow.",
      });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── SMART SUGGESTIONS ────────────────────
//
// Automatically suggests videos based on the user's
// registered subject and education level — no query needed.
// Great for the home screen "Recommended Lectures" section.
//
// Example: GET /api/youtube/suggestions
//
router.get("/suggestions", authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("subject educationLevel");
    if (!user) return res.status(404).json({ message: "User not found" });

    if (!user.subject) {
      return res.status(400).json({
        message: "Please set your subject in your profile to get suggestions",
      });
    }

    const videos = await searchVideos(user.subject, 10, user.educationLevel || "");

    res.status(200).json({
      message: `Suggested lectures for ${user.subject}`,
      subject: user.subject,
      educationLevel: user.educationLevel,
      videos,
      total: videos.length,
    });
  } catch (e) {
    if (e.message.includes("quota")) {
      return res.status(429).json({
        message: "YouTube API quota exceeded. Please try again tomorrow.",
      });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE VIDEO DETAILS ──────────────
//
// Example: GET /api/youtube/video/dQw4w9WgXcQ
//
router.get("/video/:videoId", authMiddleware, async (req, res) => {
  try {
    const { videoId } = req.params;

    const video = await getVideoDetails(videoId);
    if (!video) {
      return res.status(404).json({ message: "Video not found" });
    }

    res.status(200).json({ video });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── SAVE A VIDEO ─────────────────────────
//
// Body:
//   videoId     (required) string
//   title       (required) string
//   channelName (optional) string
//   thumbnail   (optional) string — medium thumbnail URL
//   url         (optional) string
//   duration    (optional) string
//   views       (optional) string
//   subject     (optional) string — what subject this belongs to
//
router.post("/save", authMiddleware, async (req, res) => {
  try {
    const { videoId, title, channelName, thumbnail, url, duration, views, subject } = req.body;

    if (!videoId || !title) {
      return res.status(400).json({ message: "videoId and title are required" });
    }

    const saved = await SavedVideo.create({
      userId: req.user.id,
      videoId,
      title,
      channelName: channelName || "",
      thumbnail: thumbnail || "",
      url: url || `https://www.youtube.com/watch?v=${videoId}`,
      duration: duration || "",
      views: views || "",
      subject: subject || "",
    });
awardXP(req.user.id, "SAVE_VIDEO").catch(console.error);

res.status(201).json({
  message: "Video saved successfully!",
  saved,
});
   
  } catch (e) {
    // Duplicate save — already saved this video
    if (e.code === 11000) {
      return res.status(409).json({ message: "You have already saved this video" });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SAVED VIDEOS ─────────────────────
//
// Optional query param: subject — filter by subject
// Example: GET /api/youtube/saved?subject=Mathematics
//
router.get("/saved", authMiddleware, async (req, res) => {
  try {
    const { subject } = req.query;

    const filter = { userId: req.user.id };
    if (subject) filter.subject = { $regex: subject, $options: "i" };

    const savedVideos = await SavedVideo.find(filter).sort({ createdAt: -1 });

    res.status(200).json({
      videos: savedVideos,
      total: savedVideos.length,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── UNSAVE A VIDEO ───────────────────────
router.delete("/saved/:videoId", authMiddleware, async (req, res) => {
  try {
    const deleted = await SavedVideo.findOneAndDelete({
      userId: req.user.id,
      videoId: req.params.videoId,
    });

    if (!deleted) {
      return res.status(404).json({ message: "Saved video not found" });
    }

    res.status(200).json({ message: "Video removed from saved list" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── ADD NOTES TO SAVED VIDEO ─────────────
//
// Body: { notes: "string" }
//
router.patch("/saved/:videoId/notes", authMiddleware, async (req, res) => {
  try {
    const { notes } = req.body;

    const updated = await SavedVideo.findOneAndUpdate(
      { userId: req.user.id, videoId: req.params.videoId },
      { notes: notes || "" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Saved video not found" });
    }

    res.status(200).json({
      message: "Notes updated",
      saved: updated,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── CHECK IF VIDEO IS SAVED ──────────────
//
// Flutter uses this to show filled/unfilled bookmark icon
// Example: GET /api/youtube/saved/check/dQw4w9WgXcQ
//
router.get("/saved/check/:videoId", authMiddleware, async (req, res) => {
  try {
    const exists = await SavedVideo.exists({
      userId: req.user.id,
      videoId: req.params.videoId,
    });
    res.status(200).json({ isSaved: !!exists });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

export default router;