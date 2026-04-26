import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_self_order_screen.dart';
import 'pin_screen.dart';
import 'pos_screen.dart';
import 'register_screen.dart';
import 'loading_screen.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEV TOOLS FLAG
// Set to false before uploading to the App Store / Play Store.
// When false, the wrench button is completely removed from the UI.
// ─────────────────────────────────────────────────────────────────────────────
const bool kShowDevTools = true;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _brandNavy = Color(0xFF0D1565);
  static const Color _brandNavy2 = Color(0xFF142B8C);
  static const Color _brandSurface = Color(0xFFF6F7FB);

  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // ── Dev tools state ──────────────────────────────────────────────────────
  String _currentBaseUrl = '';
  String _currentDbName = '';

  @override
  void initState() {
    super.initState();
    if (kShowDevTools) _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(ApiService.devBaseUrlKey) ?? '';
    final dbOverride = prefs.getString(ApiService.devDbNameKey) ?? '';
    if (mounted) {
      setState(() {
        _currentBaseUrl = override;
        _currentDbName = dbOverride;
      });
    }
  }

  /// Opens a small dialog to edit / clear the API base URL override.
  void _showDevSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ApiService.devBaseUrlKey) ?? '';
    final savedDb = prefs.getString(ApiService.devDbNameKey) ?? '';
    final controller = TextEditingController(text: saved);
    final dbController = TextEditingController(text: savedDb);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.construction_rounded,
                size: 20,
                color: Color(0xFF0D1565),
              ),
              SizedBox(width: 8),
              Text(
                'Dev: API Server',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Override the API base URL for this device.\n'
                'Leave empty to use the default from .env',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'http://192.168.x.x:8069/api',
                  filled: true,
                  fillColor: const Color(0xFFF6F7FB),
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF0D1565),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0D1565),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dbController,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Database (optional)',
                  hintText: 'ladolce',
                  filled: true,
                  fillColor: const Color(0xFFF6F7FB),
                  prefixIcon: const Icon(
                    Icons.storage_rounded,
                    color: Color(0xFF0D1565),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0D1565),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Clear override
            TextButton(
              onPressed: () async {
                await prefs.remove(ApiService.devBaseUrlKey);
                await prefs.remove(ApiService.devDbNameKey);
                if (mounted) {
                  setState(() {
                    _currentBaseUrl = '';
                    _currentDbName = '';
                  });
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dev overrides cleared — using .env/default'),
                    backgroundColor: Color(0xFF0D1565),
                  ),
                );
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
            // Save
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D1565),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final value = controller.text.trim();
                final dbValue = dbController.text.trim();
                if (value.isNotEmpty) {
                  await prefs.setString(ApiService.devBaseUrlKey, value);
                } else {
                  await prefs.remove(ApiService.devBaseUrlKey);
                }
                if (dbValue.isNotEmpty) {
                  await prefs.setString(ApiService.devDbNameKey, dbValue);
                } else {
                  await prefs.remove(ApiService.devDbNameKey);
                }
                if (mounted) {
                  setState(() {
                    _currentBaseUrl = value;
                    _currentDbName = dbValue;
                  });
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Saved dev settings',
                    ),
                    backgroundColor: const Color(0xFF0D1565),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ── Login ────────────────────────────────────────────────────────────────
  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.loginUser(
        _loginController.text,
        _passwordController.text,
      );

      if (response['role'] == 'cashier' || response['role'] == 'customer') {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoadingScreen(user: response)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unknown role from server')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Dev wrench button (bottom-right) ─────────────────────────────────
      floatingActionButton: kShowDevTools
          ? FloatingActionButton.small(
              onPressed: _showDevSettings,
              backgroundColor: const Color(0xFF0D1565).withOpacity(0.85),
              tooltip: 'Dev: API Settings',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.construction_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  // Red dot when an override is active
                  if (_currentBaseUrl.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_brandNavy, _brandNavy2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    color: _brandSurface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 108,
                            height: 108,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: _brandNavy,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/images/ladolce_bear_logo.png',
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return const Icon(
                                    Icons.pets_rounded,
                                    size: 52,
                                    color: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ),
                          const Text(
                            'LaDolce',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _brandNavy,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Show active URL hint under subtitle when override is set
                          if (kShowDevTools && _currentBaseUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _currentBaseUrl,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (kShowDevTools && _currentDbName.isNotEmpty)
                            Text(
                              'DB: $_currentDbName',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                                fontFamily: 'monospace',
                              ),
                            )
                          else
                            const Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _loginController,
                            decoration: InputDecoration(
                              labelText: 'Email / Login',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: _brandNavy,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCE5FF),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCE5FF),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _brandNavy,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter login' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: _brandNavy,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCE5FF),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCE5FF),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _brandNavy,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter password' : null,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandNavy,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Create a new account',
                              style: TextStyle(
                                color: _brandNavy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
