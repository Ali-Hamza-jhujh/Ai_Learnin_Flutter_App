import mongoose, { Schema } from "mongoose";

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

    password: { type: String, required: true, minlength: 6, select: false },

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

    // Email verification
    verifyToken: { type: String, select: false },
    verifyTokenExpiry: { type: Date, select: false },

    // Password reset — these were MISSING before, causing forgot-password to fail
    resetToken: { type: String, select: false },
    resetTokenExpiry: { type: Date, select: false },

    refreshToken: { type: String, select: false },
  },
  { timestamps: true }
);

const User = mongoose.model("User", userSchema);
export default User;