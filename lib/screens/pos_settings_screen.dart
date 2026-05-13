import 'package:flutter/material.dart';
import 'printer_settings_screen.dart';
import 'bill_template_settings_screen.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ladolce_pos_ui.dart';

class PosSettingsScreen extends StatefulWidget {
  final Future<void> Function() onSyncRequested;

  const PosSettingsScreen({
    super.key,
    required this.onSyncRequested,
  });

  @override
  State<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends State<PosSettingsScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            icon: Icons.print,
            title: 'Printer Configuration',
            subtitle: printerService.profiles.isNotEmpty
                ? '${printerService.profiles.length} printer(s) configured'
                : (printerService.isConfigured
                    ? 'Connected: ${printerService.printerIp}'
                    : 'Not configured'),
            subtitleColor: printerService.isConfigured ? Colors.green : null,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen(),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Bill Templates',
            subtitle: 'Select bill/receipt/refund templates for this branch',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BillTemplateSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.sync,
            title: 'Sync All Data',
            subtitle: 'Manually refresh all local data from Odoo server',
            onTap: () async {
              await widget.onSyncRequested();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LaDolcePosUi.card,
          borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
          border: Border.all(color: LaDolcePosUi.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LaDolcePosUi.navy.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LaDolcePosUi.navy.withOpacity(0.14)),
              ),
              child: Icon(icon, color: LaDolcePosUi.navy, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: LaDolcePosUi.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor ?? LaDolcePosUi.mutedText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: LaDolcePosUi.mutedText),
          ],
        ),
      ),
    );
  }
}
