import prisma from '../prisma.js';

// Predefined list of achievements
export const ACHIEVEMENTS = [
    {
        id: 'first_notes',
        title: 'First Step',
        description: 'Generate your first study notes.',
        xpReward: 50,
        icon: '📝'
    },
    {
        id: 'chat_tutor',
        title: 'Curious Mind',
        description: 'Start your first chat with the AI tutor.',
        xpReward: 50,
        icon: '🤖'
    },
    {
        id: 'streak_3',
        title: 'Consistency Key',
        description: 'Maintain a 3-day study streak.',
        xpReward: 100,
        icon: '🔥'
    },
    {
        id: 'streak_7',
        title: 'Unstoppable',
        description: 'Maintain a 7-day study streak.',
        xpReward: 300,
        icon: '⚡'
    },
    {
        id: 'mcq_master',
        title: 'Quiz Master',
        description: 'Score 100% on any generated MCQ test.',
        xpReward: 150,
        icon: '🎯'
    }
];

export class AchievementService {
    /**
     * Unlock an achievement for a user
     * @param {String} userId 
     * @param {String} achievementId 
     * @returns {Object} { newlyUnlocked, achievement, userXp }
     */
    static async unlockAchievement(userId, achievementId) {
        const user = await prisma.user.findUnique({
            where: { id: userId },
        });
        if (!user) throw new Error('User not found');

        const achievement = ACHIEVEMENTS.find(a => a.id === achievementId);
        if (!achievement) throw new Error('Achievement not found');

        const achievements = Array.isArray(user.achievements) ? [...user.achievements] : [];
        const hasUnlocked = achievements.some(a => a.id === achievementId);
        if (hasUnlocked) {
            return {
                newlyUnlocked: false,
                achievement,
                userXp: user.xp,
            };
        }

        achievements.push({ id: achievementId, unlockedAt: new Date() });
        const newXp = (user.xp || 0) + achievement.xpReward;

        await prisma.user.update({
            where: { id: userId },
            data: {
                achievements,
                xp: newXp,
            },
        });

        return {
            newlyUnlocked: true,
            achievement,
            userXp: newXp,
        };
    }

    /**
     * Get user's achievements and overall stats
     * @param {String} userId 
     */
    static async getUserAchievements(userId) {
        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { xp: true, streak: true, achievements: true },
        });
        if (!user) throw new Error('User not found');

        const achievements = Array.isArray(user.achievements) ? user.achievements : [];
        const userAchievementsMap = new Map();
        achievements.forEach(a => {
            userAchievementsMap.set(a.id, a.unlockedAt);
        });

        const list = ACHIEVEMENTS.map(a => ({
            ...a,
            isUnlocked: userAchievementsMap.has(a.id),
            unlockedAt: userAchievementsMap.get(a.id) || null,
        }));

        return {
            xp: user.xp || 0,
            streak: user.streak || 0,
            achievements: list,
            unlockedCount: achievements.length,
            totalCount: ACHIEVEMENTS.length,
        };
    }
}
