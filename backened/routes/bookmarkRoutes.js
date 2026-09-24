import express from 'express';
import authMiddleware from '../Authentication/auth.js';
import prisma from '../prisma.js';

const router = express.Router();

// Get user bookmarks
router.get('/my', authMiddleware, async (req, res) => {
    try {
        const bookmarks = await prisma.bookmark.findMany({
            where: { userId: req.user.id },
            orderBy: { createdAt: 'desc' },
        });
        const data = bookmarks.map(b => ({
            ...b,
            _id: b.id,
            user: b.userId,
        }));
        res.json({ status: 'success', data });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Toggle bookmark
router.post('/toggle', authMiddleware, async (req, res) => {
    try {
        const { itemType, itemId } = req.body;
        const existing = await prisma.bookmark.findFirst({
            where: { userId: req.user.id, itemType, itemId },
        });
        
        if (existing) {
            await prisma.bookmark.delete({
                where: { id: existing.id },
            });
            res.json({ status: 'success', message: 'Bookmark removed', bookmarked: false });
        } else {
            await prisma.bookmark.create({
                data: {
                    userId: req.user.id,
                    itemType,
                    itemId,
                },
            });
            res.json({ status: 'success', message: 'Bookmarked', bookmarked: true });
        }
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

export default router;
