// Medical Dictionary Routes — Enhanced & Fixed
// All imports at top, uses rewritten medicalAPICaller, 14 total endpoints

import express from "express";
import authMiddleware from "../Authentication/auth.js";
import prisma from "../prisma.js";
import { processQuery } from "../services/queryProcessor.js";
import { detectCategory } from "../services/categoryDetector.js";
import { fetchCompleteTopicData } from "../services/medicalAPICaller.js";

const router = express.Router();

// ═════════════════════════════════════════
// 1. GET ALL CATEGORIES WITH KEYWORDS
// ═════════════════════════════════════════
// GET /api/medical/categories
router.get("/categories", async (req, res) => {
  try {
    const CATEGORIES = [
      "Diseases",
      "Drugs",
      "Anatomy",
      "Physiology",
      "Biochemistry",
      "Histology",
      "Pharmacology",
      "Lab Values",
      "Clinical Concepts",
      "Procedures",
      "Medical Terminologies",
      "Research Papers",
      "Medical Images",
      "Syndromes",
      "Body Systems",
      "Medical Classifications",
    ];

    const categoriesWithItems = await Promise.all(
      CATEGORIES.map(async (category) => {
        const [topItems, count] = await Promise.all([
          prisma.dictionaryItem.findMany({
            where: { category },
            take: 10,
            select: { title: true, slug: true, keywords: true, category: true, images: true },
          }),
          prisma.dictionaryItem.count({ where: { category } }),
        ]);

        return {
          name: category,
          count,
          topItems: topItems.map((item) => {
            const images = Array.isArray(item.images) ? item.images : [];
            const keywords = Array.isArray(item.keywords) ? item.keywords : [];
            return {
              title: item.title,
              slug: item.slug,
              keywords: keywords.slice(0, 5),
              thumbnail: images[0]?.thumbnailUrl || images[0]?.url || null,
            };
          }),
        };
      })
    );

    return res.status(200).json({
      categories: categoriesWithItems,
      total: categoriesWithItems.reduce((sum, cat) => sum + cat.count, 0),
    });
  } catch (error) {
    console.error("❌ Error fetching categories:", error);
    return res.status(500).json({ message: "Error fetching categories", error: error.message });
  }
});

// ═════════════════════════════════════════
// 2. GET KEYWORDS FOR SPECIFIC CATEGORY
// ═════════════════════════════════════════
// GET /api/medical/category/:categoryName/keywords
router.get("/category/:categoryName/keywords", async (req, res) => {
  const { categoryName } = req.params;

  try {
    const items = await prisma.dictionaryItem.findMany({
      where: { category: categoryName },
      orderBy: [{ searchCount: "desc" }, { viewCount: "desc" }],
      take: 50,
      select: {
        id: true,
        title: true,
        slug: true,
        keywords: true,
        category: true,
        images: true,
        description: true,
        viewCount: true,
      },
    });

    if (items.length === 0) {
      return res.status(200).json({
        success: true,
        category: categoryName,
        count: 0,
        items: [],
        message: `No items found for category "${categoryName}". Search to populate.`,
      });
    }

    const formatted = items.map((item) => {
      const images = Array.isArray(item.images) ? item.images : [];
      const keywords = Array.isArray(item.keywords) ? item.keywords : [];
      return {
        id: item.id,
        _id: item.id,
        title: item.title,
        slug: item.slug,
        keywords: keywords.slice(0, 5),
        category: categoryName,
        description: item.description?.substring(0, 100) || "",
        images: images.map((img) => ({
          id: img.id || img._id,
          thumbnail: img.thumbnailUrl || img.url,
          medium: img.mediumUrl || img.url,
          url: img.url,
          caption: img.caption,
          creator: img.creator,
          license: img.license,
        })),
        thumbnail: images[0]?.thumbnailUrl || images[0]?.url || null,
        viewCount: item.viewCount || 0,
      };
    });

    return res.status(200).json({
      success: true,
      category: categoryName,
      count: formatted.length,
      items: formatted,
    });
  } catch (error) {
    console.error("❌ Error fetching category keywords:", error);
    return res.status(500).json({ message: "Error fetching keywords", error: error.message });
  }
});

