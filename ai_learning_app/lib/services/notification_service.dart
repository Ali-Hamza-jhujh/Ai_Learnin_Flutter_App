import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/health_snapshot.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const int playbackNotificationId = 8888;

  static const _channel = AndroidNotificationDetails(
    'lumio_health_channel',
    'Health summaries',
    channelDescription: 'Morning, afternoon, evening, and limit alerts',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _alertChannel = AndroidNotificationDetails(
    'lumio_health_alerts',
    'Health limit alerts',
    channelDescription: 'Notifies when a tracked metric crosses your limit',
    importance: Importance.max,
    priority: Priority.max,
  );

  static Future<void> initialize() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    }
    _ready = true;
  }

  static Future<void> showLocalNotification(String title, String body) async {
    await initialize();
    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
    );
  }

  static Future<void> showHealthAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: _alertChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> scheduleDailyHealthChecks(HealthLimits limits) async {
    await initialize();
    await _plugin.cancel(1001);
    await _plugin.cancel(1002);
    await _plugin.cancel(1003);

    const summary =
        'Open StudyAI Health to review steps, heart rate, sleep, and vitals.';

    if (limits.morning) {
      await _daily(1001, 8, 0, 'Morning health check', 'Start of day · $summary');
    }
    if (limits.afternoon) {
      await _daily(1002, 14, 0, 'Afternoon health check', 'Midday · $summary');
    }
    if (limits.evening) {
      await _daily(1003, 20, 0, 'Evening health check', 'Evening wrap-up · $summary');
    }
  }

  static Future<void> refreshScheduledBodies(
    HealthSnapshot snapshot,
    HealthLimits limits,
  ) async {
    await initialize();
    await _plugin.cancel(1001);
    await _plugin.cancel(1002);
    await _plugin.cancel(1003);
    final line = snapshot.summaryLine;
    if (limits.morning) {
      await _daily(1001, 8, 0, 'Morning health check', line);
    }
    if (limits.afternoon) {
      await _daily(1002, 14, 0, 'Afternoon health check', line);
    }
    if (limits.evening) {
      await _daily(1003, 20, 0, 'Evening health check', line);
    }
  }

  static Future<void> _daily(
    int id,
    int hour,
    int minute,
    String title,
    String body,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstance(hour, minute),
        const NotificationDetails(
          android: _channel,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Displays or updates an ongoing lock-screen and notification center playback card
  /// with public visibility so it appears prominently on mobile lock screen.
  static Future<void> showPlaybackNotification({
    required String title,
    required String currentLine,
    required bool isPlaying,
    int? currentLineIndex,
    int? totalLines,
  }) async {
    try {
      await initialize();
      final progress = (currentLineIndex != null && totalLines != null && totalLines > 0)
          ? 'Line ${currentLineIndex + 1}/$totalLines'
          : (isPlaying ? 'Reading aloud' : 'Paused');

      final bodyText = currentLine.trim().isNotEmpty
          ? currentLine.trim()
          : (isPlaying ? 'Listening to document…' : 'Playback paused');

      final androidDetails = AndroidNotificationDetails(
        'smart_reader_playback_channel',
        'Smart Reader Playback',
        channelDescription: 'Ongoing audio reader playback controls and progress on lock screen',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: isPlaying,
        autoCancel: false,
        showWhen: false,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.transport,
        color: const Color(0xFF7B61FF),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      await _plugin.show(
        playbackNotificationId,
        '📖 $title · $progress',
        bodyText,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('Playback notification error: $e');
    }
  }

  /// Cancels and removes the playback notification from lock screen and notification bar.
  static Future<void> cancelPlaybackNotification() async {
    try {
      await initialize();
      await _plugin.cancel(playbackNotificationId);
    } catch (_) {}
  }
}

