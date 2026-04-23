import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'customer_self_order_screen.dart';
import 'pos_screen.dart';
import 'login_screen.dart';

class PinScreen extends StatefulWidget {
  final Map<String, dynamic> cachedUser;

  const PinScreen({Key? key, required this.cachedUser}) : super(key: key);

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  static const Color _brandNavy = Color(0xFF0D1565);
  static const Color _coffeeBrown = Color(0xFF6B4F3A);
  static const Color _coffeeGold = Color(0xFFC6A15B);

  String _pin = '';
  final int _pinLength = 4;
  bool _hasError = false;
  bool _isSubmitting = false;
  String? _firstPinEntry;

  String _normalizedCachedPin() {
    final raw = widget.cachedUser['pos_pin'];
    if (raw == null || raw == false) return '';
    return raw.toString().trim();
  }

  bool get _isSetupMode => _normalizedCachedPin().isEmpty;

  void _onKeyPress(String value) {
    if (_isSubmitting) return;
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += value;
        _hasError = false;
      });

      if (_pin.length == _pinLength) {
        _handlePinInput();
      }
    }
  }

  void _onBackspace() {
    if (_isSubmitting) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _handlePinInput() async {
    if (_isSetupMode) {
      await _setupPinFlow();
      return;
    }
    _verifyPin();
  }

  Future<void> _setupPinFlow() async {
    if (_firstPinEntry == null) {
      setState(() {
        _firstPinEntry = _pin;
        _pin = '';
        _hasError = false;
      });
      return;
    }

    if (_pin != _firstPinEntry) {
      setState(() {
        _hasError = true;
        _pin = '';
        _firstPinEntry = null;
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _hasError = false;
      });
      await ApiService().setPosPin(_pin);
      widget.cachedUser['pos_pin'] = _pin;
      if (!mounted) return;
      _goNext();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _pin = '';
        _firstPinEntry = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _verifyPin() {
    final expectedPin = _normalizedCachedPin();

    if (_pin == expectedPin) {
      _goNext();
    } else {
      setState(() {
        _hasError = true;
        _pin = '';
      });
    }
  }

  void _goNext() {
    final role = widget.cachedUser['role']?.toString();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => role == 'customer'
            ? CustomerSelfOrderScreen(
                customerName: widget.cachedUser['name'] ?? 'Customer',
                userId: widget.cachedUser['user_id'] ?? 1,
                partnerId: widget.cachedUser['partner_id'],
              )
            : PosScreen(
                cashierName: widget.cachedUser['name'] ?? 'Cashier',
                cashierId: widget.cachedUser['user_id'] ?? 1,
              ),
      ),
    );
  }

  void _logout() async {
    await ApiService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandNavy,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _CoffeeLuxuryPatternPainter(
                  smokeColor: Colors.white.withOpacity(0.06),
                  medallionColor: _coffeeGold.withOpacity(0.09),
                  coffeeColor: _coffeeBrown.withOpacity(0.09),
                ),
              ),
            ),

            // Background Logo
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.07,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        _coffeeGold,
                        BlendMode.modulate,
                      ),
                      child: Image.asset(
                        'assets/images/ladolce_bear_logo.png',
                        width: 380,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Column(
              children: [
                // Header - Switch User
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white70,
                          size: 20,
                        ),
                        label: const Text(
                          'Switch User',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.16),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildUserAvatar(),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome back, ${widget.cachedUser['name'] ?? 'Cashier'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSetupMode
                                  ? (_firstPinEntry == null
                                      ? 'Create your 4-digit PIN'
                                      : 'Confirm your new PIN')
                                  : 'Enter PIN to unlock',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(
                              height: 32,
                            ), // ลดจาก 48 เพื่อประหยัดพื้นที่
                            // PIN Indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _pinLength,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index < _pin.length
                                        ? _coffeeGold
                                        : Colors.white.withOpacity(0.2),
                                    border: Border.all(
                                      color: _hasError
                                          ? Colors.red
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Error Message Area
                            SizedBox(
                              height: 40,
                              child: _hasError
                                  ? Center(
                                      child: Text(
                                        _isSetupMode
                                            ? 'PIN mismatch or save failed'
                                            : 'Incorrect PIN',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            // Numpad
                            if (_isSubmitting)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            else
                              _buildNumpad(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    final String? base64Str = widget.cachedUser['image_base64'] as String?;
    final String initials =
        (widget.cachedUser['name'] ?? 'U').toString().trim().isEmpty
        ? 'U'
        : (widget.cachedUser['name'] as String).trim()[0].toUpperCase();

    ImageProvider? imageProvider;
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(base64Str));
      } catch (_) {
        imageProvider = null;
      }
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _coffeeBrown.withOpacity(0.35),
        border: Border.all(color: _coffeeGold.withOpacity(0.7), width: 2),
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: imageProvider == null
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _buildNumpadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildNumpadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildNumpadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 68, height: 68),
            _numButton('0'),
            _actionButton(Icons.backspace_outlined, _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _numButton(n)).toList(),
    );
  }

  Widget _numButton(String number) {
    return InkWell(
      onTap: () => _onKeyPress(number),
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _coffeeBrown.withOpacity(0.3),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 28)),
      ),
    );
  }
}

class _CoffeeLuxuryPatternPainter extends CustomPainter {
  final Color smokeColor;
  final Color medallionColor;
  final Color coffeeColor;

  _CoffeeLuxuryPatternPainter({
    required this.smokeColor,
    required this.medallionColor,
    required this.coffeeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final medallionPaint = Paint()
      ..color = medallionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final coffeeDotPaint = Paint()
      ..color = coffeeColor
      ..style = PaintingStyle.fill;

    const spacing = 170.0;
    for (double y = -50; y < size.height + spacing; y += spacing) {
      for (double x = -50; x < size.width + spacing; x += spacing) {
        final center = Offset(x, y);
        canvas.drawCircle(center, 28, medallionPaint);
        canvas.drawCircle(center, 12, medallionPaint);
        canvas.drawCircle(center.translate(30, 0), 3.2, coffeeDotPaint);
        canvas.drawCircle(center.translate(-30, 0), 3.2, coffeeDotPaint);
        canvas.drawCircle(center.translate(0, 30), 3.2, coffeeDotPaint);
        canvas.drawCircle(center.translate(0, -30), 3.2, coffeeDotPaint);
      }
    }

    final smokePaint = Paint()
      ..color = smokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    final waveCount = (size.height / 120).ceil() + 1;
    for (int i = 0; i < waveCount; i++) {
      final baseY = 80.0 + (i * 120.0);
      final path = Path()
        ..moveTo(-20, baseY)
        ..cubicTo(
          size.width * 0.18,
          baseY - 24,
          size.width * 0.32,
          baseY + 24,
          size.width * 0.5,
          baseY,
        )
        ..cubicTo(
          size.width * 0.68,
          baseY - 24,
          size.width * 0.82,
          baseY + 24,
          size.width + 20,
          baseY - 4,
        );
      canvas.drawPath(path, smokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoffeeLuxuryPatternPainter oldDelegate) =>
      false;
}
