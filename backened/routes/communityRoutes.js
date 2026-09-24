import express from 'express';
import authMiddleware from '../Authentication/auth.js';
import prisma from '../prisma.js';

const router = express.Router();

// Get all posts
router.get('/posts', authMiddleware, async (req, res) => {
    try {
        const posts = await prisma.communityPost.findMany({
            include: {
                author: {
                    select: { id: true, name: true, avatar: true, xp: true },
                },
            },
            orderBy: { createdAt: 'desc' },
        });

        const formatted = posts.map(p => ({
            ...p,
            _id: p.id,
            author: p.author ? { ...p.author, _id: p.author.id } : null,
        }));

        res.json({ status: 'success', data: formatted });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Create post
router.post('/posts', authMiddleware, async (req, res) => {
    try {
        const { title, body, subject } = req.body;
        const post = await prisma.communityPost.create({
            data: {
                authorId: req.user.id,
                title,
                body,
                subject: subject || 'General',
            },
            include: {
                author: {
                    select: { id: true, name: true, avatar: true, xp: true },
                },
            },
        });

        res.status(201).json({
            status: 'success',
            data: {
                ...post,
                _id: post.id,
                author: post.author ? { ...post.author, _id: post.author.id } : null,
            },
        });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Post answer
router.post('/posts/:id/answer', authMiddleware, async (req, res) => {
    try {
        const post = await prisma.communityPost.findUnique({
            where: { id: req.params.id },
        });
        if (!post) return res.status(404).json({ message: 'Post not found' });

        const user = await prisma.user.findUnique({
            where: { id: req.user.id },
            select: { id: true, name: true, avatar: true },
        });

        const answers = Array.isArray(post.answers) ? [...post.answers] : [];
        answers.push({
            author: user ? { _id: user.id, id: user.id, name: user.name, avatar: user.avatar } : { _id: req.user.id, id: req.user.id },
            body: req.body.body,
            createdAt: new Date(),
        });

        const updated = await prisma.communityPost.update({
            where: { id: req.params.id },
            data: { answers },
            include: {
                author: {
                    select: { id: true, name: true, avatar: true, xp: true },
                },
            },
        });

        res.json({
            status: 'success',
            data: {
                ...updated,
                _id: updated.id,
                author: updated.author ? { ...updated.author, _id: updated.author.id } : null,
            },
        });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

export default router;
