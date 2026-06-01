import mongoose, { Schema } from "mongoose";

const savedVideoSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    videoId: { type: String, required: true },
    title: { type: String },
    channelName: { type: String },
    thumbnail: { type: String },   // medium thumbnail URL
    url: { type: String },
    duration: { type: String },
    views: { type: String },
    subject: { type: String },     // what subject user was studying when they saved it
    notes: { type: String, default: "" }, // personal notes on the video
  },
  { timestamps: true }
);

// Prevent duplicate saves — one user can't save same video twice
savedVideoSchema.index({ userId: 1, videoId: 1 }, { unique: true });

const SavedVideo = mongoose.models.SavedVideo ||
  mongoose.model("SavedVideo", savedVideoSchema);
export default SavedVideo;