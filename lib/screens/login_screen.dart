import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../main.dart';
import 'register_screen.dart';
import 'loading_screen.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/push_notifications_service.dart';
import '../utils/responsive_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEV TOOLS FLAG
// Set to false before uploading to the App Store / Play Store.
// When false, the wrench button is completely removed from the UI.
// ─────────────────────────────────────────────────────────────────────────────
const bool kShowDevTools = true;

class LoginScreen extends StatefulWidget {
  final String? infoMessage;

  const LoginScreen({super.key, this.infoMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _brandNavy = Color(0xFF001460);
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
    final msg = widget.infoMessage?.trim();
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF001460),
          ),
        );
      });
    }
  }

  Future<void> _loadCurrentUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(ApiService.devBaseUrlKey);
    final dbOverride = prefs.getString(ApiService.devDbNameKey) ?? '';
    if (mounted) {
      setState(() {
        _currentBaseUrl =
            override ??
            'https://posteruptive-ungreasy-alethia.ngrok-free.dev/api';
        _currentDbName = dbOverride;
      });
    }
  }

  /// Opens a small dialog to edit / clear the API base URL override.
  void _showDevSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getString(ApiService.devBaseUrlKey) ??
        'https://posteruptive-ungreasy-alethia.ngrok-free.dev/api';
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
                color: Color(0xFF001460),
              ),
              SizedBox(width: 8),
              Text(
                'Dev: API Server',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Override the API base URL for this device.\n'
                  'Leave empty to use the default from .env.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Base URL',
                    hintText:
                        'https://posteruptive-ungreasy-alethia.ngrok-free.dev/api',
                    filled: true,
                    fillColor: const Color(0xFFF6F7FB),
                    prefixIcon: const Icon(
                      Icons.link_rounded,
                      color: Color(0xFF001460),
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
                        color: Color(0xFF001460),
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
                      color: Color(0xFF001460),
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
                        color: Color(0xFF001460),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Clear override
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                await prefs.remove(ApiService.devBaseUrlKey);
                await prefs.remove(ApiService.devDbNameKey);
                if (!mounted) return;
                if (mounted) {
                  setState(() {
                    _currentBaseUrl =
                        'https://posteruptive-ungreasy-alethia.ngrok-free.dev/api';
                    _currentDbName = '';
                  });
                }
                navigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dev overrides reset to default ngrok URL'),
                    backgroundColor: Color(0xFF001460),
                  ),
                );
              },
              child: const Text('Reset', style: TextStyle(color: Colors.red)),
            ),
            // Save
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001460),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final value = controller.text.trim();
                final dbValue = dbController.text.trim();
                await prefs.setString(ApiService.devBaseUrlKey, value);
                if (dbValue.isNotEmpty) {
                  await prefs.setString(ApiService.devDbNameKey, dbValue);
                } else {
                  await prefs.remove(ApiService.devDbNameKey);
                }
                if (!mounted) return;
                if (mounted) {
                  setState(() {
                    _currentBaseUrl = value.isNotEmpty ? value : '';
                    _currentDbName = dbValue;
                  });
                }
                navigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved dev settings'),
                    backgroundColor: const Color(0xFF001460),
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

      final role = response['role']?.toString();
      if (role == 'cashier' || role == 'customer' || role == 'admin' || role == 'rider') {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        try {
          await PushNotificationsService.refreshBackendRegistration();
        } catch (_) {}
        if (!mounted) return;
        navigator.pushReplacement(
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

  void _continueWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuthService.instance.signInWithGoogle();
      final user = credential.user;
      final email = user?.email?.trim().toLowerCase() ?? '';
      final uid = user?.uid ?? '';
      final googleLogin = _googleOdooLogin(uid);
      final name = (user?.displayName?.trim().isNotEmpty ?? false)
          ? user!.displayName!.trim()
          : email.split('@').first;
      if (email.isEmpty || uid.isEmpty) {
        throw Exception('Google account is missing email information.');
      }

      Map<String, dynamic> response;
      try {
        response = await _apiService.loginUser(
          googleLogin,
          uid,
          authProvider: 'google',
        );
      } catch (_) {
        await _apiService.registerUser(
          name: name,
          login: googleLogin,
          password: uid,
          role: 'customer',
          authProvider: 'google',
        );
        response = await _apiService.loginUser(
          googleLogin,
          uid,
          authProvider: 'google',
        );
      }
      final role = response['role']?.toString();
      if (role == 'cashier' || role == 'customer' || role == 'admin' || role == 'rider') {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        try {
          await PushNotificationsService.refreshBackendRegistration();
        } catch (_) {}
        if (!mounted) return;
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => LoadingScreen(user: response)),
        );
      } else {
        throw Exception('Unknown role from server');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Login Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _googleOdooLogin(String uid) {
    return 'g${uid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Dev wrench button (bottom-right) ─────────────────────────────────
      floatingActionButton: kShowDevTools
          ? FloatingActionButton.small(
              onPressed: _showDevSettings,
              backgroundColor: const Color(0xFF001460).withOpacity(0.85),
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
        color: _brandNavy,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: ResponsiveLayout.scrollablePaddingWithKeyboard(
                    context,
                    top: 20,
                    horizontal: ResponsiveLayout.pageHorizontalPadding(context),
                    bottomExtra: 20,
                  ),
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
                                width: MediaQuery.of(context).size.width < 360
                                    ? 80
                                    : 108,
                                height: MediaQuery.of(context).size.width < 360
                                    ? 80
                                    : 108,
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
                                    width:
                                        MediaQuery.of(context).size.width < 360
                                        ? 64
                                        : 88,
                                    height:
                                        MediaQuery.of(context).size.width < 360
                                        ? 64
                                        : 88,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) {
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
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    bottom: 2,
                                  ),
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
                              else if (kShowDevTools &&
                                  _currentDbName.isNotEmpty)
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
                                Text(
                                  AppLocalizations.of(context)?.welcomeBack ??
                                      'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _loginController,
                                decoration: InputDecoration(
                                  labelText:
                                      AppLocalizations.of(
                                        context,
                                      )?.emailOrLogin ??
                                      'Email / Login',
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
                                validator: (value) => value!.isEmpty
                                    ? 'Please enter login'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText:
                                      AppLocalizations.of(context)?.password ??
                                      'Password',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: _brandNavy,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
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
                                validator: (value) => value!.isEmpty
                                    ? 'Please enter password'
                                    : null,
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
                                      : Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.loginButton ??
                                              'LOGIN',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _GoogleAuthButton(
                                label: 'Continue with Google',
                                isLoading: _isLoading,
                                onPressed: _continueWithGoogle,
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
                                child: Text(
                                  AppLocalizations.of(context)?.createAccount ??
                                      'Create a new account',
                                  style: const TextStyle(
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
              Positioned(
                top: 10,
                right: 16,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          PosApp.setLocale(context, const Locale('en', '')),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Localizations.localeOf(context).languageCode == 'en'
                            ? Colors.white
                            : Colors.white60,
                      ),
                      child: const Text('EN'),
                    ),
                    const Text('|', style: TextStyle(color: Colors.white54)),
                    TextButton(
                      onPressed: () =>
                          PosApp.setLocale(context, const Locale('lo', '')),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Localizations.localeOf(context).languageCode == 'lo'
                            ? Colors.white
                            : Colors.white60,
                      ),
                      child: const Text('ລາວ'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        label: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF001460),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDCE5FF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
