import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ld.dart';

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
      final products = await _apiService.fetchProducts();
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
        SnackBar(content: Text(AppLocalizations.of(context)?.printerSaved ?? (AppLocalizations.of(context)?.printerSaved ?? 'Printer saved')), backgroundColor: Ld.success),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    if (widget.profile == null) return;
    await printerService.deletePrinter(widget.profile!.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.printerDeleted ?? (AppLocalizations.of(context)?.printerDeleted ?? 'Printer deleted')), backgroundColor: Ld.warning),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _testPrint() async {
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? (AppLocalizations.of(context)?.printerTestSuccessful ?? 'Printer test successful.') : (AppLocalizations.of(context)?.printerTestFailed ?? 'Printer test failed.')),
        backgroundColor: ok ? Ld.success : Ld.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tablet = Ld.isTablet(context);

    final connection = _buildSection(
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: l10n?.name ?? 'Name',
            prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ipCtrl,
          decoration: InputDecoration(
            labelText: l10n?.printerIpAddress ?? 'Printer IP address',
            prefixIcon: const Icon(Icons.router_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _portCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n?.port ?? 'Port',
            prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          value: _paperWidth,
          decoration: InputDecoration(labelText: l10n?.paperWidth ?? 'Paper width'),
          items: const [
            DropdownMenuItem(value: 80, child: Text('80 mm')),
            DropdownMenuItem(value: 58, child: Text('58 mm')),
          ],
          onChanged: (v) => setState(() => _paperWidth = v ?? 80),
        ),
        const SizedBox(height: 8),
        _buildSwitchTile(
          icon: Icons.receipt_outlined,
          value: _asDefaultReceipt,
          title: l10n?.defaultPrinterForReceipts ?? 'Default printer for receipts',
          onChanged: (v) => setState(() => _asDefaultReceipt = v),
        ),
      ],
    );

    final advanced = _buildSection(
      title: l10n?.advancedSettings ?? 'Advanced settings',
      children: [
        _buildSwitchTile(
          icon: Icons.receipt_long_outlined,
          value: _printReceipts,
          title: l10n?.printReceiptsAndBills ?? 'Print receipts and bills',
          onChanged: (v) => setState(() => _printReceipts = v),
        ),
        const Divider(height: 1, indent: 48),
        _buildSwitchTile(
          icon: Icons.receipt_outlined,
          value: _printOrders,
          title: l10n?.printOrders ?? 'Print orders',
          onChanged: (v) => setState(() => _printOrders = v),
        ),
        const Divider(height: 1, indent: 48),
        _buildSwitchTile(
          icon: Icons.article_outlined,
          value: _singleItem,
          title: l10n?.printSingleItemPerOrderTicket ?? 'Print single item per order ticket',
          onChanged: (v) => setState(() => _singleItem = v),
        ),
        const Divider(height: 1, indent: 48),
        _buildSwitchTile(
          icon: Icons.copy_outlined,
          value: _groupItems,
          title: l10n?.groupIdenticalItemsInOrderTickets ?? 'Group identical items in order tickets',
          onChanged: (v) => setState(() => _groupItems = v),
        ),
      ],
    );

    final routing = _buildSection(
      title: l10n?.categoryRouting ?? 'Category routing',
      subtitle: l10n?.ifNoneSelectedAllCategoriesWill ?? 'If none selected, all categories will print on this printer.',
      children: [
        if (_loadingCats)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n?.noCategoriesFound ?? 'No categories found', style: Ld.small),
          )
        else
          ..._categories.map((c) => CheckboxListTile(
                value: _selectedCats.contains(c),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedCats.add(c); } else { _selectedCats.remove(c); }
                }),
                title: Text(c, style: const TextStyle(fontSize: 15, color: Ld.ink)),
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: EdgeInsets.zero,
              )),
      ],
    );

    final buttons = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _isTesting || _isSaving ? null : _testPrint,
          icon: _isTesting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.print_outlined, size: 20),
          label: Text(_isTesting ? 'Testing...' : (l10n?.printTest ?? 'Print Test')),
        ),
        if (widget.profile != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(l10n?.deletePrinter ?? 'Delete Printer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Ld.danger,
              side: const BorderSide(color: Ld.dangerLine),
            ),
          ),
        ],
      ],
    );

    final bottom = 32 + Ld.navInset(context);

    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: widget.isEditing ? widget.profile!.name : (l10n?.addPrinter ?? 'Add Printer'),
        actions: [
          if (_isSaving)
            const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            )
          else
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: Ld.gold,
                foregroundColor: Ld.navy,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Text(l10n?.save ?? 'Save'),
            ),
        ],
      ),
      body: tablet
          ? SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 20, 24, bottom),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [connection, const SizedBox(height: 16), advanced],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [routing, const SizedBox(height: 20), buttons],
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
              children: [
                connection,
                const SizedBox(height: 16),
                advanced,
                const SizedBox(height: 16),
                routing,
                const SizedBox(height: 24),
                buttons,
              ],
            ),
    );
  }

  Widget _buildSection({String? title, String? subtitle, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Ld.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Ld.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: Ld.small),
            ],
            const SizedBox(height: 10),
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
      borderRadius: BorderRadius.circular(Ld.rSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              LdIconTile(icon, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15, color: Ld.ink, height: 1.35)),
              ),
              const SizedBox(width: 8),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
