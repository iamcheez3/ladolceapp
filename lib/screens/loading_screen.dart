import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/api_service.dart';
import '../theme/coffee_luxury_background.dart';
import 'customer_self_order_screen.dart';
import 'pin_screen.dart';
import 'login_screen.dart';
import 'pos_identity_screen.dart';

class LoadingScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const LoadingScreen({super.key, required this.user});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _statusMessage = 'Starting…';
  /// 0.0 – 1.0 while loading; not used in error state.
  double _progress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _statusMessage = 'Starting…';
      _progress = 0;
      _hasError = false;
    });

    try {
      await ApiService().syncAllData(
        onProgress: (message, progress) {
          if (!mounted) return;
          setState(() {
            _statusMessage = message;
            _progress = progress.clamp(0.0, 1.0);
          });
        },
      );
      if (!mounted) return;
      _proceedToApp();
    } catch (e) {
      if (!mounted) return;
      final hasCache = await ApiService().hasBasicCache();
      if (hasCache) {
        developer.log(
          '[LoadingScreen] Sync failed, but we have offline cache. Proceeding.',
          name: 'LoadingScreen',
        );
        _proceedToApp();
      } else {
        setState(() {
          _statusMessage =
              'Network error and no offline cache available.\nPlease connect to the internet to initialize the app.';
          _hasError = true;
          _progress = 0;
        });
      }
    }
  }

  void _proceedToApp() {
    if (!mounted) return;

    final role = widget.user['role']?.toString();

    Widget nextScreen;
    if (role == 'customer') {
      nextScreen = CustomerSelfOrderScreen(
        customerName: widget.user['name'] ?? 'Customer',
        userId: widget.user['user_id'] ?? 1,
        partnerId: widget.user['partner_id'],
      );
    } else if (role == 'cashier' || role == 'admin') {
      nextScreen = const SizedBox.shrink();
    } else {
      nextScreen = const LoginScreen();
    }

    if (role == 'cashier') {
      _goCashierFlow();
      return;
    }
    if (role == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PinScreen(cachedUser: widget.user)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  Future<void> _goCashierFlow() async {
    final api = ApiService();
    final mustPrompt = await api.shouldPromptPosIdentityForThisSession();
    final posName = await api.getCachedPosName();

    if (!mounted) return;
    // Ask on every cashier login (but not on app resume).
    if (mustPrompt || posName == null || posName.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PosIdentityScreen(user: widget.user)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PinScreen(cachedUser: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Same base as PIN: solid navy. No frosted box — pattern + watermark
    // from [PinStyleBackground] stay visually consistent.
    return Scaffold(
      backgroundColor: kCoffeeBrandNavy,
      body: PinStyleBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LaDolce',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Refreshing menus, tables, and sales data for this device',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_hasError) ...[
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.orange.shade300,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _initializeApp,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: kCoffeeBrandNavy,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Return to Login',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Determinate bar — [syncAllData] reports step labels + 0..1
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            kCoffeeGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