// ═════════════════════════════════════════
// 3. REAL-TIME SEARCH (LOCAL DB ONLY)
// ═════════════════════════════════════════
// GET /api/medical/search?q=diabetes
router.get("/search", async (req, res) => {
  const { q, limit = 10 } = req.query;
  const userId = req.user?.id;

  if (!q || q.trim().length < 2) {
    return res.status(400).json({ message: "Search query must be at least 2 characters" });
  }

  const searchQuery = q.trim();

  try {
    const processed = processQuery(searchQuery);

    const results = await prisma.dictionaryItem.findMany({
      where: {
        OR: [
          { title: { contains: processed.processedQuery, mode: "insensitive" } },
          { slug: { contains: processed.processedQuery, mode: "insensitive" } },
          { description: { contains: processed.processedQuery, mode: "insensitive" } },
        ],
      },
      take: parseInt(limit),
      orderBy: { searchCount: "desc" },
    });

    const formattedResults = results.map((item) => {
      const images = Array.isArray(item.images) ? item.images : [];
      const keywords = Array.isArray(item.keywords) ? item.keywords : [];
      return {
        id: item.id,
        _id: item.id,
        title: item.title,
        slug: item.slug,
        category: item.category,
        description: item.description,
        images: images.map((img) => ({
          id: img.id || img._id,
          thumbnail: img.thumbnailUrl || img.url,
          medium: img.mediumUrl || img.url,
          url: img.url,
          caption: img.caption,
          creator: img.creator,
          license: img.license,
        })),
        thumbnail: images[0]?.thumbnailUrl || images[0]?.url || null,
        viewCount: item.viewCount || 0,
        keywords: keywords.slice(0, 5),
      };
    });

    if (userId) {
      prisma.dictionarySearchHistory.create({
        data: {
          userId,
          query: searchQuery,
        },
      }).catch((err) => console.error("⚠️ Failed to log search:", err.message));
    }

    return res.status(200).json({
      success: true,
      query: searchQuery,
      processedQuery: processed.processedQuery,
      intent: processed.intent,
      resultsCount: results.length,
      results: formattedResults,
      source: "database",
    });
  } catch (error) {
    console.error("❌ Error searching:", error);
    return res.status(500).json({ message: "Error searching", error: error.message });
  }
});

// ═════════════════════════════════════════
// 4. GET FULL TOPIC DETAILS (CLICK RESULT)
// ═════════════════════════════════════════
// GET /api/medical/topic/:slug
router.get("/topic/:slug", async (req, res) => {
  const { slug } = req.params;

  try {
    console.log(`\n📌 GET /api/medical/topic/${slug}`);

    let item = await prisma.dictionaryItem.findUnique({ where: { slug } });

    const isPlaceholder = item && (
      !item.overview?.definition ||
      item.overview.definition.includes("item for") ||
      item.overview.definition.includes("is a medical topic classified under") ||
      item.description?.includes("item for") ||
      item.description?.includes("is a medical topic classified under") ||
      ((item.category === "Diseases" || item.category === "Anatomy") && 
       (!item.clinicalInfo || Object.keys(item.clinicalInfo).length === 0))
    );

    if (!item || isPlaceholder) {
      console.log(item ? "   Placeholder/incomplete entry detected → Fetching from external APIs..." : "   Not in DB → Fetching from external APIs...");
      if (item) {
        await prisma.dictionaryItem.delete({ where: { id: item.id } });
      }

      const titleFromSlug = slug.replace(/-/g, " ");
      const category = await detectCategory(titleFromSlug);
      const completeData = await fetchCompleteTopicData(titleFromSlug, category);

      item = await prisma.dictionaryItem.create({
        data: completeData,
      });
      console.log(`   ✅ Saved new topic: ${item.title}`);
    } else {
      item = await prisma.dictionaryItem.update({
        where: { id: item.id },
        data: { viewCount: { increment: 1 } },
      });
    }

    return res.status(200).json({
      success: true,
      data: formatFullTopicResponse(item),
    });
  } catch (error) {
    console.error("❌ Error fetching topic:", error);
    return res.status(500).json({ message: "Error fetching topic", error: error.message });
  }
});

