import mongoose from "mongoose";
const { Schema, model } = mongoose;

const testResultSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    mcqId: { type: Schema.Types.ObjectId, ref: "MCQ", required: true },
    title: { type: String },
    subject: { type: String },
    chapter: { type: String },
    totalQuestions: { type: Number },
    correctAnswers: { type: Number },
    wrongAnswers: { type: Number },
    skippedAnswers: { type: Number },
    scorePercent: { type: Number },
    timeTakenSeconds: { type: Number },
    answers: [
      {
        question: { type: String },
        selectedAnswer: { type: String },
        correctAnswer: { type: String },
        isCorrect: { type: Boolean },
      }
    ],
    prediction: { type: String },
  },
  { timestamps: true }
);
const TestResult = mongoose.model("TestResult", testResultSchema);
export default TestResult;
