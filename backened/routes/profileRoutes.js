import express from "express";
import bcrypt from "bcrypt";
import authMiddleware from "../Authentication/auth.js";
import prisma from "../prisma.js";
import { calculateLevel, updateStreakAndXP, awardXP, XP_REWARDS } from "../services/xpService.js";
import dotenv from "dotenv";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════

const buildProfileResponse = (user) => {
  const levelInfo = calculateLevel(user.xp || 0);
  return {
    id: user.id,
    _id: user.id,
    name: user.name,
    email: user.email,
    educationLevel: user.educationLevel,
    subject: user.subject,
    goal: user.goal,
    profilePicture: user.profilePicture,
    isVerified: user.isVerified,
    isAdmin: user.isAdmin === true,
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
router.get("/me", authMiddleware, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
    });
    if (!user) return res.status(404).json({ message: "User not found" });

    const streakResult = await updateStreakAndXP(user);
    const profile = buildProfileResponse(user);

    res.status(200).json({
      user: profile,
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

    const updated = await prisma.user.update({
      where: { id: req.user.id },
      data: allowedUpdates,
    });

    res.status(200).json({
      message: "Profile updated successfully",
      user: buildProfileResponse(updated),
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── CHANGE PASSWORD ──────────────────────
router.put("/change-password", authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: "Both current and new password are required" });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: "New password must be at least 6 characters" });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
    });
    if (!user || !user.password) return res.status(404).json({ message: "User not found" });

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await prisma.user.update({
      where: { id: req.user.id },
      data: { password: hashedPassword },
    });

    res.status(200).json({ message: "Password changed successfully" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET XP + LEVEL INFO ──────────────────
router.get("/xp", authMiddleware, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { xp: true, streak: true, lastActive: true },
    });
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
router.get("/leaderboard", authMiddleware, async (req, res) => {
  try {
    const { subject } = req.query;

    const where = {};
    if (subject) {
      where.subject = { contains: subject, mode: "insensitive" };
    }

    const topUsers = await prisma.user.findMany({
      where,
      orderBy: { xp: "desc" },
      take: 20,
      select: {
        id: true,
        name: true,
        subject: true,
        educationLevel: true,
        xp: true,
        streak: true,
        profilePicture: true,
      },
    });

    const leaderboard = topUsers.map((u, index) => ({
      rank: index + 1,
      id: u.id,
      _id: u.id,
      name: u.name,
      subject: u.subject,
      educationLevel: u.educationLevel,
      profilePicture: u.profilePicture,
      xp: u.xp || 0,
      streak: u.streak || 0,
      level: calculateLevel(u.xp || 0).level,
      title: calculateLevel(u.xp || 0).title,
      isMe: u.id === req.user.id,
    }));

    const myUser = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { xp: true },
    });
    
    const countAbove = await prisma.user.count({
      where: {
        xp: { gt: myUser?.xp || 0 },
      },
    });
    const myRank = countAbove + 1;
    const totalUsers = await prisma.user.count({ where });

    res.status(200).json({
      leaderboard,
      myRank,
      totalUsers,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET STATS SUMMARY ────────────────────
router.get("/stats", authMiddleware, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
    });
    if (!user) return res.status(404).json({ message: "User not found" });

    const [notesCount, mcqCount, chatCount, testResultCount] = await Promise.all([
      prisma.note.count({ where: { userId: req.user.id } }),
      prisma.mCQ.count({ where: { userId: req.user.id } }),
      prisma.chat.count({ where: { userId: req.user.id } }),
      prisma.testResult.count({ where: { userId: req.user.id } }),
    ]);

    const aggregateScore = await prisma.testResult.aggregate({
      where: { userId: req.user.id },
      _avg: { scorePercent: true },
    });

    const avg = aggregateScore._avg.scorePercent;
    const averageScore = avg ? Math.round(avg * 10) / 10 : 0;

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
      xpRewards: XP_REWARDS,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

export default router;