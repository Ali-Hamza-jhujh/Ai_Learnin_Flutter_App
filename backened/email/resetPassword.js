import nodemailer from "nodemailer";
import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, "../.env") });

const sendPasswordResetEmail = async (email, name, token) => {
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL,
      pass: process.env.EMAIL_PASSWORD,
    },
  });
 const BASE_URL = process.env.FRONTEND_URL || "http://localhost:5000";
const resetLink = `${BASE_URL}/api/auth/reset-password?token=${token}`;
console.log("TOKEN BEING SENT:", token);
console.log("RESET LINK:", resetLink);
  await transporter.sendMail({
    from: `"StudyAI" <${process.env.EMAIL}>`,
    to: email,
    subject: "🔐 Reset your StudyAI password",
    html: `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    </head>
    <body style="margin:0;padding:0;background:#f4f6fb;font-family:'Segoe UI',Arial,sans-serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6fb;padding:40px 0;">
        <tr>
          <td align="center">
            <table width="520" cellpadding="0" cellspacing="0"
              style="background:#ffffff;border-radius:16px;overflow:hidden;
                     box-shadow:0 4px 24px rgba(0,0,0,0.08);">

              <!-- HEADER -->
              <tr>
                <td style="background:linear-gradient(135deg,#FF6B6B,#FF8E53);
                            padding:40px 0;text-align:center;">
                  <div style="font-size:48px;">🔐</div>
                  <h1 style="color:#ffffff;margin:12px 0 4px;font-size:28px;
                              font-weight:700;letter-spacing:1px;">StudyAI</h1>
                  <p style="color:rgba(255,255,255,0.85);margin:0;font-size:14px;">
                    Password Reset Request
                  </p>
                </td>
              </tr>

              <!-- BODY -->
              <tr>
                <td style="padding:40px 48px 32px;">
                  <h2 style="color:#1a1a2e;font-size:22px;margin:0 0 12px;">
                    Hi ${name}! 👋
                  </h2>
                  <p style="color:#555;font-size:15px;line-height:1.7;margin:0 0 24px;">
                    We received a request to reset your <strong>StudyAI</strong> password.
                    Click the button below to choose a new password.
                  </p>
                  <p style="color:#555;font-size:15px;line-height:1.7;margin:0 0 32px;">
                    This link expires in <strong>1 hour</strong>. If you did not request
                    a password reset, you can safely ignore this email.
                  </p>

                  <!-- RESET BUTTON -->
                  <div style="text-align:center;margin-bottom:32px;">
                    <a href="${resetLink}"
                       style="display:inline-block;background:linear-gradient(135deg,#FF6B6B,#FF8E53);
                              color:#ffffff;text-decoration:none;padding:16px 48px;
                              border-radius:50px;font-size:16px;font-weight:600;
                              letter-spacing:0.5px;box-shadow:0 4px 16px rgba(255,107,107,0.4);">
                      🔐 Reset My Password
                    </a>
                  </div>

                  <!-- WARNING BOX -->
                  <div style="background:#fff5f5;border-radius:10px;padding:16px 20px;
                              border-left:4px solid #FF6B6B;margin-bottom:16px;">
                    <p style="margin:0;color:#c53030;font-size:13px;line-height:1.6;">
                      ⚠️ This link expires in <strong>1 hour</strong>. Request a new one if it expires.
                    </p>
                  </div>

                  <div style="background:#f4f6fb;border-radius:10px;padding:16px 20px;
                              border-left:4px solid #6C63FF;">
                    <p style="margin:0;color:#666;font-size:13px;line-height:1.6;">
                      🔒 If you did not request a password reset, your account is safe.
                      No changes have been made.
                    </p>
                  </div>
                </td>
              </tr>

              <!-- FOOTER -->
              <tr>
                <td style="background:#f4f6fb;padding:20px 48px;text-align:center;
                            border-top:1px solid #eee;">
                  <p style="color:#aaa;font-size:12px;margin:0;">
                    © 2026 StudyAI · Made with ❤️ for students
                  </p>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    `,
  });
};

export default sendPasswordResetEmail;