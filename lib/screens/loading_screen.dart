import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'dart:developer' as developer;
import '../services/api_service.dart';
import '../theme/ld.dart';
import '../utils/responsive_layout.dart';
import 'customer_self_order_screen.dart';
import 'pin_screen.dart';
import 'login_screen.dart';
import 'pos_identity_screen.dart';
import 'rider_screen.dart';

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

    final api = ApiService();

    // If we already have cache, go straight to the app and sync in the background.
    // This eliminates the 4-5 second wait for returning users.
    final hasCache = await api.hasBasicCache();
    if (hasCache) {
      developer.log(
        '[LoadingScreen] Cache found — navigating immediately, syncing in background.',
        name: 'LoadingScreen',
      );
      _proceedToApp();
      // Fire-and-forget background sync (updates cache silently, no onProgress).
      api.syncAllData().catchError((_) {});
      return;
    }

    // First-time setup (no cache) — show progress bar and wait for full sync.
    try {
      await api.syncAllData(
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
      final stillHasCache = await api.hasBasicCache();
      if (stillHasCache) {
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
        customerName: widget.user['name'] ?? (AppLocalizations.of(context)?.roleCustomer ?? 'Customer'),
        userId: widget.user['user_id'] ?? 1,
        partnerId: widget.user['partner_id'],
      );
    } else if (role == 'cashier' || role == 'admin') {
      nextScreen = const SizedBox.shrink();
    } else {
      nextScreen = const LoginScreen();
    }

    if (role == 'rider') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RiderScreen(
            riderName: widget.user['name'] ?? (AppLocalizations.of(context)?.roleRider ?? 'Rider'),
            riderId: widget.user['user_id'] ?? 1,
          ),
        ),
      );
      return;
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
    final l10n = AppLocalizations.of(context);
    final short = MediaQuery.sizeOf(context).height < 700;
    return Scaffold(
      backgroundColor: Ld.navy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final hPad = ResponsiveLayout.pageHorizontalPadding(context).clamp(
              20.0,
              44.0,
            );
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (viewport.maxHeight - 44).clamp(0.0, double.infinity)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/ladolce_bear_logo.png',
                          width: short ? 72 : 96,
                          height: short ? 72 : 96,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.pets_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'LaDolce',
                          style: Ld.title(short ? 30 : 38, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n?.refreshingMenusTablesAndSalesData ??
                              'Refreshing menus, tables, and sales data for this device',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Ld.onNavyMuted,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: short ? 24 : 36),
                        if (_hasError)
                          _buildErrorCard(context)
                        else ...[
                          // Determinate bar — [syncAllData] reports step labels + 0..1
                          Semantics(
                            value: '${(_progress * 100).round()}%',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _progress,
                                minHeight: 8,
                                backgroundColor: Ld.navyRaised,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Ld.gold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _statusMessage,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(_progress * 100).round()}%',
                                style: Ld.price(15, color: Ld.gold),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      decoration: Ld.card(radius: Ld.rXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: LdIconTile(
              Icons.wifi_off_rounded,
              size: 56,
              background: Ld.warningWash,
              color: Ld.warning,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: Ld.body,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _initializeApp,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n?.retry ?? 'Retry'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Ld.navy,
                elevation: 0,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Ld.rMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Ld.navy,
              minimumSize: const Size(0, 48),
            ),
            child: Text(
              l10n?.returnToLogin ?? 'Return to Login',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
