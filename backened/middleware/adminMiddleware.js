import prisma from "../prisma.js";

/**
 * adminMiddleware — must be used AFTER authMiddleware.
 * Checks that the authenticated user has isAdmin === true in the DB.
 * Double-checks DB (not just JWT) to prevent privilege escalation via stale tokens.
 */
const adminMiddleware = async (req, res, next) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ message: "Not authenticated" });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { isAdmin: true },
    });
    if (!user || user.isAdmin !== true) {
      return res.status(403).json({ message: "Admin access required" });
    }

    next();
  } catch (error) {
    res.status(500).json({ message: "Admin check failed", error: error.message });
  }
};

export default adminMiddleware;
