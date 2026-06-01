// ══════════════════════════════════════════
// XP REWARD TABLE
// How many XP each action earns
// ══════════════════════════════════════════

export const XP_REWARDS = {
  GENERATE_NOTES: 20,       // generated notes from PDF
  GENERATE_MCQ: 15,         // generated MCQ set
  COMPLETE_TEST: 10,        // submitted a test
  SCORE_ABOVE_80: 25,       // bonus for scoring 80%+
  SCORE_ABOVE_60: 10,       // bonus for scoring 60–79%
  CHAT_MESSAGE: 2,          // sent a message to tutor
  SAVE_VIDEO: 5,            // saved a YouTube lecture
  DAILY_LOGIN: 10,          // first login of the day
  STREAK_BONUS_7: 50,       // 7-day streak milestone
  STREAK_BONUS_30: 200,     // 30-day streak milestone
  STREAK_BONUS_100: 1000,   // 100-day streak milestone
};

// ══════════════════════════════════════════
// LEVEL SYSTEM
// ══════════════════════════════════════════

// XP required to reach each level
// Level 1 = 0 XP, Level 2 = 100 XP, etc.
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
  "Beginner",        // 1
  "Curious Learner", // 2
  "Note Taker",      // 3
  "Quiz Taker",      // 4
  "Knowledge Seeker",// 5
  "Study Buddy",     // 6
  "Scholar",         // 7
  "Academic",        // 8
  "Expert",          // 9
  "Master",          // 10
  "Genius",          // 11
  "Prodigy",         // 12
  "Legend",          // 13
  "Grand Master",    // 14
  "StudyAI Elite",   // 15
];

// Calculate level from total XP
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

// Returns whether today is a new day compared to lastActive
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

// Returns whether lastActive was exactly yesterday
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

// Returns whether lastActive was 2+ days ago (streak broken)
const isStreakBroken = (lastActive) => {
  if (!lastActive) return false;
  const now = new Date();
  const last = new Date(lastActive);
  const diffMs = now - last;
  const diffDays = diffMs / (1000 * 60 * 60 * 24);
  return diffDays >= 2;
};

// ── Main function: update streak + award daily login XP ──
// Returns { xpGained, streakUpdated, newStreak, milestoneReached }
export const updateStreakAndXP = async (user) => {
  let xpGained = 0;
  let streakUpdated = false;
  let milestoneReached = null;

  // Only process if this is a new day
  if (!isNewDay(user.lastActive)) {
    return { xpGained: 0, streakUpdated: false, newStreak: user.streak, milestoneReached: null };
  }

  // Award daily login XP
  xpGained += XP_REWARDS.DAILY_LOGIN;

  if (isStreakBroken(user.lastActive)) {
    // Streak broken — reset to 1
    user.streak = 1;
  } else if (isYesterday(user.lastActive) || !user.lastActive) {
    // Continued streak — increment
    user.streak = (user.streak || 0) + 1;
    streakUpdated = true;
  } else {
    // Same day edge case — shouldn't reach here but handle it
    user.streak = Math.max(user.streak || 1, 1);
  }

  // Check streak milestones
  if (user.streak === 7) {
    xpGained += XP_REWARDS.STREAK_BONUS_7;
    milestoneReached = { days: 7, bonus: XP_REWARDS.STREAK_BONUS_7, message: "🔥 7-day streak! Keep it up!" };
  } else if (user.streak === 30) {
    xpGained += XP_REWARDS.STREAK_BONUS_30;
    milestoneReached = { days: 30, bonus: XP_REWARDS.STREAK_BONUS_30, message: "🏆 30-day streak! Incredible!" };
  } else if (user.streak === 100) {
    xpGained += XP_REWARDS.STREAK_BONUS_100;
    milestoneReached = { days: 100, bonus: XP_REWARDS.STREAK_BONUS_100, message: "👑 100-day streak! Legendary!" };
  }

  user.xp = (user.xp || 0) + xpGained;
  user.lastActive = new Date();
  await user.save();

  return {
    xpGained,
    streakUpdated,
    newStreak: user.streak,
    milestoneReached,
  };
};

// ── Award XP for a specific action ──
// Call this from any route after a user completes an action
export const awardXP = async (userId, action, bonusXP = 0) => {
  const User = (await import("../models/users.js")).default;

  const user = await User.findById(userId);
  if (!user) return null;

  const baseXP = XP_REWARDS[action] || 0;
  const totalXP = baseXP + bonusXP;

  if (totalXP <= 0) return null;

  const oldLevel = calculateLevel(user.xp).level;
  user.xp = (user.xp || 0) + totalXP;
  await user.save();

  const newLevelInfo = calculateLevel(user.xp);
  const leveledUp = newLevelInfo.level > oldLevel;

  return {
    xpAwarded: totalXP,
    totalXP: user.xp,
    levelInfo: newLevelInfo,
    leveledUp,
    newLevel: leveledUp ? newLevelInfo.level : null,
    newTitle: leveledUp ? newLevelInfo.title : null,
  };
};