import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/push_notifications_service.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../main.dart';
import '../theme/ld.dart';
import '../utils/responsive_layout.dart';
import 'loading_screen.dart';
import 'privacy_policy_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool showStaffRoles;
  const RegisterScreen({super.key, this.showStaffRoles = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  String _phoneE164 = '';
  bool _isAccepted = false;
  late TapGestureRecognizer _privacyPolicyRecognizer;

  String _selectedRole = 'customer'; // Default role
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _isLoadingBranches = false;
  List<Map<String, dynamic>> _branches = const [];
  int? _selectedBranchId;

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  String _otpError = '';

  @override
  void initState() {
    super.initState();
    _maybeLoadBranches();
    _privacyPolicyRecognizer = TapGestureRecognizer()
      ..onTap = _openPrivacyPolicy;
  }

  Future<void> _maybeLoadBranches() async {
    if (_selectedRole != 'cashier' && _selectedRole != 'rider') return;
    setState(() => _isLoadingBranches = true);
    try {
      final branches = await _apiService.fetchBranchesPublic();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        if (_selectedBranchId == null && branches.isNotEmpty) {
          final id = (branches.first['id'] is int)
              ? branches.first['id'] as int
              : int.tryParse('${branches.first['id']}');
          _selectedBranchId = id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _branches = const []);
    } finally {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  Future<bool> _sendOtp(String phone) async {
    // Resolved before the await: after it, this State may be unmounted and
    // looking either up off `context` would throw.
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _apiService.sendOtp(phone);
      if (res['status'] == 'success') {
        return true;
      }

      String errorMsg =
          res['message'] ?? l10n?.failedToSendOtp ?? 'Failed to send OTP';
      if (res['wait_seconds'] != null) {
        final totalSeconds = (res['wait_seconds'] as num).toInt();
        final duration = Duration(seconds: totalSeconds);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final seconds = duration.inSeconds % 60;
        String timeStr = '';
        if (hours > 0) timeStr += '${hours}h ';
        if (minutes > 0 || hours > 0) timeStr += '${minutes}m ';
        timeStr += '${seconds}s';
        errorMsg =
            l10n?.tooManyOtpRequests(timeStr) ??
            'Too many OTP requests. Please wait $timeStr before resending.';
      }

      messenger.showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Ld.warning),
      );
      return false;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.failedToSendOtpError(e.toString()) ??
                'Failed to send OTP: ${e.toString()}',
          ),
          backgroundColor: Ld.danger,
        ),
      );
      return false;
    }
  }

  void _showOtpDialog(String telbizPhone) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)?.otpVerification ??
                                'OTP Verification',
                            style: Ld.title(20),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Ld.muted,
                          ),
                          onPressed: _isVerifyingOtp || _isSendingOtp
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)?.otpSentTo(telbizPhone) ??
                          'We have sent a 6-digit OTP to your phone number:\n+856 $telbizPhone',
                      style: const TextStyle(
                        color: Ld.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: Ld.navy,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: Ld.faint,
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Ld.line,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Ld.line,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Ld.navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.length == 6) {
                          setDialogState(() {
                            _otpError = '';
                          });
                        }
                      },
                    ),
                    if (_otpError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _otpError,
                        style: const TextStyle(
                          color: Ld.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isVerifyingOtp || _isSendingOtp
                            ? null
                            : () async {
                                // Resolved up front; the dialog is popped
                                // mid-flow, which invalidates its context.
                                final l10n = AppLocalizations.of(context);
                                final messenger = ScaffoldMessenger.of(
                                  context,
                                );
                                final enteredCode = otpController.text.trim();
                                if (enteredCode.length != 6) {
                                  setDialogState(() {
                                    _otpError =
                                        l10n?.pleaseEnterSixDigitCode ??
                                        'Please enter a 6-digit code';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  _isVerifyingOtp = true;
                                  _otpError = '';
                                });

                                try {
                                  final response = await _apiService
                                      .registerUser(
                                        name: _nameController.text,
                                        login: _loginController.text,
                                        password: _passwordController.text,
                                        role: _selectedRole,
                                        phone: _phoneE164.trim().isNotEmpty
                                            ? _phoneE164.trim()
                                            : null,
                                        branchId:
                                            (_selectedRole == 'cashier' ||
                                                _selectedRole == 'rider')
                                            ? _selectedBranchId
                                            : null,
                                        otpCode: enteredCode,
                                      );

                                  if (!mounted) return;

                                  Navigator.pop(context); // Close OTP Dialog

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        response['message'] ??
                                            l10n?.registrationSuccessful ??
                                            'Registration successful',
                                      ),
                                      backgroundColor: Ld.success,
                                    ),
                                  );
                                  Navigator.pop(
                                    context,
                                  ); // Pop back to login screen
                                } catch (e) {
                                  setDialogState(() {
                                    _otpError =
                                        l10n?.registrationFailed(e.toString()) ??
                                        'Registration Failed: ${e.toString()}';
                                  });
                                } finally {
                                  setDialogState(() {
                                    _isVerifyingOtp = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Ld.navy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isVerifyingOtp
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(
                                _sentence(AppLocalizations.of(context)?.verifyAndRegister ??
                                    'Verify & register'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _isVerifyingOtp || _isSendingOtp
                            ? null
                            : () async {
                                setDialogState(() {
                                  _isSendingOtp = true;
                                  _otpError = '';
                                });
                                final ok = await _sendOtp(telbizPhone);
                                setDialogState(() {
                                  _isSendingOtp = false;
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.otpResentSuccessfully ??
                                              'OTP code resent successfully!',
                                        ),
                                        backgroundColor: Ld.success,
                                      ),
                                    );
                                  }
                                });
                              },
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Ld.navy,
                                ),
                              )
                            : Text(
                                AppLocalizations.of(context)?.resendCode ??
                                    'Resend Code',
                                style: TextStyle(
                                  color: Ld.navy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _otpError = '';
      _isSendingOtp = false;
      _isVerifyingOtp = false;
    });
  }

  void _registerDirect() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.registerUser(
        name: _nameController.text,
        login: _loginController.text,
        password: _passwordController.text,
        role: _selectedRole,
        phone: _phoneE164.trim().isNotEmpty ? _phoneE164.trim() : null,
        branchId: (_selectedRole == 'cashier' || _selectedRole == 'rider')
            ? _selectedBranchId
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ??
                AppLocalizations.of(context)?.registrationSuccessful ??
                'Registration successful',
          ),
          backgroundColor: Ld.success,
        ),
      );

      Navigator.pop(context); // Go back to login screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.registrationFailed(e.toString()) ??
                'Registration Failed: ${e.toString()}',
          ),
          backgroundColor: Ld.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Extract national phone number without country code
    String telbizPhone = _phoneE164;
    if (telbizPhone.startsWith('+856')) {
      telbizPhone = telbizPhone.substring(4);
    } else if (telbizPhone.startsWith('856')) {
      telbizPhone = telbizPhone.substring(3);
    }
    telbizPhone = telbizPhone.trim();

    // Enforce OTP for customer registration or when a valid Lao mobile number is provided
    if (_selectedRole == 'customer' ||
        telbizPhone.startsWith('20') ||
        telbizPhone.startsWith('30')) {
      setState(() => _isLoading = true);
      final ok = await _sendOtp(telbizPhone);
      setState(() => _isLoading = false);

      if (ok) {
        _showOtpDialog(telbizPhone);
      }
    } else {
      _registerDirect();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _privacyPolicyRecognizer.dispose();
    super.dispose();
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _continueWithGoogle() async {
    if ((_selectedRole == 'cashier' || _selectedRole == 'rider') &&
        (_selectedBranchId == null || _selectedBranchId! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.selectBranchBeforeGoogle ??
                'Please select a branch before Google registration',
          ),
          backgroundColor: Ld.danger,
        ),
      );
      return;
    }
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

      await _apiService.registerUser(
        name: name,
        login: googleLogin,
        password: uid,
        role: _selectedRole,
        phone: _phoneE164.trim().isNotEmpty ? _phoneE164.trim() : null,
        branchId: (_selectedRole == 'cashier' || _selectedRole == 'rider')
            ? _selectedBranchId
            : null,
        authProvider: 'google',
      );

      final response = await _apiService.loginUser(
        googleLogin,
        uid,
        authProvider: 'google',
      );
      final role = response['role']?.toString();
      if (role == 'cashier' ||
          role == 'customer' ||
          role == 'admin' ||
          role == 'rider') {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        try {
          await PushNotificationsService.refreshBackendRegistration();
        } catch (_) {}
        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoadingScreen(user: response)),
          (route) => false,
        );
      } else {
        throw Exception('Unknown role from server');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
                  context,
                )?.googleRegistrationFailed(e.toString()) ??
                'Google Registration Failed: ${e.toString()}',
          ),
          backgroundColor: Ld.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _googleOdooLogin(String uid) {
    return 'g${uid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
  }

  /// "REGISTER" → "Register": some English labels are upper case in the
  /// strings; the design uses sentence case. Lao text is left as it is.
  static String _sentence(String s) {
    if (s.length < 2 || s != s.toUpperCase() || s == s.toLowerCase()) return s;
    return s[0] + s.substring(1).toLowerCase();
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
              constraints: const BoxConstraints(minWidth: 46, minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
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
        borderRadius: BorderRadius.circular(22),
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

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Ld.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.createAccountTitle ?? 'Create Account',
        subtitle: l10n?.joinLaDolce ?? 'Join LaDolce and start ordering',
        leading: LdNavIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        // EN / Lao switcher, mirroring the login screen so the language
        // choice carries into registration.
        actions: [_languageToggle(context)],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.pageHorizontalPadding(context).clamp(12.0, 32.0),
            16,
            ResponsiveLayout.pageHorizontalPadding(context).clamp(12.0, 32.0),
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LdSection(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            style: Ld.body,
                            decoration: _inputDecoration(
                              l10n?.fullName ?? 'Full Name',
                              Icons.badge_outlined,
                            ),
                            validator: (value) => value!.isEmpty
                                ? (l10n?.pleaseEnterName ?? 'Please enter name')
                                : null,
                          ),
                          const SizedBox(height: 14),
                          IntlPhoneField(
                            initialCountryCode: 'LA', // Laos (+856)
                            disableLengthCheck: true,
                            style: Ld.body,
                            decoration: _inputDecoration(
                              _selectedRole == 'customer'
                                  ? (l10n?.phoneRequiredCustomers ??
                                      'Phone Number (Required for Customers)')
                                  : (l10n?.phoneOptional ?? 'Phone Number (Optional)'),
                              Icons.phone_outlined,
                            ),
                            onChanged: (phone) {
                              _phoneE164 = phone.completeNumber;
                            },
                            validator: (phone) {
                              final v = phone?.completeNumber.trim() ?? '';
                              if (_selectedRole == 'customer' && v.isEmpty) {
                                return l10n?.phoneRequiredForCustomers ??
                                    'Phone number is required for customers';
                              }
                              if (v.isNotEmpty) {
                                final numberOnly = phone?.number ?? '';
                                if (numberOnly.length != 10 ||
                                    !numberOnly.startsWith('20')) {
                                  return l10n?.phoneMustBe10Digits ??
                                      'Phone must be 10 digits starting with 20';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _loginController,
                            style: Ld.body,
                            decoration: _inputDecoration(
                              l10n?.emailOrLogin ?? 'Email / Login',
                              Icons.email_outlined,
                            ),
                            validator: (value) => value!.isEmpty
                                ? (l10n?.pleaseEnterLoginEmail ??
                                    'Please enter login/email')
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: Ld.body,
                            decoration: _inputDecoration(
                              l10n?.password ?? 'Password',
                              Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Ld.muted,
                                ),
                              ),
                            ),
                            validator: (value) => value!.isEmpty
                                ? (l10n?.pleaseEnterPassword ??
                                    'Please enter password')
                                : null,
                          ),
                        ],
                      ),
                    ),
                    if (widget.showStaffRoles ||
                        _selectedRole == 'cashier' ||
                        _selectedRole == 'rider') ...[
                      const SizedBox(height: 12),
                      LdSection(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.showStaffRoles) ...[
                              _sectionLabel(l10n?.role ?? 'Role'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  LdChoiceChip(
                                    label: l10n?.roleCustomer ?? 'Customer',
                                    selected: _selectedRole == 'customer',
                                    onTap: () => setState(() {
                                      _selectedRole = 'customer';
                                      _branches = const [];
                                      _selectedBranchId = null;
                                    }),
                                  ),
                                  LdChoiceChip(
                                    label: l10n?.roleCashier ?? 'Cashier',
                                    selected: _selectedRole == 'cashier',
                                    onTap: () async {
                                      setState(() => _selectedRole = 'cashier');
                                      await _maybeLoadBranches();
                                    },
                                  ),
                                  LdChoiceChip(
                                    label: l10n?.roleRider ?? 'Rider',
                                    selected: _selectedRole == 'rider',
                                    onTap: () async {
                                      setState(() => _selectedRole = 'rider');
                                      await _maybeLoadBranches();
                                    },
                                  ),
                                ],
                              ),
                            ], // end showStaffRoles
                            if (_selectedRole == 'cashier' ||
                                _selectedRole == 'rider') ...[
                              if (widget.showStaffRoles) const SizedBox(height: 16),
                              _sectionLabel(l10n?.branch ?? 'Branch'),
                              if (_isLoadingBranches)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Ld.navy,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                DropdownButtonFormField<int>(
                                  value: _selectedBranchId,
                                  isExpanded: true,
                                  items: _branches.map((b) {
                                    final id = (b['id'] is int)
                                        ? b['id'] as int
                                        : int.tryParse('${b['id']}') ?? 0;
                                    final name = (b['name'] ?? '').toString();
                                    final code = (b['code'] ?? '')
                                        .toString()
                                        .trim();
                                    final label = code.isNotEmpty
                                        ? '$name ($code)'
                                        : name;
                                    return DropdownMenuItem<int>(
                                      value: id,
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _isLoading
                                      ? null
                                      : (v) =>
                                            setState(() => _selectedBranchId = v),
                                  decoration: _inputDecoration(
                                    l10n?.selectBranchHint ?? 'Select branch',
                                    Icons.account_tree_outlined,
                                  ),
                                  validator: (v) {
                                    if (_selectedRole != 'cashier' &&
                                        _selectedRole != 'rider')
                                      return null;
                                    if (v == null || v <= 0) {
                                      return l10n?.pleaseSelectBranch ??
                                          'Please select a branch';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          activeColor: Ld.navy,
                          checkColor: Colors.white,
                          side: const BorderSide(color: Ld.muted, width: 1.5),
                          onChanged: (value) {
                            setState(() {
                              _isAccepted = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: RichText(
                            textScaler: MediaQuery.textScalerOf(context),
                            text: TextSpan(
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Ld.muted,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                              children: [
                                TextSpan(
                                  text: l10n?.agreeToTerms ??
                                      'I agree to the Terms of Service and ',
                                ),
                                TextSpan(
                                  text: l10n?.privacyPolicy ?? 'Privacy Policy',
                                  style: const TextStyle(
                                    color: Ld.navy,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: _privacyPolicyRecognizer,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_isAccepted)
                            ? null
                            : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Ld.navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Ld.lineSoft,
                          disabledForegroundColor: Ld.faint,
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
                                  color: Ld.navy,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(
                                _sentence(l10n?.registerButton ?? 'Register'),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Ld.r),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: Ld.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(Ld.line),
      enabledBorder: border(Ld.line),
      focusedBorder: border(Ld.navy, 1.5),
      errorBorder: border(Ld.danger),
      focusedErrorBorder: border(Ld.danger, 1.5),
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
