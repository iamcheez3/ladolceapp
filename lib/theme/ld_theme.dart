import 'package:flutter/material.dart';

import 'ld.dart';

/// App-wide Material theme for the redesign: every screen gets the bundled
/// Lao font, the porcelain ground, navy bars and the shared control shapes,
/// even before it is restyled by hand.
ThemeData buildLdTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Ld.navy,
    primary: Ld.navy,
    onPrimary: Colors.white,
    secondary: Ld.gold,
    onSecondary: Ld.navy,
    surface: Ld.surface,
    onSurface: Ld.ink,
    error: Ld.danger,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd));
  const buttonText = TextStyle(fontFamily: Ld.sans, fontSize: 16, fontWeight: FontWeight.w700);
  const minButton = Size(64, Ld.tap);

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Ld.r),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: Ld.sans,
    colorScheme: scheme,
    scaffoldBackgroundColor: Ld.ground,
    canvasColor: Ld.ground,
    dividerColor: Ld.lineSoft,
    dividerTheme: const DividerThemeData(color: Ld.lineSoft, thickness: 1, space: 1),
    // Gestures: predictive back on Android (system back swipe and the back
    // button both animate and respect PopScope), swipe-from-edge back on iOS.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Ld.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: Ld.serif, fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Ld.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rLg),
        side: const BorderSide(color: Ld.line),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: minButton,
        shape: shape,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        minimumSize: minButton,
        shape: shape,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Ld.navy,
        minimumSize: minButton,
        side: const BorderSide(color: Ld.line),
        shape: shape,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Ld.navy,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Ld.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: Ld.faint, fontSize: 16),
      labelStyle: const TextStyle(color: Ld.muted),
      border: border(Ld.line),
      enabledBorder: border(Ld.line),
      focusedBorder: border(Ld.navy, 2),
      errorBorder: border(Ld.danger),
      focusedErrorBorder: border(Ld.danger, 2),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Ld.surface,
      selectedColor: Ld.navy,
      side: const BorderSide(color: Ld.line),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 14, color: Ld.ink),
      secondaryLabelStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 14, color: Colors.white),
      checkmarkColor: Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Ld.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rXl)),
      titleTextStyle: const TextStyle(fontFamily: Ld.serif, fontSize: 21, fontWeight: FontWeight.w700, color: Ld.navy),
      contentTextStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 16, color: Ld.ink, height: 1.45),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Ld.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Ld.ink,
      contentTextStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 15, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.r)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Ld.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Ld.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rLg)),
      textStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 16, color: Ld.ink),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Ld.navy,
      textColor: Ld.ink,
      minVerticalPadding: 10,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ld.navy : null),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ld.navy : Ld.muted),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ld.gold : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ld.navy : null),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Ld.navy),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Ld.onNavyMuted,
      indicatorColor: Ld.gold,
      labelStyle: TextStyle(fontFamily: Ld.sans, fontSize: 16, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: Ld.sans, fontSize: 16, fontWeight: FontWeight.w500),
    ),
  );
}
