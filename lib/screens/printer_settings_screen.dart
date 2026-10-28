import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ld.dart';
import 'printer_edit_screen.dart';

class PrinterSettingsScreen extends StatefulWidget {
  /// True when shown inside the tablet Settings screen (right-hand pane):
  /// no own app bar, the "Add printer" button sits in the section header.
  final bool embedded;

  /// Called after a printer was added, changed or deleted.
  final VoidCallback? onChanged;

  const PrinterSettingsScreen({super.key, this.embedded = false, this.onChanged});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await printerService.initialize();
    try {
      await _apiService.fetchProducts();
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
      if (saved == true && mounted) {
        setState(() {});
        widget.onChanged?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.printers ?? 'Printers';
    final addLabel = l10n?.addPrinter ?? 'Add Printer';

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: Ld.title(24), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _openPrinterScreen(),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(addLabel),
                ),
              ],
            ),
          ),
          Expanded(child: _body(context, horizontal: 28, bottom: 24)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(title: title),
      body: _body(context, horizontal: 16, bottom: 96),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        onPressed: () => _openPrinterScreen(),
        icon: const Icon(Icons.add_rounded),
        label: Text(addLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }

  Widget _body(BuildContext context, {required double horizontal, required double bottom}) {
    final profiles = printerService.profiles;
    final l10n = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (profiles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + Ld.navInset(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LdIconTile(Icons.print_outlined, size: 80),
              const SizedBox(height: 20),
              Text(
                l10n?.noPrintersYet ?? 'No printers yet',
                textAlign: TextAlign.center,
                style: Ld.title(20),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap + to add your first printer.\nConfigure receipts, orders, and category routing.',
                textAlign: TextAlign.center,
                style: Ld.label,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(l10n?.addPrinter ?? 'Add Printer'),
                onPressed: () => _openPrinterScreen(),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, bottom + Ld.navInset(context)),
      itemCount: profiles.length,
      itemBuilder: (context, i) {
        final p = profiles[i];
        final isDefault = p.id == printerService.selectedReceiptPrinterId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PrinterCard(
            profile: p,
            isDefault: isDefault,
            onTap: () => _openPrinterScreen(profile: p),
          ),
        );
      },
    );
  }
}

class _PrinterCard extends StatelessWidget {
  final PrinterProfile profile;
  final bool isDefault;
  final VoidCallback onTap;

  const _PrinterCard({
    required this.profile,
    required this.isDefault,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final jobs = <String>[
      if (profile.printReceiptsAndBills) l10n?.receipt ?? 'Receipt',
      if (profile.printOrders) l10n?.orders ?? 'Orders',
    ];
    final disabled = jobs.isEmpty;

    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rLg),
        side: const BorderSide(color: Ld.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ld.rLg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
          child: Row(
            children: [
              const LdIconTile(Icons.print_outlined, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Ld.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.ip}:${profile.port} · ${profile.paperWidthMm} mm',
                      style: const TextStyle(fontSize: 14, color: Ld.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isDefault)
                          LdPill(
                            l10n?.defaultLabel ?? 'Default',
                            background: Ld.successWash,
                            foreground: Ld.success,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        if (disabled)
                          LdPill(
                            l10n?.disabled ?? 'Disabled',
                            background: Ld.warningWash,
                            foreground: Ld.warning,
                          ),
                        for (final j in jobs) LdPill(j),
                      ],
                    ),
                    if (profile.categoryFilters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.category_outlined, size: 16, color: Ld.muted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              profile.categoryFilters.join(', '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Ld.small,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Ld.muted),
            ],
          ),
        ),
      ),
    );
  }
}
