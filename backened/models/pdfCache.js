import mongoose from "mongoose";

// ══════════════════════════════════════════
// PDF CACHE MODEL
// Stores extracted text + structure from PDFs
// so the same PDF is never re-parsed twice.
// Keyed by SHA-256 hash of the file buffer.
// Auto-deletes after 90 days (TTL index).
// ══════════════════════════════════════════

const pdfCacheSchema = new mongoose.Schema({
  // SHA-256 hash of the raw PDF bytes — unique identifier
  pdfHash: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },

  // What kind of document was detected
  documentType: {
    type: String,
    enum: ["book", "document", "plain"],
    default: "plain",
  },

  // Chapter/section names only (lightweight list for scan response)
  divisions: [String],

  // Full extracted text — reused for generation so we never re-parse
  // Can be large (500k+ chars for textbooks) — that's expected
  fullText: {
    type: String,
    required: true,
  },

  // Auto-delete after 90 days to save storage
  // MongoDB TTL index fires once per minute
  createdAt: {
    type: Date,
    default: Date.now,
    expires: "90d",
  },
});

export default mongoose.model("PdfCache", pdfCacheSchema);