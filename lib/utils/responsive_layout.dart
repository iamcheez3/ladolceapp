import 'package:flutter/material.dart';

/// Shared breakpoints and helpers for adaptive layouts across the app.
/// Uses logical pixels from [MediaQuery].
class ResponsiveLayout {
  ResponsiveLayout._();

  /// Very narrow phones (e.g. 320dp wide).
  static const double phoneCompactMaxWidth = 360;

  /// Typical Material “tablet” breakpoint (shortest side).
  static const double tabletMinShortestSide = 600;

  /// Two-pane POS / split layouts (catalog + cart side-by-side).
  static const double twoPaneMinWidth = 800;

  static Size screenSizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static EdgeInsets paddingOf(BuildContext context) =>
      MediaQuery.paddingOf(context);

  static EdgeInsets viewInsetsOf(BuildContext context) =>
      MediaQuery.viewInsetsOf(context);

  static bool isPortrait(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.portrait;

  static bool isLandscape(BuildContext context) =>
      !isPortrait(context);

  static double shortestSideOf(BuildContext context) {
    final s = screenSizeOf(context);
    return s.width < s.height ? s.width : s.height;
  }

  static bool isPhoneCompact(BuildContext context) =>
      screenSizeOf(context).width < phoneCompactMaxWidth;

  static bool isTabletOrLarger(BuildContext context) =>
      shortestSideOf(context) >= tabletMinShortestSide;

  /// Inline cart rail (POS) — width-based so landscape phones stay single-pane.
  static bool showsPosCartRail(BuildContext context) =>
      screenSizeOf(context).width >= twoPaneMinWidth;

  /// Horizontal padding for scrollable forms / cards.
  static double pageHorizontalPadding(BuildContext context) {
    final w = screenSizeOf(context).width;
    if (w < phoneCompactMaxWidth) return 12;
    if (w < tabletMinShortestSide) return 16;
    return 24;
  }

  /// Bottom padding when the scaffold body is already wrapped in [SafeArea]:
  /// only adds IME [viewInsets] so the keyboard does not obscure fields.
  static EdgeInsets scrollablePaddingWithKeyboard(
    BuildContext context, {
    double top = 0,
    double horizontal = 0,
    double bottomExtra = 0,
  }) {
    final vi = viewInsetsOf(context).bottom;
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottomExtra + vi);
  }

  /// [SliverGridDelegateWithMaxCrossAxisExtent] sizing for POS product grids.
  static double productGridMaxCrossAxisExtent(BuildContext context) {
    final w = screenSizeOf(context).width;
    if (w < phoneCompactMaxWidth) return 140;
    if (w < 400) return 158;
    if (w < tabletMinShortestSide) return 176;
    if (w < 900) return 200;
    return 220;
  }

  static double productGridChildAspectRatio(BuildContext context) {
    if (isTabletOrLarger(context) && screenSizeOf(context).width >= twoPaneMinWidth) {
      return 0.88;
    }
    if (isPhoneCompact(context)) return 0.78;
    return 0.86;
  }

  /// Clamps overly large accessibility text scales to reduce layout breakage
  /// while preserving normal scaling.
  static Widget withClampedTextScaling({
    required Widget child,
    double minScale = 0.85,
    double maxScale = 1.35,
  }) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: minScale,
      maxScaleFactor: maxScale,
      child: child,
    );
  }
}
