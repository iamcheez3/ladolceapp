import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/ladolce_pos_ui.dart';

class BillTemplateSettingsScreen extends StatefulWidget {
  const BillTemplateSettingsScreen({super.key});

  @override
  State<BillTemplateSettingsScreen> createState() =>
      _BillTemplateSettingsScreenState();
}

class _BillTemplateSettingsScreenState extends State<BillTemplateSettingsScreen> {
  static const _navy = LaDolcePosUi.navy;
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _billTemplates = const [];
  List<Map<String, dynamic>> _receiptTemplates = const [];
  List<Map<String, dynamic>> _refundTemplates = const [];
  List<Map<String, dynamic>> _kitchenTemplates = const [];

  int? _selectedBillId;
  int? _selectedReceiptId;
  int? _selectedRefundId;
  int? _selectedKitchenId;

  int? _toId(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fast path: cached data (instant UI), then refresh from network.
      final bill = await _api.fetchBillTemplates(type: 'bill', forceRefresh: false);
      final receipt = await _api.fetchBillTemplates(type: 'receipt', forceRefresh: false);
      final refund = await _api.fetchBillTemplates(type: 'refund', forceRefresh: false);
      final kitchen = await _api.fetchBillTemplates(type: 'kitchen', forceRefresh: false);

      final selectedBill = await _api.fetchBillTemplate(type: 'bill', forceRefresh: false);
      final selectedReceipt = await _api.fetchBillTemplate(type: 'receipt', forceRefresh: false);
      final selectedRefund = await _api.fetchBillTemplate(type: 'refund', forceRefresh: false);
      final selectedKitchen = await _api.fetchBillTemplate(type: 'kitchen', forceRefresh: false);

      if (!mounted) return;
      setState(() {
        _billTemplates = bill;
        _receiptTemplates = receipt;
        _refundTemplates = refund;
        _kitchenTemplates = kitchen;
        _selectedBillId = _toId(selectedBill['id']);
        _selectedReceiptId = _toId(selectedReceipt['id']);
        _selectedRefundId = _toId(selectedRefund['id']);
        _selectedKitchenId = _toId(selectedKitchen['id']);
        _loading = false;
      });

      // Background refresh (updates cache silently).
      Future(() async {
        try {
          await _api.fetchBillTemplates(type: 'bill', forceRefresh: true);
          await _api.fetchBillTemplates(type: 'receipt', forceRefresh: true);
          await _api.fetchBillTemplates(type: 'refund', forceRefresh: true);
          await _api.fetchBillTemplates(type: 'kitchen', forceRefresh: true);
          await _api.fetchBillTemplate(type: 'bill', forceRefresh: true);
          await _api.fetchBillTemplate(type: 'receipt', forceRefresh: true);
          await _api.fetchBillTemplate(type: 'refund', forceRefresh: true);
          await _api.fetchBillTemplate(type: 'kitchen', forceRefresh: true);
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await _api.setBranchBillTemplates(
        billTemplateId: _selectedBillId,
        receiptTemplateId: _selectedReceiptId,
        refundTemplateId: _selectedRefundId,
        kitchenTemplateId: _selectedKitchenId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved template settings.')),
      );
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Widget _dropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: value,
          items: items
              .map(
                (t) => DropdownMenuItem<int>(
                  value: _toId(t['id']),
                  child: Text((t['name'] ?? '').toString()),
                ),
              )
              .toList(),
          onChanged: _loading ? null : onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Templates'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _dropdown(
                      label: 'Bill (pre-receipt)',
                      items: _billTemplates,
                      value: _selectedBillId,
                      onChanged: (v) => setState(() => _selectedBillId = v),
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      label: 'Receipt (paid)',
                      items: _receiptTemplates,
                      value: _selectedReceiptId,
                      onChanged: (v) => setState(() => _selectedReceiptId = v),
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      label: 'Refund / Void',
                      items: _refundTemplates,
                      value: _selectedRefundId,
                      onChanged: (v) => setState(() => _selectedRefundId = v),
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      label: 'Kitchen / Order ticket',
                      items: _kitchenTemplates,
                      value: _selectedKitchenId,
                      onChanged: (v) => setState(() => _selectedKitchenId = v),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tip: Duplicate a standard template in Odoo, change the name and text, then select it here.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
    );
  }
}

