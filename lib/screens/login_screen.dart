import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../main.dart';
import 'register_screen.dart';
import 'loading_screen.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/push_notifications_service.dart';
import '../theme/ld.dart';

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

  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _devUnlocked = false;
  int _logoTapCount = 0;

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
            backgroundColor: Ld.navy,
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
        _currentBaseUrl = override ?? '';
        _currentDbName = dbOverride;
      });
    }
  }

  void _onLogoTap() {
    _logoTapCount++;
    if (_logoTapCount >= 10) {
      _logoTapCount = 0;
      setState(() => _devUnlocked = !_devUnlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _devUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_devUnlocked ? 'Staff mode unlocked' : 'Staff mode hidden'),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Ld.navy,
        ),
      );
      if (_devUnlocked && kShowDevTools) _loadCurrentUrl();
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
                color: Ld.navy,
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
                  style: TextStyle(fontSize: 12, color: Ld.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'http://your-server:8069/api',
                    filled: true,
                    fillColor: Ld.ground,
                    prefixIcon: const Icon(
                      Icons.link_rounded,
                      color: Ld.navy,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Ld.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Ld.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Ld.navy,
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
                    fillColor: Ld.ground,
                    prefixIcon: const Icon(
                      Icons.storage_rounded,
                      color: Ld.navy,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Ld.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Ld.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Ld.navy,
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
                    _currentBaseUrl = '';
                    _currentDbName = '';
                  });
                }
                navigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dev overrides reset to default URL'),
                    backgroundColor: Ld.navy,
                  ),
                );
              },
              child: const Text('Reset', style: TextStyle(color: Colors.red)),
            ),
            // Save
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Ld.navy,
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
                    backgroundColor: Ld.navy,
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

  /// Completes a successful login response: caches data and navigates.
  Future<void> _onLoginSuccess(Map<String, dynamic> response) async {
    final navigator = Navigator.of(context);
    try {
      await PushNotificationsService.refreshBackendRegistration();
    } catch (_) {}
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => LoadingScreen(user: response)),
    );
  }

  /// Shows a premium dialog when the backend reports the account is already
  /// active on another device. Returns `true` if the user chose to continue
  /// (force takeover), `false` if they cancelled.
  Future<bool> _showDeviceConflictDialog(Map<String, dynamic> conflict) async {
    final platform = (conflict['active_platform'] ?? '').toString().toLowerCase();
    final rawDeviceId = (conflict['active_device_id'] ?? '').toString();
    final maskedId = rawDeviceId.length > 8
        ? '${rawDeviceId.substring(0, 6)}…'
        : rawDeviceId;
    final l10n = AppLocalizations.of(context);
    final platformLabel = platform == 'ios'
        ? (l10n?.deviceIphone ?? 'iPhone / iPad')
        : (l10n?.deviceAndroid ?? 'Android device');
    final platformIcon = platform == 'ios'
        ? Icons.phone_iphone_rounded
        : Icons.phone_android_rounded;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rXl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LdIconTile(Icons.devices_rounded, size: 60),
                const SizedBox(height: 16),
                Text(
                  l10n?.alreadySignedIn ?? 'Already signed in',
                  textAlign: TextAlign.center,
                  style: Ld.title(20),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.accountActiveOtherDevice ??
                      'Your account is currently active on another device.',
                  textAlign: TextAlign.center,
                  style: Ld.label,
                ),
                const SizedBox(height: 16),
                // Device info pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: Ld.card(radius: Ld.r, color: Ld.ground),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(platformIcon, size: 22, color: Ld.navy),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              platformLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Ld.ink,
                              ),
                            ),
                            if (maskedId.isNotEmpty)
                              Text(
                                l10n?.deviceIdLabel(maskedId) ?? 'ID: $maskedId',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Ld.muted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.info_outline_rounded, size: 18, color: Ld.warning),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.continueSignsOutOther ??
                            'Continuing will sign out that device.',
                        style: Ld.small,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: Ld.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Ld.r),
                          ),
                          side: const BorderSide(color: Ld.line),
                        ),
                        child: Text(
                          l10n?.cancel ?? 'Cancel',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Ld.navy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Ld.r),
                          ),
                        ),
                        child: Text(
                          l10n?.continueLabel ?? 'Continue',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.loginUser(
        _loginController.text,
        _passwordController.text,
      );

      // Handle single-device conflict: show dialog and optionally force takeover.
      if (response['status'] == 'conflict') {
        if (!mounted) return;
        final shouldContinue = await _showDeviceConflictDialog(response);
        if (!mounted) return;
        if (!shouldContinue) return;
        // Re-submit with force=true to take over the session.
        setState(() => _isLoading = true);
        final forced = await _apiService.loginUser(
          _loginController.text,
          _passwordController.text,
          force: true,
        );
        final role = forced['role']?.toString();
        if (role == 'cashier' || role == 'customer' || role == 'admin' || role == 'rider') {
          if (!mounted) return;
          await _onLoginSuccess(forced);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.unknownRoleFromServer ??
                    'Unknown role from server',
              ),
            ),
          );
        }
        return;
      }

      final role = response['role']?.toString();
      if (role == 'cashier' || role == 'customer' || role == 'admin' || role == 'rider') {
        if (!mounted) return;
        await _onLoginSuccess(response);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                AppLocalizations.of(context)?.unknownRoleFromServer ??
                    'Unknown role from server',
              ),
            ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Strip the "Exception: " prefix so users see a clean message
      // (e.g. "Incorrect email or password").
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
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

      // Handle single-device conflict.
      if (response['status'] == 'conflict') {
        if (!mounted) return;
        final shouldContinue = await _showDeviceConflictDialog(response);
        if (!mounted) return;
        if (!shouldContinue) return;
        setState(() => _isLoading = true);
        response = await _apiService.loginUser(
          googleLogin,
          uid,
          authProvider: 'google',
          force: true,
        );
      }

      final role = response['role']?.toString();
      if (role == 'cashier' || role == 'customer' || role == 'admin' || role == 'rider') {
        if (!mounted) return;
        await _onLoginSuccess(response);
      } else {
        throw Exception('Unknown role from server');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.googleLoginFailed(e.toString()) ??
                'Google Login Failed: ${e.toString()}',
          ),
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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Ld.r),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: Ld.muted),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(Ld.line),
      enabledBorder: border(Ld.line),
      focusedBorder: border(Ld.navy, 1.5),
      errorBorder: border(Ld.danger),
      focusedErrorBorder: border(Ld.danger, 1.5),
    );
  }

  Widget _languageToggle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    Widget option(String label, Locale locale, bool selected) {
      return Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => PosApp.setLocale(context, locale),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Ld.navy : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Ld.navyLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option('ລາວ', const Locale('lo', ''), code == 'lo'),
          option('EN', const Locale('en', ''), code == 'en'),
        ],
      ),
    );
  }

  /// Bear, wordmark and (when set) the active dev server override under it.
  /// The bear is the hidden 10-tap staff/dev switch.
  Widget _brand(BuildContext context, {required bool compact}) {
    final logo = compact ? 72.0 : 96.0;
    Widget subtitle;
    if (kShowDevTools && _currentBaseUrl.isNotEmpty) {
      subtitle = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _currentBaseUrl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Ld.onNavyMuted,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      );
    } else if (kShowDevTools && _currentDbName.isNotEmpty) {
      subtitle = Text(
        'DB: $_currentDbName',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: Ld.onNavyMuted,
          fontFamily: 'monospace',
        ),
      );
    } else {
      subtitle = const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _onLogoTap,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              'assets/images/ladolce_bear_logo.png',
              width: logo,
              height: logo,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.pets_rounded,
                size: logo * 0.6,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            'LaDolce',
            textAlign: TextAlign.center,
            style: Ld.title(compact ? 30 : 38, color: Colors.white),
          ),
          const SizedBox(height: 6),
          subtitle,
        ],
      ),
    );
  }

  Widget _formCard(BuildContext context, {required bool tablet}) {
    final l10n = AppLocalizations.of(context);
    final loginLabel = l10n?.loginButton ?? 'LOGIN';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: tablet
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        26,
        24,
        (tablet ? 24 : 20) + (tablet ? 0 : Ld.navInset(context)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.welcomeBack ?? 'Welcome back',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ld.title(24),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginController,
              textInputAction: TextInputAction.next,
              style: Ld.body,
              decoration: _fieldDecoration(
                label: l10n?.emailOrLogin ?? 'Email / Login',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) => value!.isEmpty
                  ? (l10n?.pleaseEnterLogin ?? 'Please enter login')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: Ld.body,
              decoration: _fieldDecoration(
                label: l10n?.password ?? 'Password',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Ld.muted,
                  ),
                ),
              ),
              validator: (value) => value!.isEmpty
                  ? (l10n?.pleaseEnterPassword ?? 'Please enter password')
                  : null,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Ld.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Ld.navy.withValues(alpha: 0.75),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Ld.rMd),
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
                        loginLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (FirebaseAuthService.isGoogleAuthAvailable) ...[
              const SizedBox(height: 12),
              _GoogleAuthButton(
                label: l10n?.continueWithGoogle ?? 'Continue with Google',
                isLoading: _isLoading,
                onPressed: _continueWithGoogle,
              ),
            ],
            const SizedBox(height: 8),
            if (_devUnlocked)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(showStaffRoles: true),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: Ld.muted,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.badge_outlined, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n?.registerStaffAccount ?? 'Register Staff Account',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RegisterScreen(showStaffRoles: false),
                  ),
                );
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: Ld.navy,
              ),
              child: Text(
                l10n?.createAccount ?? 'Create a new account',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = Ld.isTablet(context);
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Scaffold(
      backgroundColor: Ld.navy,
      // ── Dev wrench button (bottom-right) ─────────────────────────────────
      floatingActionButton: (_devUnlocked && kShowDevTools)
          ? FloatingActionButton.small(
              onPressed: _showDevSettings,
              backgroundColor: Ld.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Ld.r),
                side: const BorderSide(color: Ld.navyLine),
              ),
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
      body: SafeArea(
        bottom: tablet,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _languageToggle(context),
                    ),
                  ),
                  Expanded(
                    child: Center(child: _brand(context, compact: compact)),
                  ),
                  if (tablet)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _formCard(context, tablet: true),
                      ),
                    )
                  else
                    _formCard(context, tablet: false),
                ],
              ),
            ),
          ],
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
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Ld.ink,
          side: const BorderSide(color: Ld.line),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ld.rMd),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'G',
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Ld.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
