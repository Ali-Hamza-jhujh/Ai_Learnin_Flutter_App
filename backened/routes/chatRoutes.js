import express from "express";
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");
import upload from "../middleware/upload.js";
import Chat from "../models/chat.js";
import authMiddleware from "../Authentication/auth.js";
import dotenv from "dotenv";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// CONSTANTS
// ══════════════════════════════════════════

// Max messages kept in context window sent to Groq
// Older messages beyond this are trimmed to save tokens
const MAX_CONTEXT_MESSAGES = 20;

// Max characters of document context sent to Groq per message
// Full textbooks can be 500k+ chars — we trim to avoid token limits
const MAX_DOC_CONTEXT_CHARS = 6000;

// ══════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════

// Extract text from PDF buffer
const extractTextFromPDF = async (buffer) => {
  const data = await pdfParse(buffer);
  return data.text;
};

// Build the system prompt — changes based on whether a document is attached
const buildSystemPrompt = (subject, documentContext, documentName) => {
  let base = `You are StudyAI Tutor, an expert and friendly AI study assistant.
You help students understand concepts clearly, answer questions patiently,
and guide them step by step through difficult topics.

Rules:
- Always explain in simple, clear language suitable for students.
- If a student is confused, try a different explanation or use an analogy.
- For math or science, show working step by step.
- Keep answers focused and educational. Avoid unnecessary padding.
- If you don't know something, say so honestly.`;

  if (subject) {
    base += `\n\nThe student is currently studying: ${subject}.
Tailor your explanations to this subject where relevant.`;
  }

  if (documentContext) {
    const trimmed = documentContext.slice(0, MAX_DOC_CONTEXT_CHARS);
    base += `\n\nThe student has attached a document${documentName ? ` called "${documentName}"` : ""}.
Use the content below as your primary reference when answering questions.
If the answer is in the document, reference it directly.

--- DOCUMENT CONTENT START ---
${trimmed}
${documentContext.length > MAX_DOC_CONTEXT_CHARS ? "\n[Document trimmed for context window...]" : ""}
--- DOCUMENT CONTENT END ---`;
  }

  return base;
};

// ══════════════════════════════════════════
// ROUTES
// ══════════════════════════════════════════

// ─── CREATE NEW CHAT SESSION ───────────────
// Call this once when user opens a new chat.
// Optionally attach a PDF at session creation.
//
// Body (multipart/form-data):
//   title    (required) string
//   subject  (optional) string
//   file     (optional) PDF file — attached for document Q&A
//
router.post("/new", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    const { title, subject } = req.body;

    if (!title) {
      return res.status(400).json({ message: "Chat title is required" });
    }

    let documentContext = "";
    let documentName = "";

    if (req.file) {
      console.log("Extracting text from attached PDF...");
      documentContext = await extractTextFromPDF(req.file.buffer);
      documentName = req.file.originalname;
    }

    const chat = await Chat.create({
      userId: req.user.id,
      title,
      subject: subject || "",
      documentContext,
      documentName,
      messages: [],
      totalMessages: 0,
    });

    res.status(201).json({
      message: "Chat session created!",
      chatId: chat._id,
      title: chat.title,
      subject: chat.subject,
      hasDocument: !!documentContext,
      documentName,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── SEND MESSAGE — WITH STREAMING ─────────
//
// This is the main chat endpoint. It streams the AI response
// back to Flutter word-by-word using Server-Sent Events (SSE).
//
// Flutter listens to the stream and appends each chunk to the UI
// in real time — no waiting for the full response.
//
// URL: POST /api/chat/:chatId/message
// Body (JSON):
//   message  (required) string — the user's question
//
router.post("/:chatId/message", authMiddleware, async (req, res) => {
  try {
    const { message } = req.body;
    const { chatId } = req.params;

    if (!message || !message.trim()) {
      return res.status(400).json({ message: "Message cannot be empty" });
    }

    // Load the chat session
    const chat = await Chat.findById(chatId);
    if (!chat) return res.status(404).json({ message: "Chat session not found" });
    if (chat.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }

    // Add user message to history
    chat.messages.push({ role: "user", content: message.trim() });

    // Build context window — last N messages only
    const contextMessages = chat.messages
      .slice(-MAX_CONTEXT_MESSAGES)
      .map((m) => ({ role: m.role, content: m.content }));

    // ── SET UP SSE STREAMING ──────────────────
    // Flutter will connect and read chunks as they arrive
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.setHeader("X-Accel-Buffering", "no"); // disable nginx buffering if used
    res.flushHeaders();

    // ── CALL GROQ WITH STREAMING ──────────────
    const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        stream: true, // ← this enables streaming
        messages: [
          {
            role: "system",
            content: buildSystemPrompt(
              chat.subject,
              chat.documentContext,
              chat.documentName
            ),
          },
          ...contextMessages,
        ],
        max_tokens: 1024,
        temperature: 0.5,
      }),
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      console.log("Groq stream error:", groqRes.status, errText);
      res.write(`data: [ERROR] Groq error: ${groqRes.status}\n\n`);
      res.end();
      return;
    }

    // ── READ STREAM CHUNKS ────────────────────
    let fullAssistantReply = "";

    // Groq streams NDJSON lines — each line is:
    // "data: {...}" or "data: [DONE]"
    const reader = groqRes.body.getReader();
    const decoder = new TextDecoder("utf-8");
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");

      // Keep the last incomplete line in buffer
      buffer = lines.pop();

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed === "data: [DONE]") continue;

        // Strip "data: " prefix
        const jsonStr = trimmed.startsWith("data: ")
          ? trimmed.slice(6)
          : trimmed;

        try {
          const parsed = JSON.parse(jsonStr);
          const delta = parsed.choices?.[0]?.delta?.content;
          if (delta) {
            fullAssistantReply += delta;
            // Send chunk to Flutter as SSE event
            res.write(`data: ${JSON.stringify({ chunk: delta })}\n\n`);
          }
        } catch {
          // Malformed chunk — skip silently
        }
      }
    }

    // ── STREAM DONE — SEND FINAL EVENT ────────
    // Flutter uses this to know the stream is complete
    res.write(`data: ${JSON.stringify({ done: true, fullReply: fullAssistantReply })}\n\n`);
    res.end();

    // ── SAVE ASSISTANT REPLY TO DB ────────────
    // Save after streaming so DB write doesn't delay the response
    if (fullAssistantReply) {
      chat.messages.push({ role: "assistant", content: fullAssistantReply });
      chat.totalMessages = chat.messages.length;
      await chat.save();
      if (chat.totalMessages % 5 === 0) {
        awardXP(req.user.id, "CHAT_MESSAGE").catch(console.error);
      }
    }
  } catch (e) {
    console.log("Chat stream error:", e.message);
    // If headers already sent (streaming started), end gracefully
    if (!res.headersSent) {
      res.status(500).json({ message: `Error: ${e.message}` });
    } else {
      res.write(`data: ${JSON.stringify({ error: e.message })}\n\n`);
      res.end();
    }
  }
});

