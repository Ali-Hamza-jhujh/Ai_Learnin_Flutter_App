// ══════════════════════════════════════════
// ADD THESE TO YOUR EXISTING user.js
// (auth routes file)
// ══════════════════════════════════════════
//
// 1. Add this import at the top of user.js:
//    import sendPasswordResetEmail from "../email/resetPassword.js";
//
// 2. Paste the 3 routes below into your router
//    (after your existing login route)
// ══════════════════════════════════════════

import crypto from "crypto";
import bcrypt from "bcrypt";
import sendPasswordResetEmail from "../email/resetPassword.js";

// ─── STEP 1 — REQUEST PASSWORD RESET ─────
//
// Flutter sends the user's email.
// We generate a token, save it, send the email.
//
// POST /api/auth/forgot-password
// Body: { email }
//
router.post("/forgot-password", async (req, res) => {
  const { email } = req.body;
  try {
    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    const user = await User.findOne({ email: email.toLowerCase().trim() });

    // SECURITY: always return success even if email not found
    // This prevents email enumeration attacks
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

    // Generate secure reset token
    const resetToken = crypto.randomBytes(32).toString("hex");
    const resetTokenExpiry = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    await User.findByIdAndUpdate(user._id, {
      resetToken,
      resetTokenExpiry,
    });

    // Respond immediately — send email in background
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

// ─── STEP 2 — SHOW RESET FORM (browser) ──
//
// User clicks the link in their email.
// We validate the token and show an HTML form
// in the browser to enter a new password.
//
// GET /api/auth/reset-password?token=xxx
//
router.get("/reset-password", async (req, res) => {
  const { token } = req.query;
  try {
    if (!token) {
      return res.status(400).send(resetPage("❌ Invalid Link", "No token provided.", false, null));
    }

    const user = await User.findOne({ resetToken: token }).select(
      "+resetToken +resetTokenExpiry"
    );

    if (!user) {
      return res.status(400).send(
        resetPage("❌ Invalid Link", "This reset link is invalid or has already been used.", false, null)
      );
    }

    if (user.resetTokenExpiry < Date.now()) {
      return res.status(400).send(
        resetPage("⏰ Link Expired", "This link has expired. Please request a new one.", false, null)
      );
    }

    // Token is valid — show the reset form
    return res.status(200).send(resetPage("🔐 Reset Password", "", true, token));

  } catch (e) {
    return res.status(500).send(resetPage("❌ Server Error", e.message, false, null));
  }
});

// ─── STEP 3A — SUBMIT NEW PASSWORD (browser form) ──
//
// User submits the HTML form with new password.
// This handles the browser form submission.
//
// POST /api/auth/reset-password
// Body (form): { token, newPassword, confirmPassword }
//
router.post("/reset-password", async (req, res) => {
  const { token, newPassword, confirmPassword } = req.body;
  try {
    if (!token || !newPassword || !confirmPassword) {
      return res.status(400).send(
        resetPage("❌ Error", "All fields are required.", false, token)
      );
    }

    if (newPassword !== confirmPassword) {
      return res.status(400).send(
        resetPage("❌ Error", "Passwords do not match. Please try again.", true, token)
      );
    }

    if (newPassword.length < 6) {
      return res.status(400).send(
        resetPage("❌ Error", "Password must be at least 6 characters.", true, token)
      );
    }

    const user = await User.findOne({ resetToken: token }).select(
      "+resetToken +resetTokenExpiry +password"
    );

    if (!user) {
      return res.status(400).send(
        resetPage("❌ Invalid Link", "This reset link is invalid or already used.", false, null)
      );
    }

    if (user.resetTokenExpiry < Date.now()) {
      return res.status(400).send(
        resetPage("⏰ Link Expired", "This link has expired. Please request a new one.", false, null)
      );
    }

    // Hash new password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    // Save new password and clear reset token
    await User.findByIdAndUpdate(user._id, {
      password: hashedPassword,
      resetToken: undefined,
      resetTokenExpiry: undefined,
    });

    return res.status(200).send(
      resetPage("✅ Password Reset!", "Your password has been changed. You can now log in to StudyAI.", false, null, true)
    );

  } catch (e) {
    return res.status(500).send(resetPage("❌ Server Error", e.message, false, null));
  }
});

// ─── STEP 3B — RESET VIA FLUTTER API ──────
//
// Alternative endpoint for Flutter to reset password
// directly via API (no browser form needed).
// Use this if you build the reset form inside Flutter.
//
// POST /api/auth/reset-password-api
// Body (JSON): { token, newPassword }
//
router.post("/reset-password-api", async (req, res) => {
  const { token, newPassword } = req.body;
  try {
    if (!token || !newPassword) {
      return res.status(400).json({ message: "Token and new password are required" });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: "Password must be at least 6 characters" });
    }

    const user = await User.findOne({ resetToken: token }).select(
      "+resetToken +resetTokenExpiry +password"
    );

    if (!user) {
      return res.status(400).json({ message: "Invalid or already used reset link" });
    }

    if (user.resetTokenExpiry < Date.now()) {
      return res.status(400).json({ message: "Reset link has expired. Please request a new one." });
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


// ══════════════════════════════════════════
// HTML PAGE BUILDER
// Used to show success/error pages in browser
// ══════════════════════════════════════════

const resetPage = (title, message, showForm, token, isSuccess = false) => `
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
  <div style="background:#fff;border-radius:20px;padding:48px 40px;
              text-align:center;max-width:440px;width:90%;
              box-shadow:0 8px 32px rgba(0,0,0,0.08);">

    <div style="font-size:64px;margin-bottom:16px;">
      ${isSuccess ? "🎉" : showForm ? "🔐" : "😕"}
    </div>

    <h1 style="color:#1a1a2e;font-size:22px;margin:0 0 12px;font-weight:700;">
      ${title}
    </h1>

    ${message ? `
    <p style="color:#666;font-size:14px;line-height:1.7;margin:0 0 24px;">
      ${message}
    </p>
    ` : ""}

    ${showForm ? `
    <!-- PASSWORD RESET FORM -->
    <form method="POST" action="/api/auth/reset-password"
          style="text-align:left;margin-top:8px;">
      <input type="hidden" name="token" value="${token}"/>

      <div style="margin-bottom:16px;">
        <label style="display:block;color:#444;font-size:13px;
                       font-weight:600;margin-bottom:6px;">
          New Password
        </label>
        <input type="password" name="newPassword" required minlength="6"
               placeholder="Enter new password"
               style="width:100%;padding:12px 16px;border:1.5px solid #e2e8f0;
                      border-radius:10px;font-size:14px;outline:none;
                      box-sizing:border-box;transition:border 0.2s;"
               onfocus="this.style.borderColor='#6C63FF'"
               onblur="this.style.borderColor='#e2e8f0'"/>
      </div>

      <div style="margin-bottom:24px;">
        <label style="display:block;color:#444;font-size:13px;
                       font-weight:600;margin-bottom:6px;">
          Confirm New Password
        </label>
        <input type="password" name="confirmPassword" required minlength="6"
               placeholder="Confirm new password"
               style="width:100%;padding:12px 16px;border:1.5px solid #e2e8f0;
                      border-radius:10px;font-size:14px;outline:none;
                      box-sizing:border-box;transition:border 0.2s;"
               onfocus="this.style.borderColor='#6C63FF'"
               onblur="this.style.borderColor='#e2e8f0'"/>
      </div>

      <button type="submit"
              style="width:100%;background:linear-gradient(135deg,#FF6B6B,#FF8E53);
                     color:#fff;border:none;padding:14px;border-radius:50px;
                     font-size:15px;font-weight:600;cursor:pointer;
                     box-shadow:0 4px 16px rgba(255,107,107,0.4);">
        🔐 Reset Password
      </button>
    </form>
    ` : ""}

    ${isSuccess ? `
    <div style="background:#f0fff4;border-radius:12px;padding:16px;
                margin-top:16px;border:1px solid #c6f6d5;">
      <p style="color:#276749;margin:0;font-size:14px;font-weight:600;">
        ✅ Password changed!
      </p>
      <p style="color:#276749;margin:8px 0 0;font-size:13px;">
        Open the StudyAI app and log in with your new password.
      </p>
    </div>
    ` : ""}

    ${!showForm && !isSuccess ? `
    <div style="background:#fff5f5;border-radius:12px;padding:16px;
                margin-top:8px;border:1px solid #fed7d7;">
      <p style="color:#c53030;margin:0;font-size:13px;">
        Please request a new password reset from the app.
      </p>
    </div>
    ` : ""}

    <div style="background:linear-gradient(135deg,#6C63FF,#48c6ef);
                border-radius:12px;padding:14px;margin-top:24px;">
      <p style="color:#fff;margin:0;font-size:12px;opacity:0.9;">
        📚 StudyAI · AI-powered learning for every student
      </p>
    </div>
  </div>
</body>
</html>
`;