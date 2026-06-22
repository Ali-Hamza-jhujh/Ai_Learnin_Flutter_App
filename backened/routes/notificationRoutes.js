import express from 'express';
import User from '../models/users.js';
import authMiddleware from '../Authentication/auth.js';
import { sendToDevice } from '../services/notificationService.js';


const router = express.Router();

// Save FCM token — called by Flutter on app start
router.post('/token', authMiddleware, async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'Token required' });

    await User.findByIdAndUpdate(req.user.id, { fcmToken: token });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Test notification — for testing only
router.post('/test', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user?.fcmToken) {
      return res.status(400).json({ error: 'No FCM token found for user' });
    }
    await sendToDevice(user.fcmToken, '🔔 Test!', 'Notifications are working!', {});
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;