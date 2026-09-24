import express from 'express';
import authMiddleware from '../Authentication/auth.js';
import prisma from '../prisma.js';

const router = express.Router();

// Get analytics dashboard data
router.get('/dashboard', authMiddleware, async (req, res) => {
    try {
        const user = await prisma.user.findUnique({
            where: { id: req.user.id },
            select: { activityMap: true },
        });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const now = new Date();
        const activityMap = (typeof user.activityMap === 'object' && user.activityMap !== null)
            ? user.activityMap
            : {};
        
        // Calculate weekly study time
        let weeklyStudyTime = 0;
        for (let i = 0; i < 7; i++) {
            const d = new Date(now);
            d.setDate(d.getDate() - i);
            const dateStr = d.toISOString().split('T')[0];
            if (activityMap[dateStr]) {
                weeklyStudyTime += activityMap[dateStr] * 10;
            }
        }

        const data = {
            weeklyStudyTime,
            topicMastery: [
                { subject: 'Math', percentage: 85 },
                { subject: 'Science', percentage: 92 },
                { subject: 'History', percentage: 78 }
            ],
            scoreTrends: [80, 85, 82, 90, 88, 95],
            heatmapData: activityMap,
            aiReport: 'You have been very consistent this week! Your Science mastery improved by 15%.'
        };

        res.json({ status: 'success', data });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// Log study activity
router.post('/log-activity', authMiddleware, async (req, res) => {
    try {
        const { minutes } = req.body;
        const user = await prisma.user.findUnique({
            where: { id: req.user.id },
            select: { activityMap: true },
        });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const today = new Date().toISOString().split('T')[0];
        const activityMap = (typeof user.activityMap === 'object' && user.activityMap !== null)
            ? { ...user.activityMap }
            : {};

        const currentCount = activityMap[today] || 0;
        const addedUnits = Math.ceil((minutes || 10) / 10);
        activityMap[today] = currentCount + addedUnits;

        await prisma.user.update({
            where: { id: req.user.id },
            data: { activityMap },
        });

        res.json({ status: 'success', message: 'Activity logged' });
    } catch (error) {
        res.status(500).json({ status: 'error', message: error.message });
    }
});

export default router;
