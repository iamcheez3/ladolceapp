import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import '../utils/l10n_ext.dart';

class PrinterEditScreen extends StatefulWidget {
  final PrinterProfile? profile;

  const PrinterEditScreen({super.key, this.profile});

  bool get isEditing => profile != null;

  @override
  State<PrinterEditScreen> createState() => _PrinterEditScreenState();
}

class _PrinterEditScreenState extends State<PrinterEditScreen> {
  final ApiService _apiService = ApiService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  late int _paperWidth;
  late bool _asDefaultReceipt;
  late bool _printReceipts;
  late bool _printOrders;
  late bool _singleItem;
  late bool _groupItems;
  late Set<String> _selectedCats;
  bool _isSaving = false;
  bool _isTesting = false;

  List<String> _categories = [];
  bool _loadingCats = true;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _ipCtrl = TextEditingController(text: p?.ip ?? '');
    _portCtrl = TextEditingController(text: (p?.port ?? 9100).toString());
    _paperWidth = p?.paperWidthMm ?? 80;
    _asDefaultReceipt = p != null && p.id == printerService.selectedReceiptPrinterId;
    _printReceipts = p?.printReceiptsAndBills ?? true;
    _printOrders = p?.printOrders ?? false;
    _singleItem = p?.singleItemPerTicket ?? false;
    _groupItems = p?.groupIdenticalItems ?? true;
    _selectedCats = {...(p?.categoryFilters ?? <String>[])};
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final products = await _apiService.fetchProducts(limit: 300);
      final set = products.map((e) => e.category).where((e) => e.trim().isNotEmpty).toSet().toList()..sort();
      if (mounted) {
        setState(() {
          _categories = set;
          _loadingCats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    if (name.isEmpty || ip.isEmpty) return;

    setState(() => _isSaving = true);

    final id = widget.profile?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final p = PrinterProfile(
      id: id,
      name: name,
      ip: ip,
      port: port,
      paperWidthMm: _paperWidth,
      printReceiptsAndBills: _printReceipts,
      printOrders: _printOrders,
      singleItemPerTicket: _singleItem,
      groupIdenticalItems: _groupItems,
      categoryFilters: _selectedCats.toList()..sort(),
    );

    await printerService.savePrinter(p, setAsReceiptPrinter: _asDefaultReceipt);
    if (_asDefaultReceipt) {
      await printerService.setReceiptPrinter(p.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.printerSaved), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    if (widget.profile == null) return;
    await printerService.deletePrinter(widget.profile!.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.printerDeleted), backgroundColor: Colors.orange),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? widget.profile!.name : context.l10n.addPrinter),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(context.l10n.save, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
        ],
      ),
      body: LuxuryPatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _buildSection(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: LaDolcePosUi.input(
                    hintText: context.l10n.name,
                    prefixIcon: const Icon(Icons.label_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _ipCtrl,
                  decoration: LaDolcePosUi.input(
                    hintText: context.l10n.printerIpAddress,
                    prefixIcon: const Icon(Icons.router_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _portCtrl,
                  keyboardType: TextInputType.number,
                  decoration: LaDolcePosUi.input(
                    hintText: context.l10n.port,
                    prefixIcon: const Icon(Icons.numbers, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _paperWidth,
                  decoration: LaDolcePosUi.input(hintText: context.l10n.paperWidth),
                  items: const [
                    DropdownMenuItem(value: 80, child: Text('80 mm')),
                    DropdownMenuItem(value: 58, child: Text('58 mm')),
                  ],
                  onChanged: (v) => setState(() => _paperWidth = v ?? 80),
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  icon: Icons.receipt_outlined,
                  value: _asDefaultReceipt,
                  title: context.l10n.defaultPrinterForReceipts,
                  onChanged: (v) => setState(() => _asDefaultReceipt = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: context.l10n.advancedSettings,
              children: [
                _buildSwitchTile(
                  icon: Icons.receipt_long_outlined,
                  value: _printReceipts,
                  title: context.l10n.printReceiptsAndBills,
                  onChanged: (v) => setState(() => _printReceipts = v),
                ),
                const Divider(height: 1, indent: 44),
                _buildSwitchTile(
                  icon: Icons.receipt_outlined,
                  value: _printOrders,
                  title: context.l10n.printOrders,
                  onChanged: (v) => setState(() => _printOrders = v),
                ),
                const Divider(height: 1, indent: 44),
                _buildSwitchTile(
                  icon: Icons.article_outlined,
                  value: _singleItem,
                  title: context.l10n.printSingleItemPerOrderTicket,
                  onChanged: (v) => setState(() => _singleItem = v),
                ),
                const Divider(height: 1, indent: 44),
                _buildSwitchTile(
                  icon: Icons.copy_outlined,
                  value: _groupItems,
                  title: context.l10n.groupIdenticalItemsInOrderTickets,
                  onChanged: (v) => setState(() => _groupItems = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: context.l10n.categoryRouting,
              subtitle: context.l10n.ifNoneSelectedAllCategoriesWill,
              children: [
                if (_loadingCats)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else if (_categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.l10n.noCategoriesFound, style: TextStyle(color: LaDolcePosUi.mutedText, fontSize: 13)),
                  )
                else
                  ..._categories.map((c) => CheckboxListTile(
                        value: _selectedCats.contains(c),
                        onChanged: (v) => setState(() {
                          if (v == true) { _selectedCats.add(c); } else { _selectedCats.remove(c); }
                        }),
                        title: Text(c, style: const TextStyle(fontSize: 14)),
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      )),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isTesting || _isSaving
                  ? null
                  : () async {
                      final name = _nameCtrl.text.trim();
                      final ip = _ipCtrl.text.trim();
                      final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
                      if (name.isEmpty || ip.isEmpty) return;

                      setState(() => _isTesting = true);
                      final ok = await printerService.testProfile(
                        PrinterProfile(
                          id: widget.profile?.id ?? '',
                          name: name,
                          ip: ip,
                          port: port,
                          paperWidthMm: _paperWidth,
                        ),
                      );
                      setState(() => _isTesting = false);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Printer test successful.' : context.l10n.printerTestFailed),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    },
              icon: _isTesting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print_outlined, size: 20),
              label: Text(_isTesting ? 'Testing...' : context.l10n.printTest),
              style: LaDolcePosUi.primaryButtonStyle(),
            ),
            if (widget.profile != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: Text(context.l10n.deletePrinter),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LaDolcePosUi.radiusSm)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({String? title, String? subtitle, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: LaDolcePosUi.navy)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: LaDolcePosUi.mutedText)),
            ],
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required bool value,
    required String title,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: LaDolcePosUi.navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: LaDolcePosUi.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Switch(
              value: value,
              activeColor: LaDolcePosUi.navy,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
