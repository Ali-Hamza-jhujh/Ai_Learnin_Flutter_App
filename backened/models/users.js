import mongoose, { Schema } from "mongoose";

const userSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 100 },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },

    password: { type: String, minlength: 6, select: false },

    educationLevel: {
      type: String,
      enum: ["school", "undergraduate", "postgraduate", "other"],
      default: "undergraduate",
    },

    subject: { type: String, trim: true, default: "" },
    goal: { type: String, trim: true, default: "" },

    googleId: { type: String, sparse: true, unique: true },
    avatar: { type: String, default: "" },
    profilePicture: { type: String, default: "" },

    xp: { type: Number, default: 0, min: 0 },
    streak: { type: Number, default: 0, min: 0 },
    lastActive: { type: Date, default: Date.now },
    lastStudyDate: { type: Date },

    examDate: { type: Date },
    examSubject: { type: String, trim: true },

    freeGenerationUsed: { type: Boolean, default: false },

    achievements: [{ id: String, unlockedAt: Date }],
    activityMap: { type: Map, of: Number, default: {} },

    isVerified: { type: Boolean, default: false },
    googleAuth: { type: Boolean, default: false },

    verifyToken: { type: String, select: false },
    verifyTokenExpiry: { type: Date, select: false },
    resetToken: { type: String, select: false },
    resetTokenExpiry: { type: Date, select: false },
    refreshToken: { type: String, select: false },
  },
  { timestamps: true }
);

userSchema.index({ xp: -1 });
userSchema.index({ email: 1 });

const User = mongoose.model("User", userSchema);
export default User;
