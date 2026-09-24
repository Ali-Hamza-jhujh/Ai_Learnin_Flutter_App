import crypto from "crypto";
import { createRequire } from "module";
import prisma from "../prisma.js";
import { detectChapters } from "./chapterDetector.js";

const require = createRequire(import.meta.url);
const pdfParse = require("pdf-parse");

export function hashPdfBuffer(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

export async function processPdfBuffer(buffer) {
  const pdfHash = hashPdfBuffer(buffer);

  const existing = await prisma.pdfCache.findUnique({
    where: { pdfHash },
  });

  if (existing) {
    return {
      cached: true,
      pdfHash,
      text: existing.fullText,
      chapters: existing.chapters || [],
      pageCount: existing.pageCount,
      language: existing.language || "en",
      ocrUsed: existing.ocrUsed === true,
      ocrProvider: existing.ocrProvider || null,
    };
  }

  const parsed = await pdfParse(buffer);
  const fullText = (parsed.text || "").trim();

  if (!fullText) {
    const error = new Error("This scanned PDF needs on-device OCR.");
    error.statusCode = 422;
    error.code = "SCANNED_PDF_REQUIRES_DEVICE_OCR";
    throw error;
  }

  const chapters = detectChapters(fullText).map(({ title, startIndex, endIndex }) => ({
    title,
    startIndex,
    endIndex,
  }));

  await prisma.pdfCache.upsert({
    where: { pdfHash },
    update: {},
    create: {
      pdfHash,
      fullText,
      chapters,
      pageCount: parsed.numpages || 0,
      language: "en",
      ocrUsed: false,
      ocrProvider: null,
    },
  });

  return {
    cached: false,
    pdfHash,
    text: fullText,
    chapters,
    pageCount: parsed.numpages || 0,
    language: "en",
    ocrUsed: false,
    ocrProvider: null,
  };
}

export async function getPdfCacheByHash(pdfHash) {
  const existing = await prisma.pdfCache.findUnique({
    where: { pdfHash },
  });

  if (!existing) return null;
  return {
    cached: true,
    pdfHash,
    text: existing.fullText,
    chapters: existing.chapters || [],
    pageCount: existing.pageCount,
    language: existing.language || "en",
    ocrUsed: existing.ocrUsed === true,
    ocrProvider: existing.ocrProvider || null,
  };
}

export async function cleanupPdfCacheIfOrphaned(pdfHash) {
  if (!pdfHash) return;

  const [notesCount, mcqCount] = await Promise.all([
    prisma.note.count({ where: { pdfHash } }),
    prisma.mCQ.count({ where: { pdfHash } }),
  ]);

  if (notesCount === 0 && mcqCount === 0) {
    await prisma.pdfCache.deleteMany({ where: { pdfHash } });
  }
}