// ═════════════════════════════════════════
// 5. DEEP SEARCH (LOCAL → EXTERNAL APIs)
// ═════════════════════════════════════════
// GET /api/medical/deep-search?q=diabetes
router.get("/deep-search", async (req, res) => {
  const { q } = req.query;
  const userId = req.user?.id;

  if (!q || q.trim().length < 2) {
    return res.status(400).json({ message: "Query must be at least 2 characters" });
  }

  const searchQuery = q.trim();
  const slug = searchQuery
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^\w-]+/g, "");

  try {
    console.log(`\n🔎 DEEP SEARCH: "${searchQuery}"`);

    let item = await prisma.dictionaryItem.findFirst({
      where: {
        OR: [
          { slug },
          { title: { equals: searchQuery, mode: "insensitive" } },
        ],
      },
    });

    if (item) {
      const needsRefresh =
        !item.overview?.definition ||
        item.overview.definition.includes("item for") ||
        item.overview.definition.includes("is a medical topic classified under") ||
        item.description?.includes("item for") ||
        item.description?.includes("is a medical topic classified under") ||
        ((item.category === "Diseases" || item.category === "Anatomy") && 
         (!item.clinicalInfo || Object.keys(item.clinicalInfo).length === 0));

      if (!needsRefresh) {
        console.log(`   Found in DB: ${item.title}`);
        item = await prisma.dictionaryItem.update({
          where: { id: item.id },
          data: { searchCount: { increment: 1 } },
        });

        if (userId) {
          prisma.dictionarySearchHistory.create({ data: { userId, query: searchQuery } }).catch(() => {});
        }

        return res.status(200).json({
          success: true,
          source: "database",
          data: formatFullTopicResponse(item),
        });
      }

      console.log(`   Removing stale/placeholder entry, fetching fresh data...`);
      await prisma.dictionaryItem.delete({ where: { id: item.id } });
    }

    console.log(`   Not in DB → Calling ALL external APIs...`);
    const category = await detectCategory(searchQuery);
    const completeData = await fetchCompleteTopicData(searchQuery, category);

    let existingDoc = await prisma.dictionaryItem.findFirst({
      where: {
        OR: [{ title: completeData.title }, { slug: completeData.slug }],
      },
    });

    if (existingDoc) {
      item = await prisma.dictionaryItem.update({
        where: { id: existingDoc.id },
        data: {
          ...completeData,
          searchCount: { increment: 1 },
          lastRefreshed: new Date(),
        },
      });
      console.log(`   ✅ Updated existing DB entry: ${item.title} (${category})`);
    } else {
      try {
        item = await prisma.dictionaryItem.create({
          data: completeData,
        });
        console.log(`   ✅ Saved new: ${item.title} (${category})`);
      } catch (err) {
        if (err.code === "P2002") {
          item = await prisma.dictionaryItem.findFirst({
            where: {
              OR: [{ title: completeData.title }, { slug: completeData.slug }],
            },
          });
        } else {
          throw err;
        }
      }
    }

    if (userId) {
      prisma.dictionarySearchHistory.create({ data: { userId, query: searchQuery } }).catch(() => {});
    }

    return res.status(201).json({
      success: true,
      source: "api_fetch",
      data: formatFullTopicResponse(item),
    });
  } catch (error) {
    console.error("❌ Deep search error:", error);
    return res.status(500).json({ message: "Error in deep search", error: error.message });
  }
});

// ═════════════════════════════════════════
// 6. AUTOCOMPLETE SUGGESTIONS
// ═════════════════════════════════════════
// GET /api/medical/autocomplete?q=dia
router.get("/autocomplete", async (req, res) => {
  const { q } = req.query;
  if (!q || q.trim().length < 1) {
    return res.status(200).json({ suggestions: [] });
  }

  try {
    const suggestions = await prisma.dictionaryItem.findMany({
      where: {
        title: { startsWith: q.trim(), mode: "insensitive" },
      },
      take: 8,
      select: {
        title: true,
        category: true,
        slug: true,
      },
    });

    return res.status(200).json({
      suggestions: suggestions.map((s) => ({
        title: s.title,
        category: s.category,
        slug: s.slug,
      })),
    });
  } catch (error) {
    return res.status(500).json({ message: "Autocomplete error", error: error.message });
  }
});

