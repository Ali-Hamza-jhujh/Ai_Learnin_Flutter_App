import prisma from "../prisma.js";
import { detectCategory } from "../services/categoryDetector.js";
import { fetchCompleteTopicData } from "../services/medicalAPICaller.js";

const slugify = (text) =>
  text
    .toString()
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^\w\-]+/g, "")
    .replace(/\-\-+/g, "-")
    .replace(/^-+/, "")
    .replace(/-+$/, "");

export const searchDictionary = async (req, res) => {
  const { q } = req.query;
  const userId = req.user?.id || req.body?.userId;

  if (!q) {
    return res.status(400).json({ message: "Search query is required" });
  }

  const queryTerm = q.trim();
  const slug = slugify(queryTerm);

  try {
    // 1. Search Local Database
    let item = await prisma.dictionaryItem.findFirst({
      where: {
        OR: [
          { slug: slug },
          { title: { equals: queryTerm, mode: "insensitive" } },
        ],
      },
    });

    if (item) {
      const isDummy =
        !item.overview?.definition ||
        item.overview.definition.includes("item for") ||
        item.description?.includes("item for") ||
        req.query.refresh === "true";

      if (!isDummy) {
        item = await prisma.dictionaryItem.update({
          where: { id: item.id },
          data: { searchCount: { increment: 1 } },
        });

        if (userId) {
          await prisma.dictionarySearchHistory.create({
            data: { userId, query: queryTerm },
          });
        }

        return res.status(200).json({ item: { ...item, _id: item.id }, source: "database" });
      }

      console.log(`🔄 Auto-refreshing dummy/stale item: ${queryTerm}`);
      await prisma.dictionaryItem.delete({ where: { id: item.id } });
    }

    // 2. Determine Topic Category
    const categoryHint = req.query.category;
    let category;
    if (categoryHint && categoryHint.trim().length > 0) {
      category = categoryHint.trim();
    } else {
      category = await detectCategory(queryTerm);
    }
    const completeData = await fetchCompleteTopicData(queryTerm, category);

    // 3. Upsert into Database
    let existingItem = await prisma.dictionaryItem.findFirst({
      where: {
        OR: [{ title: completeData.title }, { slug: completeData.slug }],
      },
    });

    if (existingItem) {
      item = await prisma.dictionaryItem.update({
        where: { id: existingItem.id },
        data: {
          ...completeData,
          searchCount: { increment: 1 },
          lastRefreshed: new Date(),
        },
      });
    } else {
      try {
        item = await prisma.dictionaryItem.create({
          data: completeData,
        });
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
      await prisma.dictionarySearchHistory.create({
        data: { userId, query: queryTerm },
      });
    }

    return res.status(201).json({ item: { ...item, _id: item.id }, source: "api_fetch" });
  } catch (error) {
    console.error("❌ Search dictionary controller error:", error);
    return res.status(500).json({ message: "Error searching dictionary", error: error.message });
  }
};

export const autocomplete = async (req, res) => {
  const { q } = req.query;
  if (!q) return res.status(200).json([]);

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

    return res.status(200).json(suggestions);
  } catch (error) {
    return res.status(500).json({ message: "Error fetching suggestions", error: error.message });
  }
};

export const getTopicBySlug = async (req, res) => {
  const { slug } = req.params;
  const userId = req.user?.id || req.body?.userId;

  try {
    let item = await prisma.dictionaryItem.findUnique({
      where: { slug },
    });
    if (!item) {
      return res.status(404).json({ message: "Topic not found" });
    }

    item = await prisma.dictionaryItem.update({
      where: { id: item.id },
      data: { viewCount: { increment: 1 } },
    });

    if (userId) {
      await prisma.dictionaryViewHistory.create({
        data: { userId, itemId: item.id },
      });
    }

    let isBookmarked = false;
    if (userId) {
      const bookmark = await prisma.dictionaryBookmark.findUnique({
        where: {
          userId_itemId: { userId, itemId: item.id },
        },
      });
      isBookmarked = !!bookmark;
    }

    return res.status(200).json({ item: { ...item, _id: item.id }, isBookmarked });
  } catch (error) {
    return res.status(500).json({ message: "Error fetching topic details", error: error.message });
  }
};

