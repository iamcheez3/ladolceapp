import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api_service.dart';

class UserActivityService with WidgetsBindingObserver {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  Timer? _heartbeatTimer;
  final ApiService _apiService = ApiService();

  void startTracking() {
    WidgetsBinding.instance.addObserver(this);
    _heartbeatTimer?.cancel();
    // Send heartbeat every 5 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sendHeartbeat();
    });
    // Initial heartbeat (force new session)
    _sendHeartbeat(isNewSession: true);
    // Initial app active status
    _setAppActiveStatus(true);
  }

  void stopTracking() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _setAppActiveStatus(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setAppActiveStatus(true);
    } else {
      _setAppActiveStatus(false);
    }
  }

  Future<void> _sendHeartbeat({bool isNewSession = false}) async {
    try {
      await _apiService.sendHeartbeat(isNewSession: isNewSession);
    } catch (_) {
      // Ignore errors in background tracking
    }
  }

  Future<void> _setAppActiveStatus(bool isActive) async {
    try {
      await _apiService.setAppActiveStatus(isActive: isActive);
    } catch (_) {
      // Ignore errors in background tracking
    }
  }
}