// ═════════════════════════════════════════
// 7. TRENDING TOPICS
// ═════════════════════════════════════════
// GET /api/medical/trending
router.get("/trending", async (req, res) => {
  try {
    const [trendingBySearch, trendingByView] = await Promise.all([
      prisma.dictionaryItem.findMany({
        orderBy: { searchCount: "desc" },
        take: 5,
        select: { id: true, title: true, slug: true, category: true, searchCount: true, viewCount: true, images: true },
      }),
      prisma.dictionaryItem.findMany({
        orderBy: { viewCount: "desc" },
        take: 5,
        select: { id: true, title: true, slug: true, category: true, searchCount: true, viewCount: true, images: true },
      }),
    ]);

    const formatTrending = (items) =>
      items.map((item) => {
        const images = Array.isArray(item.images) ? item.images : [];
        return {
          id: item.id,
          _id: item.id,
          title: item.title,
          slug: item.slug,
          category: item.category,
          images: images.map((img) => ({
            id: img.id || img._id,
            thumbnail: img.thumbnailUrl || img.url,
            url: img.url,
            caption: img.caption,
          })),
          thumbnail: images[0]?.thumbnailUrl || images[0]?.url || null,
          searchCount: item.searchCount || 0,
          viewCount: item.viewCount || 0,
          trending: true,
        };
      });

    return res.status(200).json({
      success: true,
      mostSearched: formatTrending(trendingBySearch),
      mostViewed: formatTrending(trendingByView),
    });
  } catch (error) {
    console.error("❌ Error fetching trending:", error);
    return res.status(500).json({ message: "Error fetching trending", error: error.message });
  }
});

// ═════════════════════════════════════════
// 8. RANDOM TOPIC
// ═════════════════════════════════════════
// GET /api/medical/random
router.get("/random", async (req, res) => {
  try {
    const count = await prisma.dictionaryItem.count();
    if (count === 0) {
      return res.status(200).json({
        success: false,
        message: "No topics in database yet. Search for topics to populate.",
      });
    }

    const randomIndex = Math.floor(Math.random() * count);
    const item = await prisma.dictionaryItem.findFirst({
      skip: randomIndex,
    });

    if (!item) {
      return res.status(404).json({ message: "No random topic found" });
    }

    return res.status(200).json({
      success: true,
      data: formatFullTopicResponse(item),
    });
  } catch (error) {
    return res.status(500).json({ message: "Error fetching random topic", error: error.message });
  }
});

// ═════════════════════════════════════════
// 9. COMBINED STATS
// ═════════════════════════════════════════
// GET /api/medical/stats
router.get("/stats", async (req, res) => {
  try {
    const totalTopics = await prisma.dictionaryItem.count();

    const categoryCountsGroup = await prisma.dictionaryItem.groupBy({
      by: ["category"],
      _count: { id: true },
      orderBy: { _count: { id: "desc" } },
    });

    const [trending, popular, recentlyAdded] = await Promise.all([
      prisma.dictionaryItem.findMany({
        orderBy: { viewCount: "desc" },
        take: 6,
        select: { id: true, title: true, slug: true, category: true, viewCount: true, searchCount: true, images: true },
      }),
      prisma.dictionaryItem.findMany({
        orderBy: { searchCount: "desc" },
        take: 6,
        select: { id: true, title: true, slug: true, category: true, viewCount: true, searchCount: true, images: true },
      }),
      prisma.dictionaryItem.findMany({
        orderBy: { createdAt: "desc" },
        take: 6,
        select: { id: true, title: true, slug: true, category: true, viewCount: true, searchCount: true, images: true },
      }),
    ]);

    const formatItems = (items) =>
      items.map((item) => {
        const images = Array.isArray(item.images) ? item.images : [];
        return {
          id: item.id,
          _id: item.id,
          title: item.title,
          slug: item.slug,
          category: item.category,
          viewCount: item.viewCount || 0,
          searchCount: item.searchCount || 0,
          thumbnail: images[0]?.thumbnailUrl || images[0]?.url || null,
        };
      });

    return res.status(200).json({
      success: true,
      totalTopics,
      categoryCounts: categoryCountsGroup.map((c) => ({ category: c.category, count: c._count.id })),
      trending: formatItems(trending),
      popular: formatItems(popular),
      recentlyAdded: formatItems(recentlyAdded),
    });
  } catch (error) {
    return res.status(500).json({ message: "Error fetching stats", error: error.message });
  }
});

