import mongoose, { Schema } from "mongoose";

// ══════════════════════════════════════════
// USER MODEL
// ══════════════════════════════════════════

const userSchema = new Schema(
  {
    name: { type: String, required: true, trim: true },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },

    password: {
      type: String,
      required: true,
      minlength: 6,
      select: false,
    },

    educationLevel: {
      type: String,
      required: true,
      enum: ["school", "undergraduate", "postgraduate", "other"],
    },

    subject: { type: String, required: true, trim: true },

    goal: { type: String, required: true, trim: true },

    xp: { type: Number, default: 0 },

    streak: { type: Number, default: 0 },

    lastActive: { type: Date, default: Date.now },

    profilePicture: { type: String, default: "" },

    isVerified: { type: Boolean, default: false },

    googleAuth: { type: Boolean, default: false },

    fcmToken: { type: String, default: "" },

    // ── Free generation tracking ─────────────
    // freeGenerationUsed: set to true after the user's
    // first free AI generation via the server key.
    // Enforced BOTH here (server-side) and in Flutter
    // (AIKeyStore local flag) for instant UI feedback.
    freeGenerationUsed: {
      type: Boolean,
      default: false,
    },

    // freeTierUsed: legacy alias kept for backward compatibility
    // with notes.js resolveGroqKey helper. Both fields mean the same thing.
    freeTierUsed: {
      type: Boolean,
      default: false,
    },

    // ── Auth tokens ──────────────────────────
    verifyToken: { type: String, select: false },
    verifyTokenExpiry: { type: Date, select: false },

    resetToken: { type: String, select: false },
    resetTokenExpiry: { type: Date, select: false },

    refreshToken: { type: String, select: false },
  },
  { timestamps: true }
);

const User = mongoose.model("User", userSchema);
export default User;