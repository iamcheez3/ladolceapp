import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/api_service.dart';
import 'customer_self_order_screen.dart';
import 'pin_screen.dart';
import 'login_screen.dart';

class LoadingScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const LoadingScreen({super.key, required this.user});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _statusMessage = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _statusMessage = 'Downloading data...';
      _hasError = false;
    });

    try {
      // Attempt to sync all data and cache it
      await ApiService().syncAllData();
      _proceedToApp();
    } catch (e) {
      // If we are offline or syncing failed, check if we have the minimum cache to run
      final hasCache = await ApiService().hasBasicCache();
      if (hasCache) {
        developer.log(
          '[LoadingScreen] Sync failed, but we have offline cache. Proceeding.',
          name: 'LoadingScreen',
        );
        _proceedToApp();
      } else {
        setState(() {
          _statusMessage = 'Network error and no offline cache available.\nPlease connect to the internet to initialize the app.';
          _hasError = true;
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
    } else if (role == 'cashier') {
      nextScreen = PinScreen(cachedUser: widget.user);
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Standard LaDolce App brand background
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1565), // Brand navy
              Color(0xFF070B36),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Placeholder - Falls back automatically if missing
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/images/ladolce_bear_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, trace) => const Icon(
                    Icons.pets,
                    size: 60,
                    color: Color(0xFF0D1565),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'LaDolce',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              
              const SizedBox(height: 48),

              if (_hasError) ...[
                const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initializeApp,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D1565),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('Return to Login', style: TextStyle(color: Colors.white54)),
                )
              ] else ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
