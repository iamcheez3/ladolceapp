import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/ld.dart';

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
    final short = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      backgroundColor: Ld.navy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (viewport.maxHeight - 48).clamp(0.0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: short ? 72 : 88,
                          height: short ? 72 : 88,
                          decoration: BoxDecoration(
                            color: Ld.navyRaised,
                            borderRadius: BorderRadius.circular(Ld.rXl),
                            border: Border.all(color: Ld.navyLine),
                          ),
                          child: Icon(
                            Icons.handyman_rounded,
                            size: short ? 36 : 44,
                            color: Ld.gold,
                          ),
                        ),
                      ),
                      SizedBox(height: short ? 18 : 26),
                      Text(
                        isLao
                            ? 'ກຳລັງປັບປຸງລະບົບ'
                            : (AppLocalizations.of(context)?.maintenanceMode ?? 'Maintenance Mode'),
                        textAlign: TextAlign.center,
                        style: Ld.title(short ? 24 : 28, color: Colors.white),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: Ld.card(radius: Ld.rXl),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Ld.body.copyWith(height: 1.5),
                        ),
                      ),
                      SizedBox(height: short ? 28 : 40),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ApiService().logout();
                            if (context.mounted) {
                              Navigator.of(
                                context,
                              ).pushNamedAndRemoveUntil('/login', (route) => false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Ld.gold,
                            foregroundColor: Ld.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Ld.rMd),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(
                            isLao ? 'ອອກຈາກລະບົບ' : (AppLocalizations.of(context)?.logout ?? 'Logout'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
