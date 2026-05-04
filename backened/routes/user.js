import User from "../models/users.js";
import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import dotenv from "dotenv";
dotenv.config();
import sendVerificationEmail from "../email/verifyuser.js";

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
      name,
      email,
      password: hashedPassword,
      educationLevel,
      subject,
      goal,
      profilePicture,
      verifyToken,
      verifyTokenExpiry,
    });

    user.password = undefined;

    // respond immediately
    res.status(201).json({
      message: "Registered! Please check your email to verify your account.",
      user,
    });

    // send email in background with error logging
    sendVerificationEmail(email, name, verifyToken)
      .then(() => console.log("✅ Email sent to:", email))
      .catch((err) => console.log("❌ Email error:", err.message));

  } catch (e) {
    if (e.code === 11000) {
      return res.status(409).json({ message: "Email already registered" });
    }
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── RESEND VERIFY ────────────────────────────────────────
router.post("/resend-verify", async (req, res) => {
  const { email } = req.body;
  try {
    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    const user = await User.findOne({ email }).select("+verifyToken +verifyTokenExpiry");
    if (!user) {
      return res.status(404).json({ message: "No account found with this email" });
    }

    if (user.isVerified) {
      return res.status(400).json({ message: "User already verified" });
    }

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

router.get("/verify", async (req, res) => {
  const { token } = req.query;
  try {
    if (!token) {
      return res.status(400).send(verifyPage("❌ Invalid Link", "No token was provided.", false));
    }

    const user = await User.findOne({ verifyToken: token }).select(
      "+verifyToken +verifyTokenExpiry"
    );

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
    if (!email || !password) {
      return res.status(400).json({ message: "All fields are required" });
    }

    const user = await User.findOne({ email }).select("+password");
    if (!user) {
      return res.status(400).json({ message: "Wrong email or password" });
    }

    if (!user.isVerified) {
      return res.status(403).json({ message: "Please verify your email first" });
    }

    const passwordCheck = await bcrypt.compare(password, user.password);
    if (!passwordCheck) {
      return res.status(400).json({ message: "Wrong email or password" });
    }

    const token = jwt.sign(
      { id: user._id },
      SECRET_KEY,
      { expiresIn: "7d" }
    );

    user.password = undefined;

    res.status(200).json({
      message: "Login successful!",
      user,
      token,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});


const verifyPage = (title, message, success) => `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background:#f4f6fb;
             font-family:'Segoe UI',Arial,sans-serif;
             display:flex;align-items:center;justify-content:center;
             min-height:100vh;">
  <div style="background:#fff;border-radius:20px;padding:56px 48px;
              text-align:center;max-width:420px;width:90%;
              box-shadow:0 8px 32px rgba(0,0,0,0.08);">

    <div style="font-size:72px;margin-bottom:16px;">
      ${success ? "🎉" : "😕"}
    </div>

    <div style="background:linear-gradient(135deg,#6C63FF,#48c6ef);
                border-radius:50%;width:80px;height:80px;
                display:flex;align-items:center;justify-content:center;
                margin:0 auto 24px;font-size:36px;">
      ${success ? "✅" : "❌"}
    </div>

    <h1 style="color:#1a1a2e;font-size:24px;margin:0 0 12px;font-weight:700;">
      ${title}
    </h1>

    <p style="color:#666;font-size:15px;line-height:1.7;margin:0 0 32px;">
      ${message}
    </p>

    ${success ? `
    <div style="background:#f0fff4;border-radius:12px;padding:20px;
                margin-bottom:28px;border:1px solid #c6f6d5;">
      <div style="font-size:32px;margin-bottom:8px;">🚀</div>
      <p style="color:#276749;margin:0;font-size:14px;font-weight:600;">
        You are all set!
      </p>
      <p style="color:#276749;margin:8px 0 0;font-size:13px;">
        Open the StudyAI app and log in to start your learning journey.
      </p>
    </div>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
      <tr>
        <td style="text-align:center;padding:8px;">
          <div style="font-size:24px;">🤖</div>
          <p style="color:#888;font-size:11px;margin:4px 0 0;">AI Notes</p>
        </td>
        <td style="text-align:center;padding:8px;">
          <div style="font-size:24px;">❓</div>
          <p style="color:#888;font-size:11px;margin:4px 0 0;">MCQs</p>
        </td>
        <td style="text-align:center;padding:8px;">
          <div style="font-size:24px;">🎥</div>
          <p style="color:#888;font-size:11px;margin:4px 0 0;">Lectures</p>
        </td>
        <td style="text-align:center;padding:8px;">
          <div style="font-size:24px;">📊</div>
          <p style="color:#888;font-size:11px;margin:4px 0 0;">Predictions</p>
        </td>
      </tr>
    </table>
    ` : `
    <div style="background:#fff5f5;border-radius:12px;padding:16px;
                margin-bottom:28px;border:1px solid #fed7d7;">
      <p style="color:#c53030;margin:0;font-size:14px;">
        Please try again or request a new verification email.
      </p>
    </div>
    `}

    <div style="background:linear-gradient(135deg,#6C63FF,#48c6ef);
                border-radius:12px;padding:16px;">
      <p style="color:#fff;margin:0;font-size:13px;opacity:0.9;">
        📚 StudyAI · AI-powered learning for every student
      </p>
    </div>
  </div>
</body>
</html>
`;

export default router;