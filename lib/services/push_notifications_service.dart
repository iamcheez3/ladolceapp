import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

const String _kCustomerPushEnabledKey = 'customer_push_notifications_enabled';

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
        if (await _isCustomerNotificationsMuted()) {
          return;
        }
        final type = (message.data['type'] ?? '').toString();
        if (type == 'self_order_new') {
          final rawBranchId = message.data['branch_id'];
          final messageBranchId = (rawBranchId is int)
              ? rawBranchId
              : int.tryParse(rawBranchId?.toString() ?? '');
          if (messageBranchId != null && messageBranchId > 0) {
            final api = ApiService();
            final user = await api.getCachedUser();
            final role = (user?['role'] ?? '').toString();
            if (role == 'cashier' || role == 'admin') {
              final currentBranchId = await api.getCachedBranchId();
              if (currentBranchId != null &&
                  currentBranchId > 0 &&
                  currentBranchId != messageBranchId) {
                return;
              }
            }
          }
        }
        if (type == 'self_order_new') {
          await _startRepeatingAlarm(duration: const Duration(seconds: 10));
        }

        final n = message.notification;
        if (n == null) return;

        var body = n.body ?? '';
        if (type == 'self_order_new') {
          final cn = (message.data['customer_name'] ??
                  message.data['customer'] ??
                  '')
              .toString()
              .trim();
          final cp = (message.data['customer_phone'] ??
                  message.data['phone'] ??
                  '')
              .toString()
              .trim();
          if (cn.isNotEmpty || cp.isNotEmpty) {
            final line = [
              if (cn.isNotEmpty) cn,
              if (cp.isNotEmpty) cp,
            ].join(' · ');
            if (body.isEmpty) {
              body = line;
            } else if (!body.contains(cn) &&
                (cp.isEmpty || !body.contains(cp))) {
              body = '$body\n$line';
            }
          }
        }

        // Android notification channel sound is "sticky" once created.
        // Use separate channel IDs so customer "confirmed" uses system default sound
        // while cashier "new order" can keep the custom alert sound.
        final AndroidNotificationDetails androidDetails;
        if (type == 'self_order_confirmed') {
          androidDetails = const AndroidNotificationDetails(
            'ladolce_pos_general_default_sound',
            'LaDolce Notifications',
            channelDescription: 'General notifications (system sound)',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true, // default system sound (no custom sound)
            enableVibration: true,
          );
        } else {
          androidDetails = AndroidNotificationDetails(
            'ladolce_pos_alarm_custom_sound',
            'LaDolce Alerts',
            channelDescription: 'High priority alerts (custom sound)',
            importance: Importance.max,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('notification'),
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 500, 500, 500]),
          );
        }

        const iosDetails = DarwinNotificationDetails(presentSound: true);
        final details =
            NotificationDetails(android: androidDetails, iOS: iosDetails);

        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          n.title,
          body,
          details,
          payload: jsonEncode(message.data),
        );
      } catch (_) {}
    });

    // Token refresh → re-register
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (!await _shouldRegisterFcmTokenForCurrentUser()) {
        return;
      }
      await _registerTokenToBackend(token);
    });

    if (await _shouldRegisterFcmTokenForCurrentUser()) {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenToBackend(token);
      }
    } else {
      try {
        await messaging.deleteToken();
      } catch (_) {}
    }
  }

  /// Customer self-order: in-app preference (default on). When off, FCM token is removed
  /// and foreground notifications are skipped.
  static Future<bool> isCustomerPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCustomerPushEnabledKey) ?? true;
  }

  static Future<void> setCustomerPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCustomerPushEnabledKey, enabled);
    if (!enabled) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    } else {
      await refreshBackendRegistration();
    }
  }

  static Future<bool> _isCustomerNotificationsMuted() async {
    final user = await ApiService().getCachedUser();
    if (user == null) return false;
    if ((user['role'] ?? '').toString() != 'customer') return false;
    return !(await isCustomerPushEnabled());
  }

  static Future<bool> _shouldRegisterFcmTokenForCurrentUser() async {
    final user = await ApiService().getCachedUser();
    if (user == null) return true;
    if ((user['role'] ?? '').toString() != 'customer') return true;
    return await isCustomerPushEnabled();
  }

  /// Call this after login so token definitely registers
  /// (initialize() may have run before cached_user_data existed).
  static Future<void> refreshBackendRegistration() async {
    try {
      if (!await _shouldRegisterFcmTokenForCurrentUser()) {
        try {
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
        return;
      }
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
      final hasVibrator = await Vibration.hasVibrator();
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

