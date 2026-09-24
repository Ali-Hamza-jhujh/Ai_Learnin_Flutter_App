import express from "express";
import authMiddleware from "../Authentication/auth.js";
import adminMiddleware from "../middleware/adminMiddleware.js";
import {
  searchDictionary,
  autocomplete,
  getTopicBySlug,
  toggleBookmark,
  getBookmarks,
  getDictionaryStats,
  getItemsByCategory,
  deleteDictionaryItem,
} from "../controllers/dictionaryController.js";

const router = express.Router();

// Get items in a specific category (public, supports query search string)
router.get("/category/:category", getItemsByCategory);

// Autocomplete suggestions (public)
router.get("/autocomplete", autocomplete);

// Search a topic (public, optionally logs search if authenticated)
router.get("/search", searchDictionary);

// Get home statistics (public)
router.get("/stats", getDictionaryStats);

// Get bookmarks (auth required)
router.get("/bookmarks", authMiddleware, getBookmarks);

// Toggle bookmark (auth required)
router.post("/bookmark", authMiddleware, toggleBookmark);

// Get topic details by slug (public, optionally logs view if authenticated)
router.get("/topic/:slug", getTopicBySlug);

// Admin: Delete a dictionary item by ID (auth + admin required)
router.delete("/item/:id", authMiddleware, adminMiddleware, deleteDictionaryItem);

export default router;
