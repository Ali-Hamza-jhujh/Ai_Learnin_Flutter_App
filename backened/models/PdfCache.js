import mongoose from "mongoose";

const PdfCacheSchema = new mongoose.Schema({
  pdfHash: { type: String, required: true, unique: true, index: true },
  fullText: { type: String, required: true },
  chapters: [
    {
      title: String,
      startIndex: Number,
      endIndex: Number,
    },
  ],
  pageCount: { type: Number },
  language: { type: String, default: "en" },
  createdAt: {
    type: Date,
    default: Date.now,
    index: { expireAfterSeconds: 7776000 },
  },
});

const PdfCache = mongoose.model("PdfCache", PdfCacheSchema);
export default PdfCache;
