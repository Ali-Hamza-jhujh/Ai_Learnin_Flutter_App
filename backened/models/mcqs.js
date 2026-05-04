import mongoose from "mongoose";
const { Schema, model } = mongoose;

const mcqSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    title: { type: String, required: true, trim: true },
    subject: { type: String, trim: true },
    chapter: { type: String },
    documentType: { type: String, enum: ["book", "document", "plain"], default: "plain" },
    questions: [
      {
        question: { type: String },
        options: [{ type: String }],
        correctAnswer: { type: String },
        explanation: { type: String },
      }
    ],
  },
  { timestamps: true }
);

export default model("MCQ", mcqSchema);