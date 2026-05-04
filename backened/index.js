import dotenv from "dotenv";
import notesRouter from "./routes/notes.js"
import router from "./routes/user.js";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, ".env") }); 

import mongoose from "mongoose";
import connectDB from "./db.js";
import express from "express";
import morgan from "morgan";
import cors from "cors";


const app = express();
app.use(express.json());
app.use(cors());
app.use(morgan("dev"));
app.use("/api/auth", router);
app.use("/api/notes", notesRouter);

connectDB(); 

const PORT = process.env.PORT || 5000;

app.get("/", (req, res) => {
  res.send("Hello World!");
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} 🚀`);
});