// ─── SEND MESSAGE — NO STREAMING (fallback) ──
//
// Use this if Flutter SSE implementation is complex.
// Returns the full reply in one JSON response.
// Slower UX but simpler to integrate.
//
// URL: POST /api/chat/:chatId/message-simple
//
router.post("/:chatId/message-simple", authMiddleware, async (req, res) => {
  try {
    const { message } = req.body;
    const { chatId } = req.params;

    if (!message || !message.trim()) {
      return res.status(400).json({ message: "Message cannot be empty" });
    }

    const chat = await Chat.findById(chatId);
    if (!chat) return res.status(404).json({ message: "Chat session not found" });
    if (chat.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }

    chat.messages.push({ role: "user", content: message.trim() });

    const contextMessages = chat.messages
      .slice(-MAX_CONTEXT_MESSAGES)
      .map((m) => ({ role: m.role, content: m.content }));

    const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        stream: false,
        messages: [
          {
            role: "system",
            content: buildSystemPrompt(
              chat.subject,
              chat.documentContext,
              chat.documentName
            ),
          },
          ...contextMessages,
        ],
        max_tokens: 1024,
        temperature: 0.5,
      }),
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      throw new Error(`Groq error: ${groqRes.status} — ${errText}`);
    }

    const data = await groqRes.json();
    const reply = data.choices[0].message.content;

    chat.messages.push({ role: "assistant", content: reply });
    chat.totalMessages = chat.messages.length;
    await chat.save();

    res.status(200).json({
      message: "Reply generated",
      reply,
      chatId: chat._id,
    });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET ALL CHAT SESSIONS (list) ────────────
router.get("/my-chats", authMiddleware, async (req, res) => {
  try {
    const chats = await Chat.find({ userId: req.user.id })
      .sort({ updatedAt: -1 })
      .select("-messages -documentContext"); // exclude heavy fields for list
    res.status(200).json({ chats });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── GET SINGLE CHAT (with full history) ─────
router.get("/:chatId", authMiddleware, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId).select("-documentContext");
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    res.status(200).json({ chat });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── DELETE CHAT SESSION ──────────────────────
router.delete("/:chatId", authMiddleware, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId);
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    await Chat.findByIdAndDelete(req.params.chatId);
    res.status(200).json({ message: "Chat deleted successfully" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

// ─── CLEAR CHAT HISTORY (keep session, wipe messages) ─
router.delete("/:chatId/clear", authMiddleware, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId);
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    chat.messages = [];
    chat.totalMessages = 0;
    await chat.save();
    res.status(200).json({ message: "Chat history cleared" });
  } catch (e) {
    res.status(500).json({ message: `Error: ${e.message}` });
  }
});

export default router;