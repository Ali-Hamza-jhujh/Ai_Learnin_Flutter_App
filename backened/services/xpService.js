import prisma from "../prisma.js";

// ══════════════════════════════════════════
// XP REWARD TABLE
// How many XP each action earns
// ══════════════════════════════════════════

export const XP_REWARDS = {
  GENERATE_NOTES: 20,
  GENERATE_MCQ: 15,
  COMPLETE_TEST: 10,
  SCORE_ABOVE_80: 25,
  SCORE_ABOVE_60: 10,
  CHAT_MESSAGE: 2,
  SAVE_VIDEO: 5,
  DAILY_LOGIN: 10,
  STREAK_BONUS_7: 50,
  STREAK_BONUS_30: 200,
  STREAK_BONUS_100: 1000,
};

// ══════════════════════════════════════════
// LEVEL SYSTEM
// ══════════════════════════════════════════

const LEVEL_THRESHOLDS = [
  0,     // Level 1
  100,   // Level 2
  250,   // Level 3
  500,   // Level 4
  800,   // Level 5
  1200,  // Level 6
  1800,  // Level 7
  2500,  // Level 8
  3500,  // Level 9
  5000,  // Level 10
  7000,  // Level 11
  9500,  // Level 12
  12500, // Level 13
  16000, // Level 14
  20000, // Level 15 — max
];

const LEVEL_TITLES = [
  "Beginner",
  "Curious Learner",
  "Note Taker",
  "Quiz Taker",
  "Knowledge Seeker",
  "Study Buddy",
  "Scholar",
  "Academic",
  "Expert",
  "Master",
  "Genius",
  "Prodigy",
  "Legend",
  "Grand Master",
  "StudyAI Elite",
];

export const calculateLevel = (xp) => {
  let level = 1;
  for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
    if (xp >= LEVEL_THRESHOLDS[i]) {
      level = i + 1;
      break;
    }
  }

  const currentThreshold = LEVEL_THRESHOLDS[level - 1];
  const nextThreshold = LEVEL_THRESHOLDS[level] || LEVEL_THRESHOLDS[level - 1];
  const xpIntoLevel = xp - currentThreshold;
  const xpNeededForNext = nextThreshold - currentThreshold;
  const progressPercent = level >= LEVEL_THRESHOLDS.length
    ? 100
    : Math.round((xpIntoLevel / xpNeededForNext) * 100);

  return {
    level,
    title: LEVEL_TITLES[level - 1] || "StudyAI Elite",
    currentXP: xp,
    xpForCurrentLevel: currentThreshold,
    xpForNextLevel: nextThreshold,
    xpToNextLevel: Math.max(nextThreshold - xp, 0),
    progressPercent,
    isMaxLevel: level >= LEVEL_THRESHOLDS.length,
  };
};

// ══════════════════════════════════════════
// STREAK SYSTEM
// ══════════════════════════════════════════

const isNewDay = (lastActive) => {
  if (!lastActive) return true;
  const now = new Date();
  const last = new Date(lastActive);
  return (
    now.getFullYear() !== last.getFullYear() ||
    now.getMonth() !== last.getMonth() ||
    now.getDate() !== last.getDate()
  );
};

const isYesterday = (lastActive) => {
  if (!lastActive) return false;
  const now = new Date();
  const last = new Date(lastActive);
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  return (
    last.getFullYear() === yesterday.getFullYear() &&
    last.getMonth() === yesterday.getMonth() &&
    last.getDate() === yesterday.getDate()
  );
};

const isStreakBroken = (lastActive) => {
  if (!lastActive) return false;
  const now = new Date();
  const last = new Date(lastActive);
  const diffMs = now - last;
  const diffDays = diffMs / (1000 * 60 * 60 * 24);
  return diffDays >= 2;
};

export const updateStreakAndXP = async (user) => {
  let xpGained = 0;
  let streakUpdated = false;
  let milestoneReached = null;

  if (!isNewDay(user.lastActive)) {
    return { xpGained: 0, streakUpdated: false, newStreak: user.streak, milestoneReached: null };
  }

  xpGained += XP_REWARDS.DAILY_LOGIN;

  let newStreak = user.streak || 0;
  if (isStreakBroken(user.lastActive)) {
    newStreak = 1;
  } else if (isYesterday(user.lastActive) || !user.lastActive) {
    newStreak = (user.streak || 0) + 1;
    streakUpdated = true;
  } else {
    newStreak = Math.max(user.streak || 1, 1);
  }

  if (newStreak === 7) {
    xpGained += XP_REWARDS.STREAK_BONUS_7;
    milestoneReached = { days: 7, bonus: XP_REWARDS.STREAK_BONUS_7, message: "🔥 7-day streak! Keep it up!" };
  } else if (newStreak === 30) {
    xpGained += XP_REWARDS.STREAK_BONUS_30;
    milestoneReached = { days: 30, bonus: XP_REWARDS.STREAK_BONUS_30, message: "🏆 30-day streak! Incredible!" };
  } else if (newStreak === 100) {
    xpGained += XP_REWARDS.STREAK_BONUS_100;
    milestoneReached = { days: 100, bonus: XP_REWARDS.STREAK_BONUS_100, message: "👑 100-day streak! Legendary!" };
  }

  const updatedUser = await prisma.user.update({
    where: { id: user.id },
    data: {
      streak: newStreak,
      xp: (user.xp || 0) + xpGained,
      lastActive: new Date(),
    },
  });

  user.streak = updatedUser.streak;
  user.xp = updatedUser.xp;
  user.lastActive = updatedUser.lastActive;

  return {
    xpGained,
    streakUpdated,
    newStreak: user.streak,
    milestoneReached,
  };
};

export const awardXP = async (userId, action, bonusXP = 0) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, xp: true },
  });
  if (!user) return null;

  const baseXP = XP_REWARDS[action] || 0;
  const totalXP = baseXP + bonusXP;

  if (totalXP <= 0) return null;

  const oldLevel = calculateLevel(user.xp || 0).level;
  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: {
      xp: (user.xp || 0) + totalXP,
    },
  });

  const newLevelInfo = calculateLevel(updatedUser.xp);
  const leveledUp = newLevelInfo.level > oldLevel;

  return {
    xpAwarded: totalXP,
    totalXP: updatedUser.xp,
    levelInfo: newLevelInfo,
    leveledUp,
    newLevel: leveledUp ? newLevelInfo.level : null,
    newTitle: leveledUp ? newLevelInfo.title : null,
  };
};