import express from "express";
import authMiddleware from "../Authentication/auth.js";
import { searchVideos, getVideoDetails } from "../services/youtubeService.js";
import prisma from "../prisma.js";
import dotenv from "dotenv";
import { awardXP } from "../services/xpService.js";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── SEARCH VIDEOS ────────────────────────
router.get("/search", authMiddleware, async (req, res) => {
  try {
    const { q, maxResults, educationLevel } = req.query;

    if (!q || !q.trim()) {
      return res.status(400).json({ message: "Search query is required" });
    }

    const limit = Math.min(parseInt(maxResults) || 10, 20);

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
    console.error("YouTube search error:", e);
    
    if (e.message && e.message.includes("quota")) {
      return res.status(429).json({
        message: "YouTube API quota exceeded. Please try again tomorrow.",
      });
    }
    
    if (e.message && e.message.includes("API key")) {
      return res.status(401).json({
        message: "YouTube API key is invalid or expired. Please contact support.",
      });
    }
    
    if (e.code === 'ENOTFOUND' || e.code === 'ECONNREFUSED') {
      return res.status(503).json({
        message: "Unable to connect to YouTube. Please check your internet connection.",
      });
    }
    
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to search videos";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── SMART SUGGESTIONS ────────────────────
router.get("/suggestions", authMiddleware, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { subject: true, educationLevel: true },
    });
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
    console.error("YouTube suggestions error:", e);
    
    if (e.message && e.message.includes("quota")) {
      return res.status(429).json({
        message: "YouTube API quota exceeded. Please try again tomorrow.",
      });
    }
    
    if (e.message && e.message.includes("API key")) {
      return res.status(401).json({
        message: "YouTube API key is invalid or expired. Please contact support.",
      });
    }
    
    if (e.code === 'ENOTFOUND' || e.code === 'ECONNREFUSED') {
      return res.status(503).json({
        message: "Unable to connect to YouTube. Please check your internet connection.",
      });
    }
    
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to get suggestions";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── GET SINGLE VIDEO DETAILS ──────────────
router.get("/video/:videoId", authMiddleware, async (req, res) => {
  try {
    const { videoId } = req.params;

    const video = await getVideoDetails(videoId);
    if (!video) {
      return res.status(404).json({ message: "Video not found" });
    }

    res.status(200).json({ video });
  } catch (e) {
    console.error("Get video details error:", e);
    
    if (e.message && e.message.includes("quota")) {
      return res.status(429).json({
        message: "YouTube API quota exceeded. Please try again tomorrow.",
      });
    }
    
    if (e.message && e.message.includes("API key")) {
      return res.status(401).json({
        message: "YouTube API key is invalid or expired. Please contact support.",
      });
    }
    
    if (e.code === 'ENOTFOUND' || e.code === 'ECONNREFUSED') {
      return res.status(503).json({
        message: "Unable to connect to YouTube. Please check your internet connection.",
      });
    }
    
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to get video details";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── SAVE A VIDEO ─────────────────────────
router.post("/save", authMiddleware, async (req, res) => {
  try {
    const { videoId, title, channelName, thumbnail, url, duration, views, subject } = req.body;

    if (!videoId || !title) {
      return res.status(400).json({ message: "videoId and title are required" });
    }

    const saved = await prisma.savedVideo.create({
      data: {
        userId: req.user.id,
        videoId,
        title,
        channelName: channelName || "",
        thumbnail: thumbnail || "",
        url: url || `https://www.youtube.com/watch?v=${videoId}`,
        duration: duration || "",
        views: views || "",
        subject: subject || "",
      },
    });

    awardXP(req.user.id, "SAVE_VIDEO").catch(err => console.error('XP award error:', err));

    res.status(201).json({
      message: "Video saved successfully!",
      saved: { ...saved, _id: saved.id },
    });
   
  } catch (e) {
    if (e.code === "P2002") {
      return res.status(409).json({ message: "You have already saved this video" });
    }
    console.error('Save video error:', e);
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SAVED VIDEOS ─────────────────────
router.get("/saved", authMiddleware, async (req, res) => {
  try {
    const { subject } = req.query;

    const where = { userId: req.user.id };
    if (subject) {
      where.subject = { contains: subject, mode: "insensitive" };
    }

    const savedVideos = await prisma.savedVideo.findMany({
      where,
      orderBy: { createdAt: "desc" },
    });

    const formatted = savedVideos.map(v => ({ ...v, _id: v.id }));

    res.status(200).json({
      videos: formatted,
      total: formatted.length,
    });
  } catch (e) {
    console.error("Get saved videos error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to load saved videos";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── UNSAVE A VIDEO ───────────────────────
router.delete("/saved/:videoId", authMiddleware, async (req, res) => {
  try {
    const result = await prisma.savedVideo.deleteMany({
      where: {
        userId: req.user.id,
        videoId: req.params.videoId,
      },
    });

    if (result.count === 0) {
      return res.status(404).json({ message: "Saved video not found" });
    }

    res.status(200).json({ message: "Video removed from saved list" });
  } catch (e) {
    console.error("Unsave video error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to remove video";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── ADD NOTES TO SAVED VIDEO ─────────────
router.patch("/saved/:videoId/notes", authMiddleware, async (req, res) => {
  try {
    const { notes } = req.body;

    const existing = await prisma.savedVideo.findUnique({
      where: {
        userId_videoId: {
          userId: req.user.id,
          videoId: req.params.videoId,
        },
      },
    });

    if (!existing) {
      return res.status(404).json({ message: "Saved video not found" });
    }

    const updated = await prisma.savedVideo.update({
      where: {
        userId_videoId: {
          userId: req.user.id,
          videoId: req.params.videoId,
        },
      },
      data: { notes: notes || "" },
    });

    res.status(200).json({
      message: "Notes updated",
      saved: { ...updated, _id: updated.id },
    });
  } catch (e) {
    console.error("Update video notes error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to update notes";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── CHECK IF VIDEO IS SAVED ──────────────
router.get("/saved/check/:videoId", authMiddleware, async (req, res) => {
  try {
    const saved = await prisma.savedVideo.findUnique({
      where: {
        userId_videoId: {
          userId: req.user.id,
          videoId: req.params.videoId,
        },
      },
    });
    res.status(200).json({ isSaved: !!saved });
  } catch (e) {
    console.error("Check saved video error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to check saved status";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

export default router;