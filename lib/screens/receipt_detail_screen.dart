import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../utils/localized_name.dart';
import '../utils/l10n_ext.dart';
import '../utils/money.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final int orderId;

  const ReceiptDetailScreen({super.key, required this.orderId});

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _receiptData;
  bool _isRefunded = false;

  static const Color _navy = Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
    _fetchReceipt();
  }

  Future<void> _fetchReceipt() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.fetchOrderReceipt(widget.orderId);
      if (mounted) setState(() { _receiptData = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  // ── Reprint ────────────────────────────────────────────────────────────────
  Future<void> _reprintReceipt() async {
    if (_receiptData == null) return;
    if (!printerService.isConfigured) {
      _snack(context.l10n.noPrinterConfiguredSettings, Colors.orange);
      return;
    }
    setState(() => _isActionLoading = true);
    try {
      final qn = (_receiptData?['queue_number'] ?? 0).toInt();
      final ok = await printerService
          .printReceiptFromRawData(_receiptData!, queueNumber: qn)
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      _snack(ok ? '🖨️ Receipt reprinted!' : 'Printer error. Check connection.', ok ? Colors.green : Colors.red);
    } catch (e) {
      _snack('Printer error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // ── Refund ─────────────────────────────────────────────────────────────────
  Future<void> _showRefundDialog() async {
    if (_isRefunded) return;
    final pinCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.undo_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(context.l10n.confirmRefund, style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will cancel order ${_receiptData?['order_reference'] ?? ''} and reverse any loyalty points.',
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: context.l10n.adminPin,
                prefixIcon: const Icon(Icons.lock_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.refund),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (pinCtrl.text.trim().isEmpty) {
      // Captured before the first await: reading it off `context` afterwards is unsafe.
      final l10n = context.l10n;
      _snack(l10n.adminPinIsRequired, Colors.orange);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _apiService.refundOrder(
        orderId: widget.orderId,
        adminPin: pinCtrl.text.trim(),
      );
      if (mounted) {
        // Captured before any await: reading it off `context` afterwards is unsafe.
        final l10n = context.l10n;
        setState(() {
          _isRefunded = true;
          _isActionLoading = false;
        });
        // Best-effort: print refund bill immediately after refund.
        if (printerService.isConfigured) {
          try {
            final tpl = await _apiService.fetchBillTemplateForPrint('refund');
            final headerText = (tpl?['header_text'] ?? '').toString();
            final footerText = (tpl?['footer_text'] ?? '').toString();

            final latest = await _apiService.fetchOrderReceipt(widget.orderId);
            final qn = (latest['queue_number'] ?? 0).toInt();
            await printerService
                .printRefundFromRawData(
                  latest,
                  headerText: headerText,
                  footerText: footerText,
                  queueNumber: qn,
                )
                .timeout(const Duration(seconds: 25), onTimeout: () => false);
          } catch (_) {
            // Do not block refund success if printing fails
          }
        }

        _snack(l10n.orderRefundedSuccessfully, Colors.green);
        // Go back to history after a short delay so the snack is visible
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context, true); // true = list should refresh
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
      }
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_receiptData?['order_reference'] ?? 'Receipt Details'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchReceipt, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final data = _receiptData!;
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Refunded badge ────────────────────────────────
                      if (_isRefunded)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text(context.l10n.thisOrderHasBeenRefunded, style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),

                      // ── Header ────────────────────────────────────────
                      Text(
                        data['order_reference'] ?? context.l10n.receipt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // ── Meta ──────────────────────────────────────────
                      _metaRow(context.l10n.dateColon, data['date_order'] ?? ''),
                      _metaRow(context.l10n.cashierColon, data['cashier'] ?? 'Unknown'),
                      if ((data['table']?.toString() ?? '').isNotEmpty)
                        _metaRow(context.l10n.tableColon, data['table'].toString()),
                      _metaRow(context.l10n.paymentColon, data['payment_method'] ?? 'Unknown'),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // ── Items header ──────────────────────────────────
                      Row(
                        children: [
                          Expanded(flex: 3, child: Text(context.l10n.item, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          Expanded(flex: 1, child: Text(context.l10n.qty, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                          Expanded(flex: 2, child: Text(context.l10n.total, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Items list ────────────────────────────────────
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (data['lines'] as List).length,
                        itemBuilder: (context, index) {
                          final line = data['lines'][index];
                          final subtotal = (line['subtotal'] as num?)?.toDouble() ?? 0.0;
                          final currency = data['currency']?.toString() ?? 'LAK';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(localizedLineName(line),
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text('${line['qty']}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey[700])),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    formatKip(subtotal, symbol: '$currency '),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // ── Discount ───────────────────────────────────────
                      if (((data['amount_discount'] as num?)?.toDouble() ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.discount,
                                  style: TextStyle(fontSize: 16, color: Colors.red),
                                ),
                              ),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '-${formatKip(data['amount_discount'] as num, symbol: '${data['currency'] ?? 'LAK'} ')}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Total ─────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.totalAmount,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                formatKip(data['amount_total'] as num, symbol: '${data['currency'] ?? 'LAK'} '),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _navy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Floating action bar ────────────────────────────────────────────
        if (!_isRefunded)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _isActionLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      // Reprint
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _reprintReceipt,
                          icon: const Icon(Icons.print_outlined),
                          label: Text(context.l10n.reprintReceipt),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Refund
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showRefundDialog,
                          icon: const Icon(Icons.undo_rounded),
                          label: Text(context.l10n.refundOrder),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
