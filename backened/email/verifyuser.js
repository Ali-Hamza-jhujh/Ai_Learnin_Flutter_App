import nodemailer from "nodemailer";
import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, "../.env") }); // load .env from parent folder

const sendVerificationEmail = async (email, name, token) => {
  
  // create transporter INSIDE function — after dotenv is loaded
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL,
      pass: process.env.EMAIL_PASSWORD,
    },
  });

  console.log("EMAIL:", process.env.EMAIL);
  console.log("PASSWORD:", process.env.EMAIL_PASSWORD);

  await transporter.sendMail({
    from: `"StudyAI" <${process.env.EMAIL}>`,
    to: email,
    subject: "✅ Verify your StudyAI account",
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
              <tr>
                <td style="background:linear-gradient(135deg,#6C63FF,#48c6ef);
                            padding:40px 0;text-align:center;">
                  <div style="font-size:48px;">📚</div>
                  <h1 style="color:#ffffff;margin:12px 0 4px;font-size:28px;
                              font-weight:700;letter-spacing:1px;">StudyAI</h1>
                  <p style="color:rgba(255,255,255,0.85);margin:0;font-size:14px;">
                    Your AI-powered study companion
                  </p>
                </td>
              </tr>
              <tr>
                <td style="padding:40px 48px 32px;">
                  <h2 style="color:#1a1a2e;font-size:22px;margin:0 0 12px;">
                    Welcome, ${name}! 👋
                  </h2>
                  <p style="color:#555;font-size:15px;line-height:1.7;margin:0 0 24px;">
                    Thank you for joining <strong>StudyAI</strong>. You are one step away from
                    unlocking AI-powered notes, MCQs, and your personal study tutor.
                  </p>
                  <p style="color:#555;font-size:15px;line-height:1.7;margin:0 0 32px;">
                    Click the button below to verify your email address.
                    This link expires in <strong>24 hours</strong>.
                  </p>
                  <div style="text-align:center;margin-bottom:32px;">
                    <a href="http://localhost:5000/api/auth/verify?token=${token}"
                       style="display:inline-block;background:linear-gradient(135deg,#6C63FF,#48c6ef);
                              color:#ffffff;text-decoration:none;padding:16px 48px;
                              border-radius:50px;font-size:16px;font-weight:600;
                              letter-spacing:0.5px;box-shadow:0 4px 16px rgba(108,99,255,0.4);">
                      ✅ Verify My Email
                    </a>
                  </div>
                  <div style="background:#f4f6fb;border-radius:10px;padding:16px 20px;
                              border-left:4px solid #6C63FF;">
                    <p style="margin:0;color:#666;font-size:13px;line-height:1.6;">
                      🔒 If you did not create a StudyAI account you can safely ignore this email.
                    </p>
                  </div>
                </td>
              </tr>
              <tr>
                <td style="padding:0 48px 32px;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="text-align:center;padding:12px;">
                        <div style="font-size:28px;">🤖</div>
                        <p style="color:#888;font-size:12px;margin:6px 0 0;">AI Notes</p>
                      </td>
                      <td style="text-align:center;padding:12px;">
                        <div style="font-size:28px;">❓</div>
                        <p style="color:#888;font-size:12px;margin:6px 0 0;">MCQ Generator</p>
                      </td>
                      <td style="text-align:center;padding:12px;">
                        <div style="font-size:28px;">🎥</div>
                        <p style="color:#888;font-size:12px;margin:6px 0 0;">Video Lectures</p>
                      </td>
                      <td style="text-align:center;padding:12px;">
                        <div style="font-size:28px;">📊</div>
                        <p style="color:#888;font-size:12px;margin:6px 0 0;">Exam Prediction</p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
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

export default sendVerificationEmail;