// ═════════════════════════════════════════
// 10. FORCE REFRESH TOPIC
// ═════════════════════════════════════════
// POST /api/medical/refresh/:slug
router.post("/refresh/:slug", async (req, res) => {
  const { slug } = req.params;

  try {
    console.log(`\n🔄 REFRESH: ${slug}`);

    const existing = await prisma.dictionaryItem.findUnique({ where: { slug } });
    const titleFromSlug = slug.replace(/-/g, " ");
    const category = existing?.category || (await detectCategory(titleFromSlug));

    const freshData = await fetchCompleteTopicData(
      existing?.title || titleFromSlug,
      category
    );

    if (existing) {
      const updated = await prisma.dictionaryItem.update({
        where: { id: existing.id },
        data: {
          ...freshData,
          lastRefreshed: new Date(),
        },
      });
      console.log(`   ✅ Refreshed: ${updated.title}`);

      return res.status(200).json({
        success: true,
        message: `Refreshed "${updated.title}" with latest data from all APIs`,
        data: formatFullTopicResponse(updated),
      });
    }

    const item = await prisma.dictionaryItem.create({
      data: freshData,
    });

    return res.status(201).json({
      success: true,
      message: `Created "${item.title}" with data from all APIs`,
      data: formatFullTopicResponse(item),
    });
  } catch (error) {
    console.error("❌ Refresh error:", error);
    return res.status(500).json({ message: "Error refreshing topic", error: error.message });
  }
});

// ═════════════════════════════════════════
// 11. BOOKMARK A TOPIC
// ═════════════════════════════════════════
// POST /api/medical/bookmark/:slug
router.post("/bookmark/:slug", authMiddleware, async (req, res) => {
  const { slug } = req.params;
  const userId = req.user.id;

  try {
    const item = await prisma.dictionaryItem.findUnique({ where: { slug } });
    if (!item) {
      return res.status(404).json({ message: "Topic not found" });
    }

    const existing = await prisma.dictionaryBookmark.findUnique({
      where: {
        userId_itemId: { userId, itemId: item.id },
      },
    });

    if (existing) {
      await prisma.dictionaryBookmark.delete({ where: { id: existing.id } });
      return res.status(200).json({ message: "Bookmark removed", bookmarked: false });
    }

    await prisma.dictionaryBookmark.create({
      data: { userId, itemId: item.id },
    });
    return res.status(201).json({ message: "Topic bookmarked", bookmarked: true });
  } catch (error) {
    console.error("❌ Error toggling bookmark:", error);
    return res.status(500).json({ message: "Error bookmarking", error: error.message });
  }
});

// ═════════════════════════════════════════
// 12. GET USER'S BOOKMARKS
// ═════════════════════════════════════════
// GET /api/medical/bookmarks
router.get("/bookmarks", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const bookmarks = await prisma.dictionaryBookmark.findMany({
      where: { userId },
      include: { dictionaryItem: true },
      orderBy: { createdAt: "desc" },
    });

    const items = bookmarks.map(b => b.dictionaryItem).filter(Boolean);

    return res.status(200).json({
      success: true,
      count: items.length,
      bookmarks: items.map((item) => {
        const images = Array.isArray(item.images) ? item.images : [];
        return {
          id: item.id,
          _id: item.id,
          title: item.title,
          slug: item.slug,
          category: item.category,
          description: item.description?.substring(0, 150) || "",
          thumbnail: images[0]?.thumbnailUrl || images[0]?.url || null,
        };
      }),
    });
  } catch (error) {
    console.error("❌ Error fetching bookmarks:", error);
    return res.status(500).json({ message: "Error fetching bookmarks", error: error.message });
  }
});

// ═════════════════════════════════════════
// 13. GET RELATED TOPICS
// ═════════════════════════════════════════
// GET /api/medical/related/:slug
router.get("/related/:slug", async (req, res) => {
  const { slug } = req.params;

  try {
    const item = await prisma.dictionaryItem.findUnique({ where: { slug } });
    if (!item) {
      return res.status(404).json({ message: "Topic not found" });
    }

    const related = await prisma.dictionaryItem.findMany({
      where: {
        slug: { not: slug },
        category: item.category,
      },
      take: 8,
      select: {
        id: true,
        title: true,
        slug: true,
        category: true,
        images: true,
        description: true,
      },
    });

    return res.status(200).json({
      success: true,
      count: related.length,
      relatedTopics: related.map((r) => {
        const images = Array.isArray(r.images) ? r.images : [];
        return {
          id: r.id,
          _id: r.id,
          title: r.title,
          slug: r.slug,
          category: r.category,
          description: r.description?.substring(0, 100) || "",
          thumbnail: images[0]?.thumbnailUrl || images[0]?.url || null,
        };
      }),
    });
  } catch (error) {
    console.error("❌ Error fetching related topics:", error);
    return res.status(500).json({ message: "Error fetching related", error: error.message });
  }
});

