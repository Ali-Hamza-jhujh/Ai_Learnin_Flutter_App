import express from 'express';
import authMiddleware from '../Authentication/auth.js';
import prisma from '../prisma.js';

const router = express.Router();

// Get user's battles
router.get('/my', authMiddleware, async (req, res) => {
    try {
        const battles = await prisma.battle.findMany({
            where: {
                OR: [
                    { challengerId: req.user.id },
                    { opponentId: req.user.id },
                ],
            },
            orderBy: { createdAt: 'desc' },
        });

        const userIds = [...new Set(battles.flatMap(b => [b.challengerId, b.opponentId]).filter(Boolean))];
        const mcqIds = [...new Set(battles.map(b => b.mcqSetId).filter(Boolean))];

        const [users, mcqs] = await Promise.all([
            prisma.user.findMany({
                where: { id: { in: userIds } },
                select: { id: true, name: true, avatar: true, xp: true },
            }),
            prisma.mCQ.findMany({
                where: { id: { in: mcqIds } },
                select: { id: true, title: true },
            }),
        ]);

        const userMap = new Map(users.map(u => [u.id, { ...u, _id: u.id }]));
        const mcqMap = new Map(mcqs.map(m => [m.id, { ...m, _id: m.id }]));

        const data = battles.map(b => ({
            ...b,
            _id: b.id,
            challenger: userMap.get(b.challengerId) || null,
            opponent: userMap.get(b.opponentId) || null,
            mcqSet: mcqMap.get(b.mcqSetId) || null,
        }));

        res.json({ status: 'success', data });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Challenge someone
router.post('/challenge', authMiddleware, async (req, res) => {
    try {
        const { opponentId, mcqSetId } = req.body;
        const battle = await prisma.battle.create({
            data: {
                challengerId: req.user.id,
                opponentId: opponentId || null,
                mcqSetId: mcqSetId || null,
                status: 'pending',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            },
        });

        res.status(201).json({ status: 'success', data: { ...battle, _id: battle.id } });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

export default router;
