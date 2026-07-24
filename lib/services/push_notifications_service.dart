import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'maintenance_service.dart';
import '../screens/self_orders_review_screen.dart';
import '../screens/customer_order_detail_screen.dart';

const String _kCustomerPushEnabledKey = 'customer_push_notifications_enabled';
const Color _kBrandNavy = Color(0xFF1E3A8A);

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

  static bool _isAppActive = false;
  static Map<String, dynamic>? _pendingNotification;

  static void setAppActive(bool active) {
    _d('setAppActive: $active');
    _isAppActive = active;
    if (active && _pendingNotification != null) {
      final payload = _pendingNotification!;
      _pendingNotification = null;
      _d('Executing queued notification payload: $payload');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleNotificationClick(payload);
      });
    }
  }

  static Future<void> handleNotificationClick(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    _d('handleNotificationClick: type=$type, data=$data');

    if (!_isAppActive) {
      _d('App is not in an active screen. Queuing notification.');
      _pendingNotification = data;
      return;
    }

    final api = ApiService();
    final user = await api.getCachedUser();
    if (user == null) {
      _d('No cached user found, cannot redirect.');
      return;
    }

    final role = (user['role'] ?? '').toString();
    final navigator = MaintenanceService().navigatorKey.currentState;
    if (navigator == null) {
      _d('Navigator state not available.');
      return;
    }

    if (role == 'cashier' || role == 'admin') {
      if (type == 'self_order_new') {
        _d('Navigating Cashier/Admin to SelfOrdersReviewScreen');
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const SelfOrdersReviewScreen(),
          ),
        );
      }
    } else if (role == 'customer') {
      final rawOrderId = data['order_id'] ?? data['id'];
      final orderId = (rawOrderId is int)
          ? rawOrderId
          : int.tryParse(rawOrderId?.toString() ?? '');
      if (orderId != null && orderId > 0) {
        _d('Fetching order $orderId details for Customer redirect');
        try {
          final orderDetail = await api.fetchOrderReceipt(orderId);
          _d('Navigating Customer to CustomerOrderDetailScreen');
          navigator.push(
            MaterialPageRoute(
              builder: (_) => CustomerOrderDetailScreen(
                item: orderDetail,
                api: api,
              ),
            ),
          );
        } catch (e) {
          _d('Failed to load order receipt: $e');
        }
      }
    }
  }

  // Generation-token deduplication: each new toggle increments this counter.
  // The async FCM closure captures its generation on entry and aborts if
  // a newer toggle has already superseded it — no Completer needed.
  static int _syncGeneration = 0;
  static bool _isSyncing = false;

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
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            handleNotificationClick(data);
          } catch (_) {}
        }
      },
    );
    await _ensureAndroidNotificationChannels();

    // Terminated state launch message check
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _d('Terminated state launch message: ${initialMessage.data}');
        _pendingNotification = initialMessage.data;
      }
    } catch (_) {}

    // Background to foreground click listener
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _d('Background notification click: ${message.data}');
      handleNotificationClick(message.data);
    });

    final messaging = FirebaseMessaging.instance;

    // iOS permissions (Android 13+ asks runtime in system flow)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _d('FCM permission: ${settings.authorizationStatus}');

    // Also ask iOS local notifications permission explicitly.
    await _local
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    await _local
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Keep permission_handler state in sync (used elsewhere in app).
    try {
      await Permission.notification.request();
    } catch (_) {}

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

        // All notification types use the same custom-sound channel so both
        // the foreground local notification banner AND the OS background/lock-
        // screen notification play notification.mp3 + vibrate.
        // For self_order_new the audioplayer alarm is ALSO started above so the
        // sound loops while the app is open; the local notification banner just
        // provides the visual + a single system-sound hit.
        const androidDetails = AndroidNotificationDetails(
          'ladolce_pos_custom_sound',
          'LaDolce Alerts',
          channelDescription: 'Order alerts with custom sound and vibration',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification'),
          enableVibration: true,
          color: _kBrandNavy,
          colorized: true,
        );

        // iOS: custom notification sounds must use a bundled, supported format.
        const iosDetails = DarwinNotificationDetails(
          presentSound: true,
          sound: 'notification.caf',
          presentAlert: true,
          presentBadge: true,
        );
        const details =
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

  /// iOS: request notification permission after first frame is rendered.
  /// Calling too early (during app bootstrap) may not show the system prompt.
  static Future<void> requestPermissionPostFrame() async {
    if (!Platform.isIOS) return;
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isPermanentlyDenied) return;
    } catch (_) {}

    try {
      await _local
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (_) {}

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  static Future<void> _ensureAndroidNotificationChannels() async {
    if (!Platform.isAndroid) return;
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // Legacy general channel (kept so old installs don't break)
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'ladolce_pos_general_default_sound',
        'LaDolce Notifications',
        description: 'General notifications (system sound)',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Legacy foreground-alert silent channel (kept for backwards compat)
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'ladolce_pos_alarm_custom_sound_silent',
        'LaDolce Foreground Alerts',
        description: 'High priority alerts (app alarm sound)',
        importance: Importance.max,
        playSound: false,
        enableVibration: false,
      ),
    );

    // Primary channel: custom notification.mp3 + vibration pattern.
    // Used for ALL notification types (foreground local + background/terminated OS).
    // Note: Android caches channel properties on first creation, so this channel
    // MUST be created before any notification is shown. Uninstall the app to
    // reset if you previously created this channel without a custom sound.
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        'ladolce_pos_custom_sound',
        'LaDolce Alerts',
        description: 'Order alerts with custom sound and vibration',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 300, 500, 300, 500]),
      ),
    );
  }

  /// Customer self-order: in-app preference (default on). When off, FCM token is removed
  /// and foreground notifications are skipped.
  /// 
  /// This method reads from local storage only and returns immediately.
  /// Use this for UI initialization and quick state checks.
  static Future<bool> isCustomerPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCustomerPushEnabledKey) ?? true;
  }

  /// Production-grade notification preference toggle.
  ///
  /// ### Optimistic update flow
  /// 1. **Local persist** — the new value is written to SharedPreferences
  ///    immediately, before any network call, so the UI can reflect it at once.
  /// 2. **Generation token** — every call increments [_syncGeneration]. The
  ///    background FCM closure captures its own token and is silently abandoned
  ///    if a newer call has already superseded it. This prevents the
  ///    `Bad state: Future already completed` crash caused by stale Completer
  ///    references.
  /// 3. **Background sync** — FCM registration/deregistration runs
  ///    asynchronously. On success, [_isSyncing] is cleared. On failure, the
  ///    local preference is reverted and [onFailure] is invoked so the UI can
  ///    revert the switch and show a Snackbar.
  ///
  /// The method returns immediately after the local write; there is no need
  /// to `await` it in the UI — just fire and forget.
  static Future<void> setCustomerPushEnabled(
    bool enabled, {
    /// Called on the calling isolate when FCM sync fails AND this call is still
    /// the most recent one (i.e. the user hasn't toggled again since).
    void Function(String reason)? onFailure,
  }) async {
    _d('🔄 Toggle → $enabled (gen ${_syncGeneration + 1})');

    // ── Step 1: Persist locally (optimistic) ──────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final previousState = prefs.getBool(_kCustomerPushEnabledKey) ?? true;
    await prefs.setBool(_kCustomerPushEnabledKey, enabled);
    _d('💾 Persisted locally: $enabled (was: $previousState)');

    // ── Step 2: Bump generation — cancels any in-flight sync ─────────────
    final myGeneration = ++_syncGeneration;
    _d('🔢 Sync generation: $myGeneration');

    // ── Step 3: Fire-and-forget FCM sync ─────────────────────────────────
    // We intentionally do NOT await this so the UI stays responsive.
    _syncFcm(
      enabled: enabled,
      previousState: previousState,
      myGeneration: myGeneration,
      prefs: prefs,
      onFailure: onFailure,
    );
  }

  /// Internal FCM synchronisation worker. Checks [myGeneration] against
  /// [_syncGeneration] before every async gap to detect cancellation.
  static Future<void> _syncFcm({
    required bool enabled,
    required bool previousState,
    required int myGeneration,
    required SharedPreferences prefs,
    void Function(String reason)? onFailure,
  }) async {
    // Guard: a newer toggle has already taken over.
    if (myGeneration != _syncGeneration) {
      _d('⏭️ Gen $myGeneration superseded by $_syncGeneration — aborting');
      return;
    }

    _isSyncing = true;
    _d('🌐 FCM sync start — enabled=$enabled gen=$myGeneration');

    try {
      if (!enabled) {
        // ── Disable: delete FCM token ─────────────────────────────────
        _d('🗑️ Deleting FCM token…');
        await FirebaseMessaging.instance.deleteToken();
        if (myGeneration != _syncGeneration) return; // superseded
        _d('✅ FCM token deleted on-device (gen=$myGeneration)');

        // Also clear the token on the backend immediately so no push
        // is attempted before Firebase propagates the UNREGISTERED error.
        try {
          final api = ApiService();
          final user = await api.getCachedUser();
          final userId = (user?['user_id'] is int)
              ? user!['user_id'] as int
              : int.tryParse(user?['user_id']?.toString() ?? '') ?? 0;
          if (userId > 0) {
            await api.deregisterFcmToken(userId: userId);
            _d('✅ FCM token deregistered on backend (gen=$myGeneration)');
          }
        } catch (e) {
          // Non-critical — Option D will self-heal on next send attempt.
          _d('⚠️ Backend deregister failed (non-critical): $e');
        }

      } else {
        // ── Enable: register FCM token ────────────────────────────────
        _d('📲 Registering FCM token…');
        await refreshBackendRegistration();
        if (myGeneration != _syncGeneration) return; // superseded
        _d('✅ FCM token registered (gen=$myGeneration)');
      }
    } catch (e) {
      if (myGeneration != _syncGeneration) {
        // Newer toggle already superseded us — don't revert, the new
        // state will manage its own FCM sync.
        _d('⏭️ FCM error but gen $myGeneration superseded — ignoring: $e');
        return;
      }

      _d('❌ FCM sync failed (gen=$myGeneration): $e');

      // Revert local preference to the pre-toggle value.
      try {
        await prefs.setBool(_kCustomerPushEnabledKey, previousState);
        _d('↩️ Reverted local preference to: $previousState');
      } catch (revertErr) {
        _d('⚠️ Could not revert local preference: $revertErr');
      }

      // Notify the UI so it can revert the switch and show a Snackbar.
      onFailure?.call(e.toString());
    } finally {
      if (myGeneration == _syncGeneration) {
        _isSyncing = false;
      }
    }
  }

  /// Whether an FCM sync is currently in progress.
  static bool get isSyncing => _isSyncing;

  /// Cancel any in-flight sync by advancing the generation counter.
  /// The running closure will detect the mismatch and abort gracefully.
  static void cancelPendingOperations() {
    _syncGeneration++;
    _isSyncing = false;
    _d('🚫 Cancelled pending FCM sync (new gen: $_syncGeneration)');
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
      final token = await _resolveFcmTokenForRegistration();
      if (token != null && token.isNotEmpty) {
        await _registerTokenToBackend(token);
      } else {
        _d('FCM token unavailable (yet), skip register for now.');
      }
    } catch (_) {}
  }

  static Future<String?> _resolveFcmTokenForRegistration() async {
    final messaging = FirebaseMessaging.instance;

    if (Platform.isIOS) {
      try {
        final settings = await messaging.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
          await messaging.requestPermission(alert: true, badge: true, sound: true);
        }
      } catch (_) {}

      // iOS: APNs token may not be ready immediately after first launch/login.
      for (int i = 0; i < 8; i++) {
        try {
          final apns = await messaging.getAPNSToken();
          if (apns != null && apns.isNotEmpty) break;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }

    for (int i = 0; i < 5; i++) {
      try {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    return null;
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
      _d('FCM TOKEN >>> $token');
    } catch (e) {
      _d('FCM token register failed: $e');
      rethrow; // Re-throw to allow proper error handling upstream
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
