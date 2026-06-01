
import User from "../models/users.js";
import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import dotenv from "dotenv";
dotenv.config();
import sendVerificationEmail from "../email/verifyuser.js";
import sendPasswordResetEmail from "../email/resetPassword.js";
const BASE_URL = process.env.FRONTEND_URL || "http://localhost:5000";
const router = express.Router();
const SECRET_KEY = process.env.SECRET_KEY;

// ─── REGISTER ─────────────────────────────────────────────
router.post("/register", async (req, res) => {
  const { name, email, password, educationLevel, subject, goal, profilePicture } = req.body;
  try {
    if (!name || !email || !password || !educationLevel || !subject || !goal) {
      return res.status(400).json({ message: "All fields are required" });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ message: "Email already registered" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const verifyToken = crypto.randomBytes(32).toString("hex");
    const verifyTokenExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const user = await User.create({
      name, email, password: hashedPassword,
      educationLevel, subject, goal, profilePicture,
      verifyToken, verifyTokenExpiry,
    });

    user.password = undefined;

    res.status(201).json({
      message: "Registered! Please check your email to verify your account.",
      user,
    });

    sendVerificationEmail(email, name, verifyToken)
      .then(() => console.log("✅ Verify email sent to:", email))
      .catch((err) => console.log("❌ Email error:", err.message));

  } catch (e) {
    if (e.code === 11000) return res.status(409).json({ message: "Email already registered" });
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── RESEND VERIFY ────────────────────────────────────────
router.post("/resend-verify", async (req, res) => {
  const { email } = req.body;
  try {
    if (!email) return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email }).select("+verifyToken +verifyTokenExpiry");
    if (!user) return res.status(404).json({ message: "No account found with this email" });
    if (user.isVerified) return res.status(400).json({ message: "User already verified" });

    const verifyToken = crypto.randomBytes(32).toString("hex");
    const verifyTokenExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await User.findByIdAndUpdate(user._id, { verifyToken, verifyTokenExpiry });

    res.status(200).json({ message: "Verification email resent! Please check your inbox." });

    sendVerificationEmail(email, user.name, verifyToken)
      .then(() => console.log("✅ Resend email sent to:", email))
      .catch((err) => console.log("❌ Resend email error:", err.message));

  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── VERIFY EMAIL (still HTML — opens in browser from email link) ──
// Keep this as HTML because the user clicks from their email browser
router.get("/verify", async (req, res) => {
  const { token } = req.query;
  try {
    if (!token) {
      return res.status(400).send(verifyPage("❌ Invalid Link", "No token was provided.", false));
    }

    const user = await User.findOne({ verifyToken: token }).select("+verifyToken +verifyTokenExpiry");
    if (!user) {
      return res.status(400).send(verifyPage("❌ Invalid Link", "This link is invalid or already used.", false));
    }
    if (user.verifyTokenExpiry < Date.now()) {
      return res.status(400).send(verifyPage("⏰ Link Expired", "This link has expired. Please request a new one.", false));
    }

    await User.findByIdAndUpdate(user._id, {
      isVerified: true,
      verifyToken: undefined,
      verifyTokenExpiry: undefined,
    });

    return res.status(200).send(verifyPage("✅ Email Verified!", "Your account is verified. You can now log in to StudyAI.", true));

  } catch (e) {
    return res.status(500).send(verifyPage("❌ Server Error", e.message, false));
  }
});

// ─── LOGIN ────────────────────────────────────────────────
router.post("/login", async (req, res) => {
  const { email, password } = req.body;
  try {
    if (!email || !password) return res.status(400).json({ message: "All fields are required" });

    const user = await User.findOne({ email }).select("+password");
    if (!user) return res.status(400).json({ message: "Wrong email or password" });
    if (!user.isVerified) return res.status(403).json({ message: "Please verify your email first" });

    const passwordCheck = await bcrypt.compare(password, user.password);
    if (!passwordCheck) return res.status(400).json({ message: "Wrong email or password" });

    const token = jwt.sign({ id: user._id }, SECRET_KEY, { expiresIn: "7d" });
    user.password = undefined;

    res.status(200).json({ message: "Login successful!", user, token });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── FORGOT PASSWORD → JSON only (Flutter handles UI) ─────
router.post("/forgot-password", async (req, res) => {
  const { email } = req.body;
  try {
    if (!email) return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email: email.toLowerCase().trim() });

    if (!user) {
      return res.status(200).json({
        message: "If an account with that email exists, a reset link has been sent.",
      });
    }

    if (!user.isVerified) {
      return res.status(403).json({
        message: "Please verify your email first before resetting your password.",
      });
    }

    const resetToken = crypto.randomBytes(32).toString("hex");
    const resetTokenExpiry = new Date(Date.now() + 60 * 60 * 1000);

    await User.findByIdAndUpdate(user._id, { resetToken, resetTokenExpiry });

    // Respond immediately — email sends in background
    res.status(200).json({
      message: "If an account with that email exists, a reset link has been sent.",
    });

    sendPasswordResetEmail(email, user.name, resetToken)
      .then(() => console.log("✅ Reset email sent to:", email))
      .catch((err) => console.log("❌ Reset email error:", err.message));

  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── RESET PASSWORD PAGE (keep HTML — opens in browser from email link) ──
// User clicks link in email → opens browser → sees this HTML form
// We keep this as HTML because it's a browser page, not Flutter
router.get("/reset-password", async (req, res) => {
  const { token } = req.query;
  try {
    if (!token) {
      return res.status(400).send(resetPage("❌ Invalid Link", "No token provided.", false, null));
    }

    const user = await User.findOne({ resetToken: token }).select("+resetToken +resetTokenExpiry");
    if (!user) {
      return res.status(400).send(resetPage("❌ Invalid Link", "This link is invalid or already used.", false, null));
    }
    if (user.resetTokenExpiry < Date.now()) {
      return res.status(400).send(resetPage("⏰ Link Expired", "This link has expired. Please request a new one.", false, null));
    }

    return res.status(200).send(resetPage("🔐 Reset Password", "", true, token));

  } catch (e) {
    return res.status(500).send(resetPage("❌ Server Error", e.message, false, null));
  }
});

// ─── RESET PASSWORD SUBMIT (browser form POST) ────────────
router.post("/reset-password", async (req, res) => {
  const { token, newPassword, confirmPassword } = req.body;
  try {
    if (!token || !newPassword || !confirmPassword) {
      return res.status(400).send(resetPage("❌ Error", "All fields are required.", false, token));
    }
    if (newPassword !== confirmPassword) {
      return res.status(400).send(resetPage("❌ Error", "Passwords do not match.", true, token));
    }
    if (newPassword.length < 6) {
      return res.status(400).send(resetPage("❌ Error", "Password must be at least 6 characters.", true, token));
    }

    const user = await User.findOne({ resetToken: token }).select("+resetToken +resetTokenExpiry +password");
    if (!user) {
      return res.status(400).send(resetPage("❌ Invalid Link", "This link is invalid or already used.", false, null));
    }
    if (user.resetTokenExpiry < Date.now()) {
      return res.status(400).send(resetPage("⏰ Expired", "This link has expired. Please request a new one.", false, null));
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await User.findByIdAndUpdate(user._id, {
      password: hashedPassword,
      resetToken: undefined,
      resetTokenExpiry: undefined,
    });

    // ── SUCCESS: return JSON so Flutter ResetPasswordScreen can handle it ──
    // Also keep HTML for browser users who came from email link
    return res.status(200).send(resetPage("✅ Password Reset!", "Your password has been changed. You can now log in.", false, null, true));

  } catch (e) {
    return res.status(500).send(resetPage("❌ Server Error", e.message, false, null));
  }
});

// ─── RESET PASSWORD API → JSON only (Flutter ResetPasswordScreen) ──
// Flutter sends token + new password → gets JSON back
router.post("/reset-password-api", async (req, res) => {
  const { token, newPassword } = req.body;
  try {
    if (!token || !newPassword) {
      return res.status(400).json({ message: "Token and new password are required" });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: "Password must be at least 6 characters" });
    }

    const user = await User.findOne({ resetToken: token }).select("+resetToken +resetTokenExpiry +password");
    if (!user) return res.status(400).json({ message: "Invalid or already used reset link" });
    if (user.resetTokenExpiry < Date.now()) {
      return res.status(400).json({ message: "Reset link expired. Please request a new one." });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await User.findByIdAndUpdate(user._id, {
      password: hashedPassword,
      resetToken: undefined,
      resetTokenExpiry: undefined,
    });

    res.status(200).json({ message: "Password reset successfully! You can now log in." });

  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GOOGLE AUTH → JSON only (Flutter handles UI) ─────────
router.post("/google", async (req, res) => {
  const { idToken, name, email, profilePicture } = req.body;
  try {
    if (!email) return res.status(400).json({ message: "Email is required" });

    let user = await User.findOne({ email });

    if (user) {
      if (!user.isVerified) {
        await User.findByIdAndUpdate(user._id, { isVerified: true });
        user.isVerified = true;
      }
    } else {
      user = await User.create({
        name: name || email.split("@")[0],
        email,
        password: crypto.randomBytes(32).toString("hex"),
        educationLevel: "undergraduate",
        subject: "General",
        goal: "Learn and grow",
        profilePicture: profilePicture || "",
        isVerified: true,
        googleAuth: true,
      });
    }

    const token = jwt.sign({ id: user._id }, SECRET_KEY, { expiresIn: "7d" });
    user.password = undefined;

    const needsProfile = user.subject === "General" || !user.subject;

    res.status(200).json({
      message: "Google login successful!",
      user, token, needsProfile,
    });

  } catch (e) {
    if (e.code === 11000) return res.status(409).json({ message: "Email already registered" });
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ══════════════════════════════════════════
// HTML PAGES
// Only 2 remain — both are browser pages opened from email links
// Flutter never sees these — they open in the phone's browser
// ══════════════════════════════════════════

// Verify email page — user clicks from email → browser opens this
const verifyPage = (title, message, success) => `
<!DOCTYPE html><html><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>${title}</title></head>
<body style="margin:0;padding:0;background:#f4f6fb;font-family:'Segoe UI',Arial,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
  <div style="background:#fff;border-radius:20px;padding:56px 48px;text-align:center;max-width:420px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,0.08);">
    <div style="font-size:72px;margin-bottom:16px;">${success ? "🎉" : "😕"}</div>
    <h1 style="color:#1a1a2e;font-size:24px;margin:0 0 12px;font-weight:700;">${title}</h1>
    <p style="color:#666;font-size:15px;line-height:1.7;margin:0 0 32px;">${message}</p>
    ${success ? `
    <div style="background:#f0fff4;border-radius:12px;padding:20px;margin-bottom:28px;border:1px solid #c6f6d5;">
      <div style="font-size:32px;margin-bottom:8px;">🚀</div>
      <p style="color:#276749;margin:0;font-size:14px;font-weight:600;">You are all set!</p>
      <p style="color:#276749;margin:8px 0 0;font-size:13px;">Open the StudyAI app and log in to start learning.</p>
    </div>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
      <tr>
        <td style="text-align:center;padding:8px;"><div style="font-size:24px;">🤖</div><p style="color:#888;font-size:11px;margin:4px 0 0;">AI Notes</p></td>
        <td style="text-align:center;padding:8px;"><div style="font-size:24px;">❓</div><p style="color:#888;font-size:11px;margin:4px 0 0;">MCQs</p></td>
        <td style="text-align:center;padding:8px;"><div style="font-size:24px;">🎥</div><p style="color:#888;font-size:11px;margin:4px 0 0;">Lectures</p></td>
        <td style="text-align:center;padding:8px;"><div style="font-size:24px;">📊</div><p style="color:#888;font-size:11px;margin:4px 0 0;">Predictions</p></td>
      </tr>
    </table>` : `
    <div style="background:#fff5f5;border-radius:12px;padding:16px;margin-bottom:28px;border:1px solid #fed7d7;">
      <p style="color:#c53030;margin:0;font-size:14px;">Please try again or request a new verification email.</p>
    </div>`}
    <div style="background:linear-gradient(135deg,#6C63FF,#48c6ef);border-radius:12px;padding:16px;">
      <p style="color:#fff;margin:0;font-size:13px;">📚 StudyAI · AI-powered learning for every student</p>
    </div>
  </div>
</body></html>`;

// Reset password page — user clicks from email → browser opens this form
const resetPage = (title, message, showForm, token, isSuccess = false) => `
<!DOCTYPE html><html><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>${title}</title></head>
<body style="margin:0;padding:0;background:#f4f6fb;font-family:'Segoe UI',Arial,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
  <div style="background:#fff;border-radius:20px;padding:48px 40px;text-align:center;max-width:440px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,0.08);">
    <div style="font-size:64px;margin-bottom:16px;">${isSuccess ? "🎉" : showForm ? "🔐" : "😕"}</div>
    <h1 style="color:#1a1a2e;font-size:22px;margin:0 0 12px;font-weight:700;">${title}</h1>
    ${message ? `<p style="color:#666;font-size:14px;line-height:1.7;margin:0 0 24px;">${message}</p>` : ""}
    ${showForm ? `
<form method="POST" action="${BASE_URL}/api/auth/reset-password" style="text-align:left;margin-top:8px;">
      <input type="hidden" name="token" value="${token}"/>
      <div style="margin-bottom:16px;">
        <label style="display:block;color:#444;font-size:13px;font-weight:600;margin-bottom:6px;">New Password</label>
        <input type="password" name="newPassword" required minlength="6" placeholder="Enter new password"
          style="width:100%;padding:12px 16px;border:1.5px solid #e2e8f0;border-radius:10px;font-size:14px;outline:none;box-sizing:border-box;"/>
      </div>
      <div style="margin-bottom:24px;">
        <label style="display:block;color:#444;font-size:13px;font-weight:600;margin-bottom:6px;">Confirm Password</label>
        <input type="password" name="confirmPassword" required minlength="6" placeholder="Confirm new password"
          style="width:100%;padding:12px 16px;border:1.5px solid #e2e8f0;border-radius:10px;font-size:14px;outline:none;box-sizing:border-box;"/>
      </div>
      <button type="submit" style="width:100%;background:linear-gradient(135deg,#FF6B6B,#FF8E53);color:#fff;border:none;padding:14px;border-radius:50px;font-size:15px;font-weight:600;cursor:pointer;">
        🔐 Reset Password
      </button>
    </form>` : ""}
    ${isSuccess ? `
    <div style="background:#f0fff4;border-radius:12px;padding:16px;margin-top:16px;border:1px solid #c6f6d5;">
      <p style="color:#276749;margin:0;font-size:14px;">Open the StudyAI app and log in with your new password.</p>
    </div>` : ""}
    ${!showForm && !isSuccess ? `
    <div style="background:#fff5f5;border-radius:12px;padding:16px;margin-top:8px;border:1px solid #fed7d7;">
      <p style="color:#c53030;margin:0;font-size:13px;">Please request a new password reset from the app.</p>
    </div>` : ""}
    <div style="background:linear-gradient(135deg,#6C63FF,#48c6ef);border-radius:12px;padding:14px;margin-top:24px;">
      <p style="color:#fff;margin:0;font-size:12px;">📚 StudyAI · AI-powered learning for every student</p>
    </div>
  </div>
</body></html>`;

export default router;
