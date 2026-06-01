import express from "express";
import bcrypt from "bcrypt";
import authMiddleware from "../Authentication/auth.js";
import User from "../models/users.js";
import { calculateLevel, updateStreakAndXP, awardXP, XP_REWARDS } from "../services/xpService.js";
import dotenv from "dotenv";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════

// Build full profile response — used in multiple routes
const buildProfileResponse = (user) => {
  const levelInfo = calculateLevel(user.xp || 0);
  return {
    _id: user._id,
    name: user.name,
    email: user.email,
    educationLevel: user.educationLevel,
    subject: user.subject,
    goal: user.goal,
    profilePicture: user.profilePicture,
    isVerified: user.isVerified,
    xp: user.xp || 0,
    streak: user.streak || 0,
    lastActive: user.lastActive,
    level: levelInfo,
    createdAt: user.createdAt,
  };
};

// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── GET MY PROFILE ───────────────────────
// Also triggers daily login XP + streak update
router.get("/me", authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    // Update streak and award daily login XP
    const streakResult = await updateStreakAndXP(user);

    const profile = buildProfileResponse(user);

    res.status(200).json({
      user: profile,
      // Tell Flutter if anything changed so it can show a toast/animation
      dailyReward: streakResult.xpGained > 0 ? {
        xpGained: streakResult.xpGained,
        newStreak: streakResult.newStreak,
        streakUpdated: streakResult.streakUpdated,
        milestoneReached: streakResult.milestoneReached,
      } : null,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── UPDATE PROFILE ───────────────────────
//
// Body (all optional):
//   name, educationLevel, subject, goal, profilePicture
//
router.put("/update", authMiddleware, async (req, res) => {
  try {
    const { name, educationLevel, subject, goal, profilePicture } = req.body;

    const allowedUpdates = {};
    if (name) allowedUpdates.name = name.trim();
    if (educationLevel) allowedUpdates.educationLevel = educationLevel;
    if (subject) allowedUpdates.subject = subject.trim();
    if (goal) allowedUpdates.goal = goal.trim();
    if (profilePicture !== undefined) allowedUpdates.profilePicture = profilePicture;

    if (Object.keys(allowedUpdates).length === 0) {
      return res.status(400).json({ message: "No valid fields provided to update" });
    }

    const updated = await User.findByIdAndUpdate(
      req.user.id,
      allowedUpdates,
      { new: true, runValidators: true }
    );

    if (!updated) return res.status(404).json({ message: "User not found" });

    res.status(200).json({
      message: "Profile updated successfully",
      user: buildProfileResponse(updated),
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── CHANGE PASSWORD ──────────────────────
//
// Body:
//   currentPassword (required)
//   newPassword     (required, min 6 chars)
//
router.put("/change-password", authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: "Both current and new password are required" });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: "New password must be at least 6 characters" });
    }

    const user = await User.findById(req.user.id).select("+password");
    if (!user) return res.status(404).json({ message: "User not found" });

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();

    res.status(200).json({ message: "Password changed successfully" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET XP + LEVEL INFO ──────────────────
// Lightweight endpoint — just XP and level data
// Flutter uses this to update progress bars without full profile reload
router.get("/xp", authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("xp streak lastActive");
    if (!user) return res.status(404).json({ message: "User not found" });

    const levelInfo = calculateLevel(user.xp || 0);

    res.status(200).json({
      xp: user.xp || 0,
      streak: user.streak || 0,
      lastActive: user.lastActive,
      level: levelInfo,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── AWARD XP (internal use / manual) ────
//
// Called by other routes after actions.
// Can also be called directly for testing.
//
// Body:
//   action (required) — key from XP_REWARDS table
//   bonusXP (optional) — extra XP on top of base reward
//
// Valid actions:
//   GENERATE_NOTES, GENERATE_MCQ, COMPLETE_TEST,
//   SCORE_ABOVE_80, SCORE_ABOVE_60, CHAT_MESSAGE,
//   SAVE_VIDEO, DAILY_LOGIN
//
router.post("/award-xp", authMiddleware, async (req, res) => {
  try {
    const { action, bonusXP } = req.body;

    if (!action || !XP_REWARDS[action]) {
      return res.status(400).json({
        message: "Invalid action",
        validActions: Object.keys(XP_REWARDS),
      });
    }

    const result = await awardXP(req.user.id, action, bonusXP || 0);
    if (!result) return res.status(404).json({ message: "User not found" });

    res.status(200).json({
      message: `+${result.xpAwarded} XP awarded!`,
      ...result,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── LEADERBOARD ──────────────────────────
//
// Top 20 users by XP — for competitive motivation.
// Query param: subject — filter by same subject (optional)
//
router.get("/leaderboard", authMiddleware, async (req, res) => {
  try {
    const { subject } = req.query;

    const filter = {};
    if (subject) filter.subject = { $regex: subject, $options: "i" };

    const topUsers = await User.find(filter)
      .sort({ xp: -1 })
      .limit(20)
      .select("name subject educationLevel xp streak profilePicture");

    const leaderboard = topUsers.map((u, index) => ({
      rank: index + 1,
      name: u.name,
      subject: u.subject,
      educationLevel: u.educationLevel,
      profilePicture: u.profilePicture,
      xp: u.xp || 0,
      streak: u.streak || 0,
      level: calculateLevel(u.xp || 0).level,
      title: calculateLevel(u.xp || 0).title,
      isMe: u._id.toString() === req.user.id,
    }));

    // Also find current user's rank even if not in top 20
    const myUser = await User.findById(req.user.id).select("xp");
    const myRank = await User.countDocuments({ xp: { $gt: myUser?.xp || 0 } }) + 1;

    res.status(200).json({
      leaderboard,
      myRank,
      totalUsers: await User.countDocuments(filter),
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET STATS SUMMARY ────────────────────
//
// Combines profile + test stats + notes count + chat count
// for the Flutter profile screen — one call, full picture.
//
router.get("/stats", authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    // Load counts from other collections in parallel
    const [notesCount, mcqCount, chatCount, testResultCount] = await Promise.all([
      import("../models/notes.js").then(({ default: Notes }) =>
        Notes.countDocuments({ userId: req.user.id })
      ),
      import("../models/mcq.js").then(({ default: MCQ }) =>
        MCQ.countDocuments({ userId: req.user.id })
      ),
      import("../models/chat.js").then(({ default: Chat }) =>
        Chat.countDocuments({ userId: req.user.id })
      ),
      import("../models/testResult.js").then(({ default: TestResult }) =>
        TestResult.countDocuments({ userId: req.user.id })
      ),
    ]);

    // Average score from test results
    const TestResult = (await import("../models/testResult.js")).default;
    const scoreAgg = await TestResult.aggregate([
      { $match: { userId: user._id } },
      { $group: { _id: null, avgScore: { $avg: "$scorePercent" } } },
    ]);
    const averageScore = scoreAgg[0]?.avgScore
      ? Math.round(scoreAgg[0].avgScore * 10) / 10
      : 0;

    const levelInfo = calculateLevel(user.xp || 0);

    res.status(200).json({
      profile: buildProfileResponse(user),
      stats: {
        notesGenerated: notesCount,
        mcqSetsCreated: mcqCount,
        testsCompleted: testResultCount,
        chatSessions: chatCount,
        averageTestScore: averageScore,
      },
      level: levelInfo,
      xpRewards: XP_REWARDS, // send to Flutter so it can show reward info in UI
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

export default router;