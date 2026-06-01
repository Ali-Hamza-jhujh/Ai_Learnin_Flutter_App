import mongoose, { Schema } from "mongoose";

const messageSchema = new Schema(
  {
    role: { type: String, enum: ["user", "assistant"], required: true },
    content: { type: String, required: true },
  },
  { _id: false } // no separate _id per message — saves space
);

const chatSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },

    // display name shown in chat history list
    title: { type: String, required: true, trim: true },

    // optional context — subject the student is studying
    subject: { type: String, trim: true },

    // optional — if user attached a PDF, we store extracted text here
    // so follow-up questions can still reference it without re-uploading
    documentContext: { type: String, default: "" },
    documentName: { type: String, default: "" },

    // full conversation history
    messages: [messageSchema],

    // track token usage roughly (optional — useful for analytics)
    totalMessages: { type: Number, default: 0 },
  },
  { timestamps: true }
);

const Chat = mongoose.model("Chat", chatSchema);
export default Chat;