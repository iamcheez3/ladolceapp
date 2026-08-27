import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:upgrader/upgrader.dart';
import 'utils/responsive_layout.dart';
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/push_notifications_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/maintenance_screen.dart';
import 'models/product.dart';
import 'services/maintenance_service.dart';
import 'services/user_activity_service.dart';

void main() async {
  // Ensure bindings are initialized before loading dotenv
  WidgetsFlutterBinding.ensureInitialized();
  // Keep app boot resilient if `.env` wasn't created yet in a fresh clone.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // FCM init (requires google-services.json / GoogleService-Info.plist in the app).
  // Best-effort: do not block app startup if Firebase is not configured yet.
  try {
    await PushNotificationsService.initialize();
  } catch (_) {}

  // Check cache for offline auth
  final cachedUser = await ApiService().getCachedUser();

  // Check maintenance status
  final maintenanceStatus = await ApiService().fetchMaintenanceStatus();

  runApp(PosApp(initialUser: cachedUser, maintenanceStatus: maintenanceStatus));
}

class PosApp extends StatefulWidget {
  final Map<String, dynamic>? initialUser;
  final Map<String, dynamic>? maintenanceStatus;

  const PosApp({super.key, this.initialUser, this.maintenanceStatus});

  static void setLocale(BuildContext context, Locale newLocale) {
    _PosAppState state = context.findAncestorStateOfType<_PosAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    MaintenanceService().startChecking();
    UserActivityService().startTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationsService.requestPermissionPostFrame();
    });
    _fetchLocale().then((locale) {
      setState(() {
        _locale = locale;
      });
    });
  }

  Future<Locale> _fetchLocale() async {
    var prefs = await SharedPreferences.getInstance();
    String languageCode = prefs.getString('languageCode') ?? 'en';
    return Locale(languageCode);
  }

  void setLocale(Locale locale) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    setState(() {
      _locale = locale;
    });
  }

  Widget _initialScreen() {
    if (widget.maintenanceStatus != null &&
        widget.maintenanceStatus!['is_active'] == true) {
      return MaintenanceScreen(
        messageEn: widget.maintenanceStatus!['message_en'] ?? 'Maintenance',
        messageLo: widget.maintenanceStatus!['message_lo'] ?? 'Maintenance',
      );
    }

    if (widget.initialUser == null) {
      return const LoginScreen();
    }

    return LoadingScreen(user: widget.initialUser!);
  }

  @override
  Widget build(BuildContext context) {
    // Keep product naming in step with the chosen language. Set here so it is
    // applied on first build and again on every setLocale.
    Product.useLaoNames = _locale?.languageCode == 'lo';
    return MaterialApp(
      navigatorKey: MaintenanceService().navigatorKey,
      title: 'LaDolce POS',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => _OrientationLocker(
        child: ResponsiveLayout.withClampedTextScaling(
          child: UpgradeAlert(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      theme: ThemeData(
        fontFamily: _locale?.languageCode == 'lo'
            ? GoogleFonts.notoSansLao().fontFamily
            : 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF001460), // Brand navy
          primary: const Color(0xFF001460),
          secondary: const Color(0xFF3B82F6),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF001460),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: _initialScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/maintenance') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => MaintenanceScreen(
              messageEn: args?['message_en'] ?? 'Maintenance',
              messageLo: args?['message_lo'] ?? 'Maintenance',
            ),
          );
        }
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
        return null;
      },
    );
  }
}

class _OrientationLocker extends StatefulWidget {
  final Widget child;
  const _OrientationLocker({required this.child});

  @override
  State<_OrientationLocker> createState() => _OrientationLockerState();
}

class _OrientationLockerState extends State<_OrientationLocker> {
  bool? _wasTablet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    if (_wasTablet != isTablet) {
      _wasTablet = isTablet;
      if (isTablet) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
