import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ladolce_pos_ui.dart';
import 'printer_edit_screen.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;

  static const Color _accent = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await printerService.initialize();
    try {
      await _apiService.fetchProducts(limit: 300);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPrinterScreen({PrinterProfile? profile}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PrinterEditScreen(profile: profile),
      ),
    ).then((saved) {
      if (saved == true && mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = printerService.profiles;

    return Scaffold(
      backgroundColor: LaDolcePosUi.surface,
      appBar: AppBar(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        title: const Text('Printers'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profiles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.print_outlined, color: _accent.withValues(alpha: 0.5), size: 40),
                        ),
                        const SizedBox(height: 20),
                        const Text('No printers yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          'Tap + to add your first printer.\nConfigure receipts, orders, and category routing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: LaDolcePosUi.mutedText, height: 1.35),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Printer'),
                          onPressed: () => _openPrinterScreen(),
                          style: LaDolcePosUi.primaryButtonStyle(),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  itemCount: profiles.length,
                  itemBuilder: (context, i) {
                    final p = profiles[i];
                    final isDefault = p.id == printerService.selectedReceiptPrinterId;
                    return _PrinterCard(
                      profile: p,
                      isDefault: isDefault,
                      accent: _accent,
                      onTap: () => _openPrinterScreen(profile: p),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: () => _openPrinterScreen(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PrinterCard extends StatelessWidget {
  final PrinterProfile profile;
  final bool isDefault;
  final Color accent;
  final VoidCallback onTap;

  const _PrinterCard({
    required this.profile,
    required this.isDefault,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mode = profile.printOrders
        ? 'Orders'
        : (profile.printReceiptsAndBills ? 'Receipt' : 'Disabled');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
        child: Container(
          decoration: BoxDecoration(
            color: LaDolcePosUi.card,
            borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
            border: Border.all(color: LaDolcePosUi.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.print_outlined, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Default',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${profile.ip}:${profile.port}',
                            style: TextStyle(fontSize: 12, color: LaDolcePosUi.mutedText),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: LaDolcePosUi.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              mode,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: LaDolcePosUi.mutedText),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: LaDolcePosUi.mutedText, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
