import express from 'express';
import authMiddleware from '../Authentication/auth.js';
import { AchievementService } from '../services/achievementService.js';

const router = express.Router();

/**
 * @route GET /api/achievements
 * @desc Get user's achievements and XP
 * @access Private
 */
router.get('/', authMiddleware, async (req, res) => {
    try {
        const stats = await AchievementService.getUserAchievements(req.user.id);
        res.json({
            status: 'success',
            data: stats
        });
    } catch (error) {
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

/**
 * @route POST /api/achievements/unlock
 * @desc Unlock an achievement for a user
 * @access Private
 */
router.post('/unlock', authMiddleware, async (req, res) => {
    try {
        const { achievementId } = req.body;
        if (!achievementId) {
            return res.status(400).json({
                status: 'error',
                message: 'achievementId is required'
            });
        }

        const result = await AchievementService.unlockAchievement(req.user.id, achievementId);
        res.json({
            status: 'success',
            data: result
        });
    } catch (error) {
        // Return 404 for not found errors
        if (error.message.includes('not found')) {
            return res.status(404).json({
                status: 'error',
                message: error.message
            });
        }
        res.status(500).json({
            status: 'error',
            message: error.message
        });
    }
});

export default router;
