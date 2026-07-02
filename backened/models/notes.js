import mongoose, { Schema } from "mongoose";

const notesSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    pdfHash: { type: String, index: true, default: "" },
    title: { type: String, required: true, trim: true },
    subject: { type: String, trim: true },
    mode: { type: String, enum: ["single", "multiple", "full"], default: "full" },
    documentType: {
      type: String,
      enum: ["book", "document", "plain"],
      default: "plain",
    },
    requestedChapters: { type: [String], default: [] },
    summaryType: {
      type: String,
      enum: ["quick", "normal", "deep"],
      default: "normal",
    },
    detectedChapters: [String],
    chapters: [
      {
        chapterName: { type: String },
        notes: { type: String },
      },
    ],
    notes: [
      {
        heading: { type: String },
        content: { type: String },
      },
    ],
    flashcards: [
      {
        front: String,
        back: String,
        nextReview: Date,
        easeFactor: { type: Number, default: 2.5 },
      },
    ],
    provider: { type: String },
    language: { type: String, default: "en" },
    isFavorite: { type: Boolean, default: false },
  },
  { timestamps: true }
);

notesSchema.index(
  { userId: 1, pdfHash: 1, requestedChapters: 1, summaryType: 1 },
  {
    unique: true,
    partialFilterExpression: { pdfHash: { $exists: true, $type: "string", $ne: "" } },
  }
);

const Notes = mongoose.model("notes", notesSchema);
export default Notes;
