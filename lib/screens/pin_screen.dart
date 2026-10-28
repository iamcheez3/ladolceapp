import 'dart:convert';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../theme/ld.dart';
import '../services/api_service.dart';
import 'admin_reports_screen.dart';
import 'customer_self_order_screen.dart';
import 'pos_screen.dart';
import 'rider_screen.dart';
import 'login_screen.dart';

class PinScreen extends StatefulWidget {
  final Map<String, dynamic> cachedUser;

  const PinScreen({super.key, required this.cachedUser});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
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
      final userId = widget.cachedUser['user_id'] as int;
      await ApiService().setPosPin(_pin, userId);
      
      // ✅ Update the in-memory map so _normalizedCachedPin() reflects the new PIN
      widget.cachedUser['pos_pin'] = _pin;
      
      if (!mounted) return;
      _goNext();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _pin = '';
        _firstPinEntry = null;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    final name = widget.cachedUser['name']?.toString() ?? 'User';
    final userId = widget.cachedUser['user_id'] is int
        ? widget.cachedUser['user_id'] as int
        : int.tryParse('${widget.cachedUser['user_id']}') ?? 1;

    Widget destination;
    if (role == 'customer') {
      destination = CustomerSelfOrderScreen(
        customerName: name,
        userId: userId,
        partnerId: widget.cachedUser['partner_id'],
      );
    } else if (role == 'rider') {
      destination = RiderScreen(
        riderName: name,
        riderId: userId,
      );
    } else if (role == 'admin') {
      // Admin lands directly on the reports dashboard — admin role is purely
      // analytical (sales by date / payment / product / branch ranking).
      destination = const AdminReportsScreen(asAdminHome: true);
    } else {
      destination = PosScreen(
        cashierName: name,
        cashierId: userId,
        role: 'cashier',
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
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
    final size = MediaQuery.sizeOf(context);
    // Side-by-side (who is on the till | keypad) only where there is room for
    // both: landscape tablets / large windows. Everything else stacks, with the
    // keypad pinned to the bottom so it never needs scrolling.
    final sideBySide = Ld.isTablet(context) && size.width > size.height && size.width >= 900;
    return Scaffold(
      backgroundColor: Ld.navy,
      body: sideBySide ? _buildSideBySide(context) : _buildStacked(context),
    );
  }

  String get _userName {
    final raw = widget.cachedUser['name']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw : (AppLocalizations.of(context)?.roleCashier ?? 'Cashier');
  }

  String get _tillLabel {
    final pos = widget.cachedUser['pos_name']?.toString().trim() ?? '';
    final branch = widget.cachedUser['branch_name']?.toString().trim() ?? '';
    final parts = [pos, branch].where((s) => s.isNotEmpty && s != 'false').toList();
    return parts.join(', ');
  }

  String _promptText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _isSetupMode
        ? (_firstPinEntry == null
            ? (l10n?.createYour4DigitPin ?? 'Create your 4-digit PIN')
            : (l10n?.confirmYourNewPin ?? 'Confirm your new PIN'))
        : (l10n?.enterPinToUnlock ?? 'Enter PIN to unlock');
  }

