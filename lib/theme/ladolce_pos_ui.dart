import 'package:flutter/material.dart';

class LaDolcePosUi {
  // Brand
  static const Color navy = Color(0xFF001460);
  static const Color navy2 = Color(0xFF142B8C);
  static const Color surface = Color(0xFFF6F7FB);
  static const Color card = Colors.white;
  static const Color accent = Color(0xFF3B82F6);
  static const Color gold = Color(0xFFC6A15B);

  // Neutrals
  static const Color text = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Layout
  static const double radius = 14;
  static const double radiusSm = 10;

  static LinearGradient get navyGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [navy, navy2],
      );

  static ShapeBorder get sheetShape => const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      );

  static InputDecoration input({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: navy, width: 2),
      ),
    );
  }

  static ButtonStyle primaryButtonStyle({bool isDestructive = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor: isDestructive ? const Color(0xFFDC2626) : navy,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: navy,
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  /// Extra bottom inset for system gesture bar / 3-button nav (not keyboard).
  /// [MediaQuery.padding] is often 0 on Android gesture navigation; prefer [viewPadding].
  static double gestureBarBottomPad(BuildContext context) {
    return 8.0 + MediaQuery.viewPaddingOf(context).bottom;
  }

  /// Bottom padding for modal sheets: IME (keyboard) + gesture / home indicator.
  static double modalBottomPadding(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom + gestureBarBottomPad(context);
  }
}

