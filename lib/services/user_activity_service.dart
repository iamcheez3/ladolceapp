import 'dart:async';
import 'api_service.dart';

class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  Timer? _heartbeatTimer;
  final ApiService _apiService = ApiService();

  void startTracking() {
    _heartbeatTimer?.cancel();
    // Send heartbeat every 5 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sendHeartbeat();
    });
    // Initial heartbeat (force new session)
    _sendHeartbeat(isNewSession: true);
  }

  void stopTracking() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat({bool isNewSession = false}) async {
    try {
      await _apiService.sendHeartbeat(isNewSession: isNewSession);
    } catch (_) {
      // Ignore errors in background tracking
    }
  }
}
