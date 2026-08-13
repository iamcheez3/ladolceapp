import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/push_notifications_service.dart';
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
  static const Color _brandNavy = Color(0xFF001460);
  static const Color _brandNavy2 = Color(0xFF142B8C);
  static const Color _brandSurface = Color(0xFFF6F7FB);

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
    try {
      final res = await _apiService.sendOtp(phone);
      if (res['status'] == 'success') {
        return true;
      }

      String errorMsg = res['message'] ?? 'Failed to send OTP';
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
            'Too many OTP requests. Please wait $timeStr before resending.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange),
      );
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP: ${e.toString()}'),
          backgroundColor: Colors.red,
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
              backgroundColor: _brandSurface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'OTP Verification',
                          style: TextStyle(
                            color: _brandNavy,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: _isVerifyingOtp || _isSendingOtp
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We have sent a 6-digit OTP to your phone number:\n+856 $telbizPhone',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
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
                        color: _brandNavy,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: const Color(0xFF64748B).withOpacity(0.3),
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                          color: Colors.red,
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
                                final enteredCode = otpController.text.trim();
                                if (enteredCode.length != 6) {
                                  setDialogState(() {
                                    _otpError = 'Please enter a 6-digit code';
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

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        response['message'] ??
                                            'Registration successful',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.pop(
                                    context,
                                  ); // Pop back to login screen
                                } catch (e) {
                                  setDialogState(() {
                                    _otpError =
                                        'Registration Failed: ${e.toString()}';
                                  });
                                } finally {
                                  setDialogState(() {
                                    _isVerifyingOtp = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
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
                            : const Text(
                                'VERIFY & REGISTER',
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
                                      const SnackBar(
                                        content: Text(
                                          'OTP code resent successfully!',
                                        ),
                                        backgroundColor: Colors.green,
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
                                  color: _brandNavy,
                                ),
                              )
                            : const Text(
                                'Resend Code',
                                style: TextStyle(
                                  color: _brandNavy,
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
          content: Text(response['message'] ?? 'Registration successful'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context); // Go back to login screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
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
        const SnackBar(
          content: Text('Please select a branch before Google registration'),
          backgroundColor: Colors.red,
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
          content: Text('Google Registration Failed: ${e.toString()}'),
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
              padding: ResponsiveLayout.scrollablePaddingWithKeyboard(
                context,
                top: 20,
                horizontal: ResponsiveLayout.pageHorizontalPadding(context),
                bottomExtra: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
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
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                              color: _brandNavy,
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: _brandNavy,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/ladolce_bear_logo.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) {
                                    return const Icon(
                                      Icons.pets_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _brandNavy,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Join LaDolce and start ordering',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration(
                              'Full Name',
                              Icons.badge_outlined,
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter name' : null,
                          ),
                          const SizedBox(height: 12),
                          IntlPhoneField(
                            initialCountryCode: 'LA', // Laos (+856)
                            disableLengthCheck: true,
                            decoration: _inputDecoration(
                              _selectedRole == 'customer'
                                  ? 'Phone Number (Required for Customers)'
                                  : 'Phone Number (Optional)',
                              Icons.phone_outlined,
                            ),
                            onChanged: (phone) {
                              _phoneE164 = phone.completeNumber;
                            },
                            validator: (phone) {
                              final v = phone?.completeNumber.trim() ?? '';
                              if (_selectedRole == 'customer' && v.isEmpty) {
                                return 'Phone number is required for customers';
                              }
                              if (v.isNotEmpty) {
                                final numberOnly = phone?.number ?? '';
                                if (numberOnly.length != 10 ||
                                    !numberOnly.startsWith('20')) {
                                  return 'Phone must be 10 digits starting with 20';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _loginController,
                            decoration: _inputDecoration(
                              'Email / Login',
                              Icons.email_outlined,
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter login/email'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration:
                                _inputDecoration(
                                  'Password',
                                  Icons.lock_outline,
                                ).copyWith(
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
                                ),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter password' : null,
                          ),
                          const SizedBox(height: 16),
                          if (widget.showStaffRoles) ...[
                            const Text(
                              'Role',
                              style: TextStyle(
                                color: _brandNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              children: [
                                ChoiceChip(
                                  label: const Text('Customer'),
                                  selected: _selectedRole == 'customer',
                                  selectedColor: _brandNavy,
                                  labelStyle: TextStyle(
                                    color: _selectedRole == 'customer'
                                        ? Colors.white
                                        : _brandNavy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFDCE5FF),
                                  ),
                                  onSelected: (_) => setState(() {
                                    _selectedRole = 'customer';
                                    _branches = const [];
                                    _selectedBranchId = null;
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text('Cashier'),
                                  selected: _selectedRole == 'cashier',
                                  selectedColor: _brandNavy,
                                  labelStyle: TextStyle(
                                    color: _selectedRole == 'cashier'
                                        ? Colors.white
                                        : _brandNavy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFDCE5FF),
                                  ),
                                  onSelected: (_) async {
                                    setState(() => _selectedRole = 'cashier');
                                    await _maybeLoadBranches();
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Rider'),
                                  selected: _selectedRole == 'rider',
                                  selectedColor: _brandNavy,
                                  labelStyle: TextStyle(
                                    color: _selectedRole == 'rider'
                                        ? Colors.white
                                        : _brandNavy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFDCE5FF),
                                  ),
                                  onSelected: (_) async {
                                    setState(() => _selectedRole = 'rider');
                                    await _maybeLoadBranches();
                                  },
                                ),
                              ],
                            ),
                          ], // end showStaffRoles
                          if (_selectedRole == 'cashier' ||
                              _selectedRole == 'rider') ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Branch',
                              style: TextStyle(
                                color: _brandNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingBranches)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  ),
                                ),
                              )
                            else
                              DropdownButtonFormField<int>(
                                value: _selectedBranchId,
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
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (v) =>
                                          setState(() => _selectedBranchId = v),
                                decoration: _inputDecoration(
                                  'Select branch',
                                  Icons.account_tree_outlined,
                                ),
                                validator: (v) {
                                  if (_selectedRole != 'cashier' &&
                                      _selectedRole != 'rider')
                                    return null;
                                  if (v == null || v <= 0) {
                                    return 'Please select a branch';
                                  }
                                  return null;
                                },
                              ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: _isAccepted,
                                activeColor: _brandNavy,
                                checkColor: Colors.white,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                onChanged: (value) {
                                  setState(() {
                                    _isAccepted = value ?? false;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF64748B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    children: [
                                      const TextSpan(
                                        text:
                                            'I agree to the Terms of Service and ',
                                      ),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: const TextStyle(
                                          color: _brandNavy,
                                          fontWeight: FontWeight.bold,
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
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (_isLoading || !_isAccepted)
                                  ? null
                                  : _register,
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
                                      'REGISTER',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                          if (FirebaseAuthService.isGoogleAuthAvailable) ...[
                            const SizedBox(height: 12),
                            _GoogleAuthButton(
                              label: 'Continue with Google',
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
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: _brandNavy),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brandNavy, width: 1.5),
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
