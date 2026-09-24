import pkg from "@prisma/client";
const { PrismaClient } = pkg;

// Singleton pattern — reuse the same Prisma Client across all imports.
// In development, hot-reloads can create multiple instances; attaching to
// `globalThis` prevents that.
const globalForPrisma = globalThis;

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

export default prisma;
