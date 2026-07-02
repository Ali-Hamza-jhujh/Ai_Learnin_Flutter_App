import mongoose from "mongoose";
const { Schema, model } = mongoose;

const mcqSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    pdfHash: { type: String, index: true, default: "" },
    title: { type: String, required: true, trim: true },
    subject: { type: String, trim: true },
    chapter: { type: String },
    requestedChapters: { type: [String], default: [] },
    difficulty: {
      type: String,
      enum: ["easy", "medium", "hard"],
      default: "medium",
    },
    numMcqs: { type: Number, default: 10 },
    mode: {
      type: String,
      enum: ["practice", "exam", "pastpaper"],
      default: "practice",
    },
    documentType: {
      type: String,
      enum: ["book", "document", "plain"],
      default: "plain",
    },
    questions: [
      {
        question: { type: String },
        options: [{ type: String }],
        correctAnswer: { type: String },
        answer: { type: String },
        explanation: { type: String },
        topic: { type: String },
      },
    ],
    results: [
      {
        attemptedAt: Date,
        score: Number,
        totalQ: Number,
        timeTaken: Number,
        wrongTopics: [String],
      },
    ],
    provider: { type: String },
  },
  { timestamps: true }
);

mcqSchema.index(
  { userId: 1, pdfHash: 1, requestedChapters: 1, difficulty: 1, numMcqs: 1 },
  {
    unique: true,
    partialFilterExpression: { pdfHash: { $exists: true, $type: "string", $ne: "" } },
  }
);

export default model("MCQ", mcqSchema);
