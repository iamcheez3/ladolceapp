import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../screens/maintenance_screen.dart';

class MaintenanceService {
  static final MaintenanceService _instance = MaintenanceService._internal();
  factory MaintenanceService() => _instance;
  MaintenanceService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  Timer? _timer;
  bool _isChecking = false;
  bool _isMaintenanceModeActive = false;

  void startChecking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkStatus();
    });
    // Initial check
    _checkStatus();
  }

  void stopChecking() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final status = await ApiService().fetchMaintenanceStatus();
      if (status['is_active'] == true) {
        if (!_isMaintenanceModeActive) {
          _isMaintenanceModeActive = true;
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            // Force navigate to maintenance screen
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/maintenance',
              (route) => false,
              arguments: {
                'message_en': status['message_en'],
                'message_lo': status['message_lo'],
              },
            );
          }
        }
      } else {
        _isMaintenanceModeActive = false;
      }
    } catch (_) {
      // Ignore network errors during background check
    } finally {
      _isChecking = false;
    }
  }
}
