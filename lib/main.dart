import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:upgrader/upgrader.dart';
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() async {
  // Ensure bindings are initialized before loading dotenv
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Check cache for offline auth
  final cachedUser = await ApiService().getCachedUser();
  
  runApp(PosApp(initialUser: cachedUser));
}

class PosApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  
  const PosApp({Key? key, this.initialUser}) : super(key: key);

  Widget _initialScreen() {
    if (initialUser == null) {
      return const LoginScreen();
    }

    return LoadingScreen(user: initialUser!);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LaDolce POS',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => UpgradeAlert(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D1565), // Brand navy
          primary: const Color(0xFF0D1565),
          secondary: const Color(0xFF3B82F6),
          background: const Color(0xFFF8FAFC),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1565),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: _initialScreen(),
    );
  }
}