  String _errorText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _isSetupMode
        ? (l10n?.pinMismatchOrSaveFailed ?? 'PIN mismatch or save failed')
        : (l10n?.incorrectPin ?? 'Incorrect PIN');
  }

  /// Bear + wordmark + which till this is.
  Widget _brandRow({required bool large, bool showTill = true}) {
    final till = showTill ? _tillLabel : '';
    return Row(
      children: [
        Image.asset(
          'assets/images/ladolce_bear_logo.png',
          width: large ? 44 : 36,
          height: large ? 44 : 36,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            Icons.pets_rounded,
            size: large ? 32 : 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'LaDolce',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ld.title(large ? 24 : 20, color: Colors.white),
          ),
        ),
        if (till.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              till,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: large ? 15 : 13, color: Ld.onNavyMuted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _switchUserButton({required bool compact}) {
    final label = AppLocalizations.of(context)?.switchUser ?? 'Switch User';
    return OutlinedButton.icon(
      onPressed: _logout,
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Ld.navyLine),
        minimumSize: Size(compact ? 44 : 48, compact ? 44 : 48),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
        textStyle: TextStyle(fontSize: compact ? 14 : 15, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.r)),
      ),
    );
  }

  Widget _pinDots({required double dot, required double gap}) {
    final filled = _pin.length;
    return Semantics(
      label: '$filled / $_pinLength',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_pinLength, (index) {
          final on = index < filled;
          return Container(
            margin: EdgeInsets.symmetric(horizontal: gap / 2),
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? Ld.gold : Colors.transparent,
              border: Border.all(
                color: _hasError
                    ? _errorOnNavy
                    : (on ? Ld.gold : const Color(0xFF5A6AB8)),
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Light red that stays readable on navy.
  static const Color _errorOnNavy = Color(0xFFFF9B93);

  Widget _errorLine({required TextAlign align}) {
    // Fixed slot so the layout does not jump when the message appears.
    return SizedBox(
      height: 32,
      child: _hasError
          ? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  align == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: _errorOnNavy),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _errorText(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _errorOnNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  // ── Tablet landscape: who is on the till | raised keypad panel ───────────
  Widget _buildSideBySide(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final panelWidth = (size.width * 0.42).clamp(420.0, 520.0);
    return Row(
      children: [
        Expanded(
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 36, 40, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandRow(large: true),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                _buildUserAvatar(size: 56),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    l10n?.welcomeBack ?? 'Welcome back',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 18, color: Ld.onNavyMuted),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _userName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Ld.title(48, color: Colors.white).copyWith(height: 1.15),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _promptText(context),
                              style: const TextStyle(fontSize: 18, color: Ld.onNavyMuted),
                            ),
                            const SizedBox(height: 20),
                            _pinDots(dot: 22, gap: 16),
                            const SizedBox(height: 8),
                            _errorLine(align: TextAlign.start),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _switchUserButton(compact: false),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: panelWidth,
          color: Ld.navyRaised,
          child: SafeArea(
            left: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 372,
                  child: _buildKeypad(keyHeight: _keySize, gap: _keyGap),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phones and portrait tablets: header, who, keypad pinned at the bottom ─
  Widget _buildStacked(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final short = MediaQuery.sizeOf(context).height < 700;
    final tablet = Ld.isTablet(context);
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
            child: Row(
              children: [
                Expanded(child: _brandRow(large: tablet, showTill: tablet)),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                  ),
                  child: _switchUserButton(compact: true),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!tablet && _tillLabel.isNotEmpty) ...[
                          Text(
                            _tillLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Ld.onNavyMuted),
                          ),
                          SizedBox(height: short ? 8 : 12),
                        ],
                        _buildUserAvatar(size: short ? 52 : (tablet ? 88 : 72)),
                        SizedBox(height: short ? 8 : 12),
                        Text(
                          l10n?.welcomeBack ?? 'Welcome back',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: Ld.onNavyMuted),
                        ),
                        Text(
                          _userName,
                          textAlign: TextAlign.center,
                          maxLines: short ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: Ld.title(short ? 22 : (tablet ? 34 : 26), color: Colors.white),
                        ),
                        SizedBox(height: short ? 4 : 8),
                        Text(
                          _promptText(context),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, color: Ld.onNavyMuted),
                        ),
                        SizedBox(height: short ? 10 : 16),
                        _pinDots(dot: short ? 16 : 20, gap: short ? 16 : 20),
                        const SizedBox(height: 4),
                        _errorLine(align: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Ld.navyRaised,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            short ? 14 : 20,
            20,
            (short ? 12 : 20) + Ld.navInset(context),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tablet ? 420 : 360),
              child: _buildKeypad(keyHeight: _keySize, gap: _keyGap),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar({double size = 80}) {
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Ld.navyRaised,
        border: Border.all(color: Ld.gold, width: 2),
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: imageProvider == null
          ? Center(
              child: Text(
                initials,
                style: Ld.title(size * 0.4, color: Colors.white),
              ),
            )
          : null,
    );
  }

  /// Key height adapts so the whole pad fits without scrolling: smaller keys
  /// on short phones, the big 100 px keys of the design on landscape tablets.
  double get _keySize {
    final size = MediaQuery.sizeOf(context);
    if (Ld.isTablet(context)) return size.height < 900 ? 88 : 96;
    return size.height < 700 ? 56 : 68;
  }

  double get _keyGap {
    final size = MediaQuery.sizeOf(context);
    if (Ld.isTablet(context)) return 16;
    return size.height < 700 ? 8 : 12;
  }

  Widget _buildKeypad({required double keyHeight, required double gap}) {
    if (_isSubmitting) {
      // Same footprint as the pad so nothing jumps while the PIN is saved.
      return SizedBox(
        height: keyHeight * 4 + gap * 3,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    Widget row(List<Widget> keys) => Row(
          children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: SizedBox(height: keyHeight, child: keys[i])),
            ],
          ],
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([_numButton('1'), _numButton('2'), _numButton('3')]),
        SizedBox(height: gap),
        row([_numButton('4'), _numButton('5'), _numButton('6')]),
        SizedBox(height: gap),
        row([_numButton('7'), _numButton('8'), _numButton('9')]),
        SizedBox(height: gap),
        row([
          const SizedBox.shrink(),
          _numButton('0'),
          _actionButton(Icons.backspace_outlined, _onBackspace),
        ]),
      ],
    );
  }

  Widget _numButton(String number) {
    final radius = BorderRadius.circular(_keySize >= 80 ? 24 : 18);
    return Semantics(
      button: true,
      label: number,
      excludeSemantics: true,
      child: Material(
        color: Ld.navy,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: Ld.navyLine),
        ),
        child: InkWell(
          onTap: () => _onKeyPress(number),
          borderRadius: radius,
          child: Center(
            child: Text(
              number,
              style: Ld.price(
                _keySize >= 80 ? 36 : 28,
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onTap) {
    final radius = BorderRadius.circular(_keySize >= 80 ? 24 : 18);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: _keySize >= 80 ? 34 : 28,
            semanticLabel: MaterialLocalizations.of(context).deleteButtonTooltip,
          ),
        ),
      ),
    );
  }
}
