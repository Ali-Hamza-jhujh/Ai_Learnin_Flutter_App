
// # Push Notifications Setup — StudyAI

// ## What we're building
// - Flutter receives FCM push notifications
// - Backend sends notifications for:
//   - Daily study reminder
//   - Streak about to break
//   - Notes/MCQ generation complete
//   - New XP milestone reached
// EOF

// cat > /mnt/user-data/outputs/notification_service.dart << 'DARTEOF'
import 'dart:convert';
import 'api_client.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════
// NOTIFICATION SERVICE
// Handles FCM + local notifications
// ══════════════════════════════════════════

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showLocalNotification(
    title: message.notification?.title ?? 'StudyAI',
    body: message.notification?.body ?? '',
    payload: message.data.toString(),
  );
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // Android notification channel
  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'studyai_main',
    'StudyAI Notifications',
    description: 'Study reminders, XP updates, and more',
    importance: Importance.high,
  );

  // ── Initialize ────────────────────────
  static Future<void> init() async {
    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus ==
        AuthorizationStatus.denied) return;

    // Init local notifications
    const android = AndroidInitializationSettings(
        '@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android channel
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Background handler
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // Foreground handler
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Get FCM token and save it
    await _saveToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_onTokenRefresh);
  }

  // ── Save FCM token ────────────────────
  static Future<void> _saveToken() async {
  try {
    final token = await _fcm.getToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      debugPrint('FCM Token: $token');

      // Send to backend using your existing ApiClient
      await ApiClient.post(
        '/api/notifications/token',
        body: {'token': token},
      );
    }
  } catch (e) {
    debugPrint('FCM token error: $e');
  }
}

  static Future<void> _onTokenRefresh(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('fcm_token', token);

  await ApiClient.post(
    '/api/notifications/token',
    body: {'token': token},
  ).catchError((e) => debugPrint('Token refresh error: $e'));
}
  // ── Get saved token ───────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  // ── Show local notification ───────────
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF7B61FF),
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ── Foreground message ────────────────
  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    showLocalNotification(
      title: notification.title ?? 'StudyAI',
      body: notification.body ?? '',
      payload: message.data.toString(),
    );
  }

  // ── Notification tap ──────────────────
  static void _onNotificationTap(NotificationResponse response) {
    // TODO: Navigate based on payload
    debugPrint('Notification tapped: ${response.payload}');
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('App opened from notification: ${message.data}');
    // TODO: Navigate to relevant screen based on message.data['screen']
  }

  // ── Schedule daily reminder ───────────
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    // Using flutter_local_notifications scheduled notification
    await _local.periodicallyShow(
      1,
      '📚 Time to Study!',
      'Keep your streak alive — open StudyAI and learn something new.',
      RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'studyai_reminders',
          'Daily Reminders',
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF7B61FF),
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Cancel all ───────────────────────
  static Future<void> cancelAll() async {
    await _local.cancelAll();
  }

  // ── Cancel by id ─────────────────────
  static Future<void> cancel(int id) async {
    await _local.cancel(id);
  }

  // ── Predefined notifications ──────────

  static Future<void> notifyNotesReady(String title) async {
    await showLocalNotification(
      id: 10,
      title: '📝 Notes Ready!',
      body: '"$title" notes have been generated successfully.',
      payload: 'screen:notes',
    );
  }

  static Future<void> notifyMCQReady(String title) async {
    await showLocalNotification(
      id: 11,
      title: '❓ Quiz Ready!',
      body: '"$title" quiz is ready. Start testing yourself!',
      payload: 'screen:mcq',
    );
  }

  static Future<void> notifyXPMilestone(int xp, String level) async {
    await showLocalNotification(
      id: 12,
      title: '⚡ Level Up!',
      body: 'You reached $level with $xp XP! Keep going!',
      payload: 'screen:profile',
    );
  }

  static Future<void> notifyStreakReminder(int streak) async {
    await showLocalNotification(
      id: 13,
      title: '🔥 Keep your streak!',
      body: 'You have a $streak day streak. Study today to keep it!',
      payload: 'screen:home',
    );
  }
}

