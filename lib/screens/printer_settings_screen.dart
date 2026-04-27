import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/luxury_background.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  static const _brandNavy = Color(0xFF0D1565);
  static const _brandNavy2 = Color(0xFF142B8C);

  final ApiService _apiService = ApiService();
  bool _loading = true;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await printerService.initialize();
    try {
      final products = await _apiService.fetchProducts(limit: 300);
      final set = products.map((e) => e.category).where((e) => e.trim().isNotEmpty).toSet().toList()..sort();
      if (!mounted) return;
      setState(() {
        _categories = set;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({PrinterProfile? profile}) async {
    final id = profile?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final ipCtrl = TextEditingController(text: profile?.ip ?? '');
    final portCtrl = TextEditingController(text: (profile?.port ?? 9100).toString());
    int paperWidth = profile?.paperWidthMm ?? 80;
    bool printReceipts = profile?.printReceiptsAndBills ?? true;
    bool printOrders = profile?.printOrders ?? false;
    bool singleItem = profile?.singleItemPerTicket ?? false;
    bool groupItems = profile?.groupIdenticalItems ?? true;
    final selectedCats = {...(profile?.categoryFilters ?? <String>[])};
    bool asDefaultReceipt = profile != null && profile.id == printerService.selectedReceiptPrinterId;
    bool isTesting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Color(0xFFF6F7FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_brandNavy, _brandNavy2]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          profile == null ? 'Add Printer' : 'Edit Printer',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(ctx);
                          final name = nameCtrl.text.trim();
                          final ip = ipCtrl.text.trim();
                          final port = int.tryParse(portCtrl.text.trim()) ?? 9100;
                          if (name.isEmpty || ip.isEmpty) return;

                          final p = PrinterProfile(
                            id: id,
                            name: name,
                            ip: ip,
                            port: port,
                            paperWidthMm: paperWidth,
                            printReceiptsAndBills: printReceipts,
                            printOrders: printOrders,
                            singleItemPerTicket: singleItem,
                            groupIdenticalItems: groupItems,
                            categoryFilters: selectedCats.toList()..sort(),
                          );
                          await printerService.savePrinter(p, setAsReceiptPrinter: asDefaultReceipt);
                          if (asDefaultReceipt) {
                            await printerService.setReceiptPrinter(p.id);
                          }
                          if (!mounted) return;
                          setState(() {});
                          navigator.pop();
                        },
                        child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: ipCtrl,
                        decoration: const InputDecoration(labelText: 'Printer IP address'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Port'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: paperWidth,
                        items: const [
                          DropdownMenuItem(value: 80, child: Text('80 mm')),
                          DropdownMenuItem(value: 58, child: Text('58 mm')),
                        ],
                        onChanged: (v) => setSheet(() => paperWidth = v ?? 80),
                        decoration: const InputDecoration(labelText: 'Paper width'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: asDefaultReceipt,
                        onChanged: (v) => setSheet(() => asDefaultReceipt = v),
                        title: const Text('Default printer for receipts'),
                      ),
                      const Divider(height: 26),
                      const Text('Advanced settings', style: TextStyle(fontWeight: FontWeight.w700, color: _brandNavy)),
                      SwitchListTile(
                        value: printReceipts,
                        onChanged: (v) => setSheet(() => printReceipts = v),
                        title: const Text('Print receipts and bills'),
                      ),
                      SwitchListTile(
                        value: printOrders,
                        onChanged: (v) => setSheet(() => printOrders = v),
                        title: const Text('Print orders'),
                      ),
                      SwitchListTile(
                        value: singleItem,
                        onChanged: (v) => setSheet(() => singleItem = v),
                        title: const Text('Print single item per order ticket'),
                      ),
                      SwitchListTile(
                        value: groupItems,
                        onChanged: (v) => setSheet(() => groupItems = v),
                        title: const Text('Group identical items in order tickets'),
                      ),
                      const Divider(height: 26),
                      const Text('Category routing', style: TextStyle(fontWeight: FontWeight.w700, color: _brandNavy)),
                      const SizedBox(height: 6),
                      const Text(
                        'If none selected, all categories will print on this printer.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      ..._categories.map((c) => CheckboxListTile(
                            value: selectedCats.contains(c),
                            onChanged: (v) => setSheet(() {
                              if (v == true) {
                                selectedCats.add(c);
                              } else {
                                selectedCats.remove(c);
                              }
                            }),
                            title: Text(c),
                            controlAffinity: ListTileControlAffinity.trailing,
                          )),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isTesting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final ip = ipCtrl.text.trim();
                                final port = int.tryParse(portCtrl.text.trim()) ?? 9100;
                                if (name.isEmpty || ip.isEmpty) return;
                                setSheet(() => isTesting = true);
                                final ok = await printerService.testProfile(
                                  PrinterProfile(
                                    id: id,
                                    name: name,
                                    ip: ip,
                                    port: port,
                                    paperWidthMm: paperWidth,
                                  ),
                                );
                                setSheet(() => isTesting = false);
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Printer test successful.' : 'Printer test failed.'),
                                    backgroundColor: ok ? Colors.green : Colors.red,
                                  ),
                                );
                              },
                        style: FilledButton.styleFrom(backgroundColor: _brandNavy),
                        icon: isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print_outlined),
                        label: Text(isTesting ? 'Testing...' : 'PRINT TEST'),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final navigator = Navigator.of(ctx);
                            await printerService.deletePrinter(profile.id);
                            if (!mounted) return;
                            setState(() {});
                            navigator.pop();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('DELETE PRINTER'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = printerService.profiles;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: _brandNavy,
        foregroundColor: Colors.white,
        title: const Text('Printers'),
      ),
      body: LuxuryPatternBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : profiles.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 22),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.93),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _brandNavy.withOpacity(0.12)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.print_outlined, size: 44, color: _brandNavy),
                          SizedBox(height: 12),
                          Text(
                            'No printers yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _brandNavy),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap + to add your first printer.\nYou can configure receipts, orders, and category routing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = profiles[i];
                      final isDefault = p.id == printerService.selectedReceiptPrinterId;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: _brandNavy.withOpacity(0.08)),
                        ),
                        tileColor: Colors.white.withOpacity(0.94),
                        leading: CircleAvatar(
                          backgroundColor: _brandNavy.withOpacity(0.08),
                          child: const Icon(Icons.print, color: _brandNavy),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${p.ip}:${p.port}${isDefault ? ' • Default receipt printer' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          p.printOrders ? 'Orders' : (p.printReceiptsAndBills ? 'Receipt' : 'Disabled'),
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                        onTap: () => _openEditor(profile: p),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4CAF50),
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
