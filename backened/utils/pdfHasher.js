import crypto from "crypto";
import { createRequire } from "module";
import PdfCache from "../models/PdfCache.js";
import { detectChapters } from "./chapterDetector.js";

const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");

export function hashPdfBuffer(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

export async function processPdfBuffer(buffer) {
  const pdfHash = hashPdfBuffer(buffer);

  const existing = await PdfCache.findOne({ pdfHash }).lean();
  if (existing) {
    return {
      cached: true,
      pdfHash,
      text: existing.fullText,
      chapters: existing.chapters || [],
      pageCount: existing.pageCount,
      language: existing.language || "en",
    };
  }

  const parsed = await pdfParse(buffer);
  const fullText = parsed.text || "";
  const chapters = detectChapters(fullText).map(({ title, startIndex, endIndex }) => ({
    title,
    startIndex,
    endIndex,
  }));

  await PdfCache.create({
    pdfHash,
    fullText,
    chapters,
    pageCount: parsed.numpages || 0,
    language: "en",
  });

  return {
    cached: false,
    pdfHash,
    text: fullText,
    chapters,
    pageCount: parsed.numpages || 0,
    language: "en",
  };
}

export async function getPdfCacheByHash(pdfHash) {
  const existing = await PdfCache.findOne({ pdfHash }).lean();
  if (!existing) return null;
  return {
    cached: true,
    pdfHash,
    text: existing.fullText,
    chapters: existing.chapters || [],
    pageCount: existing.pageCount,
    language: existing.language || "en",
  };
}

export async function cleanupPdfCacheIfOrphaned(pdfHash) {
  if (!pdfHash) return;

  const Notes = (await import("../models/notes.js")).default;
  const MCQ = (await import("../models/mcqs.js")).default;

  const [notesCount, mcqCount] = await Promise.all([
    Notes.countDocuments({ pdfHash }),
    MCQ.countDocuments({ pdfHash }),
  ]);

  if (notesCount === 0 && mcqCount === 0) {
    await PdfCache.deleteOne({ pdfHash });
  }
}
