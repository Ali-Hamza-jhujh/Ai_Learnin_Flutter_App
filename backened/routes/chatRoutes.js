import express from "express";
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");
import upload from "../middleware/upload.js";
import prisma from "../prisma.js";
import authMiddleware from "../Authentication/auth.js";
import dotenv from "dotenv";
import { awardXP } from "../services/xpService.js";
dotenv.config();

const router = express.Router();

// ══════════════════════════════════════════
// CONSTANTS
// ══════════════════════════════════════════

const MAX_CONTEXT_MESSAGES = 20;
const MAX_DOC_CONTEXT_CHARS = 6000;

// ══════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════

const extractTextFromPDF = async (buffer) => {
  const data = await pdfParse(buffer);
  return data.text;
};

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
router.post("/new", authMiddleware, upload.single("file"), async (req, res) => {
  try {
    const { title, subject } = req.body;

    if (!title) {
      return res.status(400).json({ message: "Chat title is required" });
    }

    let documentContext = "";
    let documentName = "";

    if (req.file) {
      try {
        console.log("Extracting text from attached PDF...");
        documentContext = await extractTextFromPDF(req.file.buffer);
        documentName = req.file.originalname;
      } catch (pdfError) {
        console.error("PDF extraction error:", pdfError);
        return res.status(400).json({ message: "Failed to parse PDF file. Please ensure it's a valid PDF." });
      }
    }

    const chat = await prisma.chat.create({
      data: {
        userId: req.user.id,
        title,
        subject: subject || "",
        documentContext,
        documentName,
        messages: [],
        totalMessages: 0,
      },
    });

    res.status(201).json({
      message: "Chat session created!",
      chatId: chat.id,
      _id: chat.id,
      title: chat.title,
      subject: chat.subject,
      hasDocument: !!documentContext,
      documentName,
    });
  } catch (e) {
    console.error("Chat creation error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to create chat session";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── SEND MESSAGE — WITH STREAMING ─────────
router.post("/:chatId/message", authMiddleware, async (req, res) => {
  try {
    const { message } = req.body;
    const { chatId } = req.params;

    if (!message || !message.trim()) {
      return res.status(400).json({ message: "Message cannot be empty" });
    }

    const chat = await prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat) return res.status(404).json({ message: "Chat session not found" });
    if (chat.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }

    const messages = Array.isArray(chat.messages) ? [...chat.messages] : [];
    messages.push({ role: "user", content: message.trim() });

    const contextMessages = messages
      .slice(-MAX_CONTEXT_MESSAGES)
      .map((m) => ({ role: m.role, content: m.content }));

    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.setHeader("X-Accel-Buffering", "no");
    res.flushHeaders();

    const userKeys = {
      groq: req.headers["x-groq-key"] || "",
      gemini: req.headers["x-gemini-key"] || "",
      cerebras: req.headers["x-cerebras-key"] || "",
    };
    
    const keysToTry = [
      { key: userKeys.groq, source: 'user-groq' },
      { key: userKeys.gemini, source: 'user-gemini' },
      { key: userKeys.cerebras, source: 'user-cerebras' },
      { key: process.env.LUMIO_GROQ_KEY, source: 'server-groq' },
      { key: process.env.LUMIO_GEMINI_KEY, source: 'server-gemini' },
      { key: process.env.LUMIO_CEREBRAS_KEY, source: 'server-cerebras' },
    ].filter(k => k.key && k.key.trim());
    
    if (keysToTry.length === 0) {
      res.write(`data: ${JSON.stringify({ error: "No API keys available. Please configure your API keys or use the offline model." })}\n\n`);
      res.end();
      return;
    }
    
    let groqRes = null;
    
    for (const { key, source } of keysToTry) {
      try {
        console.log(`Trying ${source} key for streaming chat...`);
        
        groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${key}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "llama-3.3-8b-instant",
            stream: true,
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
          console.log(`${source} key error for streaming:`, groqRes.status, errText);
          
          if (groqRes.status === 429 || groqRes.status === 401) {
            continue;
          }
          
          res.write(`data: ${JSON.stringify({ error: `${source} error: ${groqRes.status}` })}\n\n`);
          res.end();
          return;
        }
        
        break;
      } catch (error) {
        console.log(`${source} key failed for streaming:`, error.message);
      }
    }
    
    if (!groqRes || !groqRes.ok) {
      res.write(`data: ${JSON.stringify({ error: "All API keys have reached their limits or are invalid. Please try again later or use the offline model." })}\n\n`);
      res.end();
      return;
    }

    let fullAssistantReply = "";
    const reader = groqRes.body.getReader();
    const decoder = new TextDecoder("utf-8");
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop();

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed === "data: [DONE]") continue;

        const jsonStr = trimmed.startsWith("data: ")
          ? trimmed.slice(6)
          : trimmed;

        try {
          const parsed = JSON.parse(jsonStr);
          const delta = parsed.choices?.[0]?.delta?.content;
          if (delta) {
            fullAssistantReply += delta;
            res.write(`data: ${JSON.stringify({ chunk: delta })}\n\n`);
          }
        } catch {}
      }
    }

    res.write(`data: ${JSON.stringify({ done: true, fullReply: fullAssistantReply })}\n\n`);
    res.end();

    if (fullAssistantReply) {
      try {
        messages.push({ role: "assistant", content: fullAssistantReply });
        await prisma.chat.update({
          where: { id: chatId },
          data: {
            messages,
            totalMessages: messages.length,
          },
        });
        if (messages.length % 5 === 0) {
          awardXP(req.user.id, "CHAT_MESSAGE").catch(err => console.error('XP award error:', err));
        }
      } catch (dbError) {
        console.error("Failed to save chat message:", dbError);
      }
    }
  } catch (e) {
    console.error("Chat stream error:", e);
    if (!res.headersSent) {
      if (e.message && e.message.includes('API key')) {
        return res.status(401).json({ message: e.message });
      }
      const statusCode = e.statusCode || 500;
      const message = e.message || "Failed to send message";
      res.status(statusCode).json({ message: `Error: ${message}` });
    } else {
      res.write(`data: ${JSON.stringify({ error: e.message })}\n\n`);
      res.end();
    }
  }
});

