import mongoose from "mongoose";
const { Schema, model } = mongoose;

// ══════════════════════════════════════════
// MCQ MODEL
// ══════════════════════════════════════════

const mcqSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // SHA-256 hash linking to PdfCache entry.
    // Used for dedup: same PDF + same mode + same chapters
    // returns existing MCQ set instantly.
    pdfHash: {
      type: String,
      index: true,
      default: null,
    },

    title:   { type: String, required: true, trim: true },
    subject: { type: String, trim: true, default: "" },
    chapter: { type: String, default: "Full Document" },

    documentType: {
      type: String,
      enum: ["book", "document", "plain"],
      default: "plain",
    },

    // Generation mode used
    mode: {
      type: String,
      enum: ["single", "multiple", "full"],
      default: "full",
    },

    // Specific chapters this MCQ set was generated for.
    // Used to detect exact duplicate requests.
    requestedChapters: {
      type: [String],
      default: [],
    },

    questions: [
      {
        question:      { type: String },
        options:       [{ type: String }],
        correctAnswer: { type: String },
        explanation:   { type: String },
      },
    ],
  },
  { timestamps: true }
);

// Compound index for fast dedup lookup
mcqSchema.index({ userId: 1, pdfHash: 1, mode: 1 });

export default model("MCQ", mcqSchema);