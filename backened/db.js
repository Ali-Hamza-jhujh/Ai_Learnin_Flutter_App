import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import prisma from "./prisma.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, ".env") }); // load env here too

const connectDB = async () => {
  try {
    await prisma.$connect();
    console.log("PostgreSQL Connected via Prisma ✅");
  } catch (error) {
    console.log("PostgreSQL Connection Error ❌", error.message);
    process.exit(1);
  }
};

export default connectDB;