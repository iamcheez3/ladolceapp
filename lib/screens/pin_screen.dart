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

  void _onKeyPress(String value) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += value;
        _hasError = false;
      });

      if (_pin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _hasError = false;
      });
    }
  }

  void _verifyPin() {
    final expectedPin = widget.cachedUser['pos_pin'] ?? '';
    
    if (_pin == expectedPin || expectedPin.isEmpty) {
      // If PIN matches or no PIN was set in backend, allow entry
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
    } else {
      // Incorrect PIN
      setState(() {
        _hasError = true;
        _pin = '';
      });
    }
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
            Positioned.fill(
              child: CustomPaint(
                painter: _CoffeeLuxuryPatternPainter(
                  smokeColor: Colors.white.withOpacity(0.06),
                  medallionColor: _coffeeGold.withOpacity(0.09),
                  coffeeColor: _coffeeBrown.withOpacity(0.09),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.07,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFC6A15B),
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
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        label: const Text('Switch User', style: TextStyle(color: Colors.white70)),
                      )
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar — user profile image
                          _buildUserAvatar(),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome back, ${widget.cachedUser['name'] ?? 'Cashier'}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter PIN to unlock',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 48),

                          // PIN Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _pinLength,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index < _pin.length ? _coffeeGold : Colors.white.withOpacity(0.2),
                                  border: Border.all(
                                    color: _hasError ? Colors.red : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          if (_hasError)
                            const Padding(
                              padding: EdgeInsets.only(top: 16.0),
                              child: Text('Incorrect PIN', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            )
                          else
                            const SizedBox(height: 32),

                          const SizedBox(height: 32),

                          // Numpad
                          _buildNumpad(),
                        ],
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
      width: 84,
      height: 84,
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
                  fontSize: 34,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _numButton('1'),
            _numButton('2'),
            _numButton('3'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _numButton('4'),
            _numButton('5'),
            _numButton('6'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _numButton('7'),
            _numButton('8'),
            _numButton('9'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72, height: 72), // Spacer
            _numButton('0'),
            _actionButton(Icons.backspace_outlined, _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _numButton(String number) {
    return InkWell(
      onTap: () => _onKeyPress(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _coffeeBrown.withOpacity(0.35),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 32),
        ),
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
        ..cubicTo(size.width * 0.18, baseY - 24, size.width * 0.32, baseY + 24, size.width * 0.5, baseY)
        ..cubicTo(size.width * 0.68, baseY - 24, size.width * 0.82, baseY + 24, size.width + 20, baseY - 4);
      canvas.drawPath(path, smokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoffeeLuxuryPatternPainter oldDelegate) {
    return smokeColor != oldDelegate.smokeColor ||
        medallionColor != oldDelegate.medallionColor ||
        coffeeColor != oldDelegate.coffeeColor;
  }
}
