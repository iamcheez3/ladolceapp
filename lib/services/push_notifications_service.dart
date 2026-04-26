import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import 'api_service.dart';

/// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationsService {
  PushNotificationsService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static final AudioPlayer _alarmPlayer = AudioPlayer();
  static Timer? _alarmStopTimer;
  static bool _alarmRunning = false;

  static bool _initialized = false;

  static void _d(String msg) {
    if (!kDebugMode) return;
    developer.log(msg, name: 'PushNotifications');
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Firebase core init (uses google-services.json / GoogleService-Info.plist).
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Local notifications (for foreground messages)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(initSettings);

    final messaging = FirebaseMessaging.instance;

    // iOS permissions (Android auto-grants on install)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _d('FCM permission: ${settings.authorizationStatus}');

    // Foreground presentation (iOS)
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Show a local notification when a push arrives in foreground
    FirebaseMessaging.onMessage.listen((message) async {
      try {
        final type = (message.data['type'] ?? '').toString();
        if (type == 'self_order_new') {
          await _startRepeatingAlarm(duration: const Duration(seconds: 10));
        }

        final n = message.notification;
        if (n == null) return;

        final androidDetails = AndroidNotificationDetails(
          'ladolce_pos_default',
          'LaDolce Notifications',
          channelDescription: 'General notifications',
          importance: Importance.max,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 500, 500, 500]),
        );
        const iosDetails = DarwinNotificationDetails();
        final details =
            NotificationDetails(android: androidDetails, iOS: iosDetails);

        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          n.title,
          n.body,
          details,
          payload: jsonEncode(message.data),
        );
      } catch (_) {}
    });

    // Token refresh → re-register
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _registerTokenToBackend(token);
    });

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerTokenToBackend(token);
    }
  }

  /// Call this after login so token definitely registers
  /// (initialize() may have run before cached_user_data existed).
  static Future<void> refreshBackendRegistration() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenToBackend(token);
      }
    } catch (_) {}
  }

  static Future<void> _registerTokenToBackend(String token) async {
    try {
      final api = ApiService();
      final user = await api.getCachedUser();
      if (user == null) return;
      final userId = (user['user_id'] is int)
          ? user['user_id'] as int
          : int.tryParse(user['user_id']?.toString() ?? '') ?? 0;
      if (userId <= 0) return;

      final device = await api.getDeviceInfoForAudit();
      await api.registerFcmToken(
        userId: userId,
        role: (user['role'] ?? '').toString(),
        token: token,
        device: device,
      );
      _d('FCM token registered for user_id=$userId');
    } catch (e) {
      _d('FCM token register failed: $e');
    }
  }

  static Future<void> _startRepeatingAlarm({required Duration duration}) async {
    if (_alarmRunning) return;
    _alarmRunning = true;

    try {
      // Loop the bundled asset sound for ~10s
      await _alarmPlayer.stop();
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.setVolume(1.0);
      await _alarmPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {}

    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        // Vibrate pattern repeatedly until canceled
        await Vibration.vibrate(pattern: [0, 500, 500], repeat: 0);
      }
    } catch (_) {}

    _alarmStopTimer?.cancel();
    _alarmStopTimer = Timer(duration, () async {
      try {
        await _alarmPlayer.stop();
      } catch (_) {}
      try {
        await Vibration.cancel();
      } catch (_) {}
      _alarmRunning = false;
    });
  }
}

