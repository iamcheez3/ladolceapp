import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class MaintenanceScreen extends StatelessWidget {
  final String messageEn;
  final String messageLo;

  const MaintenanceScreen({
    super.key,
    required this.messageEn,
    required this.messageLo,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isLao = locale.languageCode == 'lo';
    final message = isLao ? messageLo : messageEn;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF001460), // Brand navy
              Color(0xFF1E293B), // Slate 800
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.handyman_rounded,
                  size: 80,
                  color: Color(0xFF3B82F6), // Brand blue
                ),
                const SizedBox(height: 32),
                Text(
                  isLao ? 'ກຳລັງປັບປຸງລະບົບ' : (AppLocalizations.of(context)?.maintenanceMode ?? 'Maintenance Mode'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansLao(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansLao(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () async {
                    await ApiService().logout();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF001460),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isLao ? 'ອອກຈາກລະບົບ' : (AppLocalizations.of(context)?.logout ?? 'Logout'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
