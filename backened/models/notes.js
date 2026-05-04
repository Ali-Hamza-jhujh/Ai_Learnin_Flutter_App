import mongoose,{Schema} from "mongoose";

const notesSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    title: { type: String, required: true, trim: true },
    subject: { type: String, trim: true },
    mode: { type: String, enum: ["single", "multiple", "full"], required: true },
    documentType: {
      type: String,
      enum: ["book", "document", "plain"],  // add this
      default: "plain",
    },
    detectedChapters: [String],
    chapters: [
      {
        chapterName: { type: String },
        notes: { type: String },
      }
    ],
  },
  { timestamps: true }
);
 const Notes=mongoose.model("notes",notesSchema)
 export default Notes