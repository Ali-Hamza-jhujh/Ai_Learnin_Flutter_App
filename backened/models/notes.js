import mongoose, { Schema } from "mongoose";

// ══════════════════════════════════════════
// NOTES MODEL
// ══════════════════════════════════════════

const notesSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // SHA-256 hash linking this note to a PdfCache entry.
    // Used for deduplication: if a user uploads the same PDF
    // again we skip re-extraction and re-generation.
    pdfHash: {
      type: String,
      index: true,
      default: null,
    },

    title: { type: String, required: true, trim: true },

    subject: { type: String, trim: true, default: "" },

    mode: {
      type: String,
      enum: ["single", "multiple", "full"],
      required: true,
    },

    documentType: {
      type: String,
      enum: ["book", "document", "plain"],
      default: "plain",
    },

    // All chapter/section names detected in the PDF
    detectedChapters: [String],

    // The specific chapters this note was generated for.
    // Used to detect if the user is asking for the exact
    // same content again so we can return the cached note.
    requestedChapters: {
      type: [String],
      default: [],
    },

    // The actual generated content — one entry per chapter
    chapters: [
      {
        chapterName: { type: String },
        notes: { type: String },
      },
    ],
  },
  { timestamps: true }
);

// Compound index for fast dedup lookup:
// "Does this user already have notes for this PDF + mode + chapters?"
notesSchema.index({ userId: 1, pdfHash: 1, mode: 1 });

const Notes = mongoose.model("notes", notesSchema);
export default Notes;