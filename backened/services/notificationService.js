import admin from 'firebase-admin';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const serviceAccount = require('../firebase-service-account.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

export const sendToDevice = async (fcmToken, title, body, data = {}) => {
  try {
    const message = {
      token: fcmToken,
      notification: { title, body },
      data: data,
      android: {
        priority: 'high',
        notification: {
          channelId: 'studyai_main',
          color: '#7B61FF',
        },
      },
    };
    const response = await admin.messaging().send(message);
    console.log('Notification sent:', response);
    return { success: true };
  } catch (error) {
    console.error('Notification error:', error.message);
    return { success: false };
  }
};

export const notifyNotesReady = (fcmToken, title) =>
  sendToDevice(fcmToken, '📝 Notes Ready!',
    `"${title}" notes have been generated successfully.`,
    { screen: 'notes' });

export const notifyMCQReady = (fcmToken, title) =>
  sendToDevice(fcmToken, '❓ Quiz Ready!',
    `"${title}" quiz is ready. Start testing yourself!`,
    { screen: 'mcq' });

export const notifyXPMilestone = (fcmToken, xp, level) =>
  sendToDevice(fcmToken, '⚡ Level Up!',
    `You reached ${level} with ${xp} XP! Keep going!`,
    { screen: 'profile' });

export const notifyStreakReminder = (fcmToken, streak) =>
  sendToDevice(fcmToken, '🔥 Keep your streak!',
    `You have a ${streak} day streak. Study today to keep it!`,
    { screen: 'home' });