// ─── SEND MESSAGE — NO STREAMING (fallback) ──
router.post("/:chatId/message-simple", authMiddleware, async (req, res) => {
  try {
    const { message } = req.body;
    const { chatId } = req.params;

    if (!message || !message.trim()) {
      return res.status(400).json({ message: "Message cannot be empty" });
    }

    const chat = await prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat) return res.status(404).json({ message: "Chat session not found" });
    if (chat.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }

    const messages = Array.isArray(chat.messages) ? [...chat.messages] : [];
    messages.push({ role: "user", content: message.trim() });

    const contextMessages = messages
      .slice(-MAX_CONTEXT_MESSAGES)
      .map((m) => ({ role: m.role, content: m.content }));

    const userKeys = {
      groq: req.headers["x-groq-key"] || "",
      gemini: req.headers["x-gemini-key"] || "",
      cerebras: req.headers["x-cerebras-key"] || "",
    };
    
    const keysToTry = [
      { key: userKeys.groq, source: 'user-groq' },
      { key: userKeys.gemini, source: 'user-gemini' },
      { key: userKeys.cerebras, source: 'user-cerebras' },
      { key: process.env.LUMIO_GROQ_KEY, source: 'server-groq' },
      { key: process.env.LUMIO_GEMINI_KEY, source: 'server-gemini' },
      { key: process.env.LUMIO_CEREBRAS_KEY, source: 'server-cerebras' },
    ].filter(k => k.key && k.key.trim());
    
    if (keysToTry.length === 0) {
      throw new Error("No API keys available. Please configure your API keys or use the offline model.");
    }
    
    let reply = null;
    
    for (const { key, source } of keysToTry) {
      try {
        console.log(`Trying ${source} key for chat message...`);
        
        const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${key}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "llama-3.3-8b-instant",
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
          console.log(`${source} key error for chat:`, groqRes.status, errText);
          if (groqRes.status === 429 || groqRes.status === 401) continue;
          throw new Error(`${source} error: ${groqRes.status}`);
        }

        const data = await groqRes.json();
        reply = data.choices[0].message.content;
        break;
      } catch (error) {
        console.log(`${source} key failed for chat:`, error.message);
      }
    }
    
    if (!reply) {
      throw new Error("All API keys have reached their limits or are invalid. Please try again later or use the offline model.");
    }

    messages.push({ role: "assistant", content: reply });
    await prisma.chat.update({
      where: { id: chatId },
      data: {
        messages,
        totalMessages: messages.length,
      },
    });
    
    awardXP(req.user.id, "CHAT_MESSAGE").catch(err => console.error('XP award error:', err));

    res.status(200).json({
      message: "Reply generated",
      reply,
      chatId: chat.id,
      _id: chat.id,
    });
  } catch (e) {
    console.error("Chat message error:", e);
    if (e.message && e.message.includes('All API keys have reached their limits')) {
      return res.status(429).json({ 
        message: e.message,
        suggestOffline: true,
        error: "api_limits_exceeded"
      });
    }
    if (e.message && e.message.includes('API key')) {
      return res.status(401).json({ message: e.message });
    }
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to send message";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── GET ALL CHAT SESSIONS (list) ────────────
router.get("/my-chats", authMiddleware, async (req, res) => {
  try {
    const chats = await prisma.chat.findMany({
      where: { userId: req.user.id },
      orderBy: { updatedAt: "desc" },
      select: {
        id: true,
        userId: true,
        title: true,
        subject: true,
        documentName: true,
        totalMessages: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    const formatted = chats.map(c => ({ ...c, _id: c.id }));
    res.status(200).json({ chats: formatted });
  } catch (e) {
    console.error("Get chats error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to load chats";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── GET SINGLE CHAT (with full history) ─────
router.get("/:chatId", authMiddleware, async (req, res) => {
  try {
    const chat = await prisma.chat.findUnique({
      where: { id: req.params.chatId },
      select: {
        id: true,
        userId: true,
        title: true,
        subject: true,
        documentName: true,
        messages: true,
        totalMessages: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    res.status(200).json({ chat: { ...chat, _id: chat.id } });
  } catch (e) {
    console.error("Get chat error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to load chat";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── DELETE CHAT SESSION ──────────────────────
router.delete("/:chatId", authMiddleware, async (req, res) => {
  try {
    const chat = await prisma.chat.findUnique({
      where: { id: req.params.chatId },
    });
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    await prisma.chat.delete({
      where: { id: req.params.chatId },
    });
    res.status(200).json({ message: "Chat deleted successfully" });
  } catch (e) {
    console.error("Delete chat error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to delete chat";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

// ─── CLEAR CHAT HISTORY (keep session, wipe messages) ─
router.delete("/:chatId/clear", authMiddleware, async (req, res) => {
  try {
    const chat = await prisma.chat.findUnique({
      where: { id: req.params.chatId },
    });
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.userId !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }
    await prisma.chat.update({
      where: { id: req.params.chatId },
      data: {
        messages: [],
        totalMessages: 0,
      },
    });
    res.status(200).json({ message: "Chat history cleared" });
  } catch (e) {
    console.error("Clear chat error:", e);
    const statusCode = e.statusCode || 500;
    const message = e.message || "Failed to clear chat history";
    res.status(statusCode).json({ message: `Error: ${message}` });
  }
});

export default router;