export const toggleBookmark = async (req, res) => {
  const { itemId } = req.body;
  const userId = req.user?.id;

  if (!userId) {
    return res.status(401).json({ message: "Unauthorized. Login required." });
  }

  try {
    const existing = await prisma.dictionaryBookmark.findUnique({
      where: {
        userId_itemId: { userId, itemId },
      },
    });

    if (existing) {
      await prisma.dictionaryBookmark.delete({
        where: { id: existing.id },
      });
      return res.status(200).json({ bookmarked: false, message: "Bookmark removed" });
    } else {
      await prisma.dictionaryBookmark.create({
        data: { userId, itemId },
      });
      return res.status(200).json({ bookmarked: true, message: "Bookmark added" });
    }
  } catch (error) {
    return res.status(500).json({ message: "Error toggling bookmark", error: error.message });
  }
};

export const getBookmarks = async (req, res) => {
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ message: "Unauthorized" });
  }

  try {
    const bookmarks = await prisma.dictionaryBookmark.findMany({
      where: { userId },
      include: { dictionaryItem: true },
      orderBy: { createdAt: "desc" },
    });
    const items = bookmarks.map(b => b.dictionaryItem ? { ...b.dictionaryItem, _id: b.dictionaryItem.id } : null).filter(Boolean);
    return res.status(200).json(items);
  } catch (error) {
    return res.status(500).json({ message: "Error fetching bookmarks", error: error.message });
  }
};

export const getItemsByCategory = async (req, res) => {
  const { category } = req.params;
  const { q } = req.query;

  try {
    const where = {
      category: { equals: category, mode: "insensitive" },
    };

    if (q) {
      where.OR = [
        { title: { contains: q.trim(), mode: "insensitive" } },
        { description: { contains: q.trim(), mode: "insensitive" } },
      ];
    }

    const items = await prisma.dictionaryItem.findMany({
      where,
      orderBy: { title: "asc" },
      select: {
        id: true,
        title: true,
        slug: true,
        category: true,
        description: true,
        viewCount: true,
        searchCount: true,
        images: true,
      },
    });

    const formatted = items.map(item => ({ ...item, _id: item.id }));
    return res.status(200).json(formatted);
  } catch (error) {
    return res.status(500).json({ message: "Error fetching category items", error: error.message });
  }
};

export const getDictionaryStats = async (req, res) => {
  try {
    const [trending, popular, recentlyAdded] = await Promise.all([
      prisma.dictionaryItem.findMany({ orderBy: { viewCount: "desc" }, take: 6 }),
      prisma.dictionaryItem.findMany({ orderBy: { searchCount: "desc" }, take: 6 }),
      prisma.dictionaryItem.findMany({ orderBy: { createdAt: "desc" }, take: 6 }),
    ]);

    const format = (list) => list.map(i => ({ ...i, _id: i.id }));

    return res.status(200).json({
      trending: format(trending),
      popular: format(popular),
      recentlyAdded: format(recentlyAdded),
    });
  } catch (error) {
    return res.status(500).json({ message: "Error fetching analytics", error: error.message });
  }
};

// ─── Admin: Delete a dictionary item ─────────────────────────────────────────
export const deleteDictionaryItem = async (req, res) => {
  const { id } = req.params;
  try {
    const deleted = await prisma.dictionaryItem.delete({
      where: { id },
    });
    console.log(`🗑️ Admin deleted dictionary item: "${deleted.title}" (${id})`);
    return res.status(200).json({ message: "Item deleted successfully", title: deleted.title });
  } catch (error) {
    return res.status(500).json({ message: "Error deleting item", error: error.message });
  }
};