// ═════════════════════════════════════════
// 14. IMAGE GALLERY (ALL IMAGES BY SUBJECT)
// ═════════════════════════════════════════
// GET /api/medical/images/gallery
router.get("/images/gallery", async (req, res) => {
  try {
    const items = await prisma.dictionaryItem.findMany({
      orderBy: { viewCount: "desc" },
      select: {
        id: true,
        title: true,
        slug: true,
        category: true,
        images: true,
        description: true,
      },
    });

    const categoryMap = {};
    for (const item of items) {
      const cat = item.category || "Uncategorized";
      if (!categoryMap[cat]) {
        categoryMap[cat] = { name: cat, images: [] };
      }
      const images = Array.isArray(item.images) ? item.images : [];
      for (const img of images) {
        if (img?.url) {
          categoryMap[cat].images.push({
            url: img.url,
            thumbnailUrl: img.thumbnailUrl || img.url,
            mediumUrl: img.mediumUrl || img.url,
            caption: img.caption || "Medical illustration",
            creator: img.creator || "",
            license: img.license || "",
            source: img.source || "",
            topicTitle: item.title,
            topicSlug: item.slug,
            topicCategory: cat,
            topicDescription: (item.description || "").substring(0, 120),
          });
        }
      }
    }

    const categories = Object.values(categoryMap)
      .map((cat) => ({
        ...cat,
        imageCount: cat.images.length,
      }))
      .filter((c) => c.imageCount > 0)
      .sort((a, b) => b.imageCount - a.imageCount);

    return res.status(200).json({
      success: true,
      totalImages: categories.reduce((s, c) => s + c.imageCount, 0),
      categoryCount: categories.length,
      categories,
    });
  } catch (error) {
    console.error("❌ Error fetching image gallery:", error);
    return res.status(500).json({ message: "Error fetching image gallery", error: error.message });
  }
});

// ═════════════════════════════════════════
// 15. SEARCH HISTORY
// ═════════════════════════════════════════
// GET /api/medical/search-history
router.get("/search-history", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const history = await prisma.dictionarySearchHistory.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      take: 20,
      select: { id: true, query: true, timestamp: true, createdAt: true },
    });

    return res.status(200).json({ searchHistory: history });
  } catch (error) {
    return res.status(500).json({ message: "Error fetching search history", error: error.message });
  }
});

// ═════════════════════════════════════════
// RESPONSE FORMATTER
// ═════════════════════════════════════════

function formatFullTopicResponse(item) {
  const images = Array.isArray(item.images) ? item.images : [];
  const references = Array.isArray(item.references) ? item.references : [];
  const researchPapers = Array.isArray(item.researchPapers) ? item.researchPapers : [];

  return {
    id: item.id,
    _id: item.id,
    title: item.title,
    slug: item.slug,
    category: item.category,
    description: item.description,
    overview: item.overview || {},
    clinicalInfo: item.clinicalInfo || {},

    images: images.map((img) => ({
      id: img.id || img._id,
      url: img.url,
      thumbnailUrl: img.thumbnailUrl || img.url,
      mediumUrl: img.mediumUrl || img.url,
      caption: img.caption || "",
      creator: img.creator || "",
      license: img.license || "",
      source: img.source || "",
    })),

    references: references.map((ref) => ({
      id: ref.id || ref._id,
      title: ref.title || "",
      source: ref.source || "",
      url: ref.url || "",
      type: ref.type || "reference",
    })),

    researchPapers: researchPapers.map((paper) => ({
      id: paper.id || paper._id,
      pubmedId: paper.pubmedId || "",
      title: paper.title || "",
      authors: paper.authors || "",
      journal: paper.journal || "",
      volume: paper.volume || "",
      issue: paper.issue || "",
      pages: paper.pages || "",
      pubDate: paper.pubDate || "",
      abstract: paper.abstract || "",
      doi: paper.doi || "",
      url: paper.url || (paper.pubmedId ? `https://pubmed.ncbi.nlm.nih.gov/${paper.pubmedId}/` : ""),
    })),

    keywords: Array.isArray(item.keywords) ? item.keywords : [],
    relatedTopics: Array.isArray(item.relatedTopics) ? item.relatedTopics : [],

    viewCount: item.viewCount || 0,
    searchCount: item.searchCount || 0,
    trending: (item.viewCount || 0) > 100,
    lastRefreshed: item.lastRefreshed,
    dataSource: item.dataSource || {},
  };
}

export default router;
