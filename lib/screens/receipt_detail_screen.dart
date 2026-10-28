import 'package:flutter/material.dart';
import '../utils/bilingual_name.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ld.dart';
import '../utils/money.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final int orderId;

  /// Shown inside the tablet receipts split view instead of as its own
  /// page: no header, and after a refund [onRefunded] runs instead of
  /// popping the route.
  final bool embedded;
  final VoidCallback? onRefunded;

  const ReceiptDetailScreen({
    super.key,
    required this.orderId,
    this.embedded = false,
    this.onRefunded,
  });

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

  /// Width of the paper receipt.
  static const double _paperWidth = 440;

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
      _snack(
        AppLocalizations.of(context)?.noPrinterConfiguredSettings ??
            'No printer configured. Set up a printer in Settings first.', Colors.orange);
      return;
    }
    setState(() => _isActionLoading = true);
    try {
      final qn = (_receiptData?['queue_number'] ?? 0).toInt();
      final ok = await printerService
          .printReceiptFromRawData(_receiptData!, queueNumber: qn)
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      _snack(ok ? (AppLocalizations.of(context)?.receiptReprinted ?? '🖨️ Receipt reprinted!') : (AppLocalizations.of(context)?.printerErrorCheckConnection ?? 'Printer error. Check connection.'), ok ? Colors.green : Colors.red);
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
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: Ld.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.confirmRefund ?? 'Confirm Refund',
                style: Ld.title(19, color: Ld.ink),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will cancel order ${_receiptData?['order_reference'] ?? ''} and reverse any loyalty points.',
                style: Ld.body,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.adminPin ?? 'Admin PIN',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Ld.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)?.refund ?? 'Refund'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (pinCtrl.text.trim().isEmpty) {
      _snack(AppLocalizations.of(context)?.adminPinIsRequired ?? 'Admin PIN is required.', Colors.orange);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _apiService.refundOrder(
        orderId: widget.orderId,
        adminPin: pinCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _isRefunded = true;
          _isActionLoading = false;
        });
        // Best-effort: print refund bill immediately after refund.
        if (printerService.isConfigured) {
          try {
            Map<String, dynamic>? tpl;
            try {
              tpl = await _apiService.fetchBillTemplate(type: 'refund');
            } catch (_) {}
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

        _snack('✅ Order refunded successfully.', Colors.green);
        // Go back to history after a short delay so the snack is visible
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          if (widget.embedded) {
            widget.onRefunded?.call(); // the list beside it refreshes
          } else {
            Navigator.pop(context, true); // true = list should refresh
          }
        }
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
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? _buildError()
            : _buildContent();
    if (widget.embedded) {
      return ColoredBox(color: Ld.ground, child: body);
    }
    return Scaffold(
      appBar: LdHeader(
        title: (_receiptData?['order_reference'] ?? 'Receipt Details').toString(),
      ),
      backgroundColor: Ld.ground,
      body: body,
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LdIconTile(Icons.error_outline_rounded, size: 64, background: Ld.dangerWash, color: Ld.danger),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: Ld.body.copyWith(color: Ld.danger)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchReceipt,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final paper = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPaper(_receiptData!),
        const LdTicketEdge(height: 12),
      ],
    );

    if (widget.embedded) {
      // Tablet: the buttons sit right under the paper.
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + Ld.navInset(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _paperWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                paper,
                if (!_isRefunded) ...[
                  const SizedBox(height: 16),
                  _buildActions(),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Phone: the paper scrolls, the buttons stay above the navigation bar.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _paperWidth),
                child: paper,
              ),
            ),
          ),
        ),
        if (!_isRefunded)
          Container(
            decoration: const BoxDecoration(
              color: Ld.surface,
              border: Border(top: BorderSide(color: Ld.line)),
            ),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + Ld.navInset(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildActions(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    final l10n = AppLocalizations.of(context);
    if (_isActionLoading) {
      return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
    }
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Ld.rMd)));
    return Row(
      children: [
        // Reprint
        Expanded(
          child: FilledButton.icon(
            onPressed: _reprintReceipt,
            icon: const Icon(Icons.print_outlined),
            label: Text(
              l10n?.reprintReceipt ?? 'Reprint Receipt',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Ld.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
              shape: shape,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Refund
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showRefundDialog,
            icon: const Icon(Icons.undo_rounded),
            label: Text(
              l10n?.refundOrder ?? 'Refund Order',
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Ld.surface,
              foregroundColor: Ld.danger,
              side: const BorderSide(color: Ld.dangerLine),
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
              shape: shape,
            ),
          ),
        ),
      ],
    );
  }

  /// The receipt drawn as the printed paper, in the receipt font.
  Widget _buildPaper(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context);
    final currency = data['currency']?.toString() ?? 'LAK';
    final lines = (data['lines'] as List?) ?? const [];
    final discount = (data['amount_discount'] as num?)?.toDouble() ?? 0;
    const paperText = TextStyle(fontFamily: Ld.serif, fontSize: 15, color: Ld.ink, height: 1.35);

    return Container(
      decoration: const BoxDecoration(
        color: Ld.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: DefaultTextStyle.merge(
        style: paperText,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Refunded badge ────────────────────────────────
            if (_isRefunded)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: Ld.card(radius: Ld.rSm, color: Ld.dangerWash, border: Ld.dangerLine),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: Ld.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.thisOrderHasBeenRefunded ?? 'This order has been refunded',
                        style: const TextStyle(fontFamily: Ld.sans, color: Ld.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Header ────────────────────────────────────────
            Text(
              (data['order_reference'] ?? (l10n?.receipt ?? 'Receipt')).toString(),
              style: Ld.title(22),
            ),
            const SizedBox(height: 6),

            // ── Meta ──────────────────────────────────────────
            _metaRow(l10n?.dateColon ?? 'Date:', (data['date_order'] ?? '').toString()),
            _metaRow(l10n?.cashierColon ?? 'Cashier:', (data['cashier'] ?? (l10n?.unknown ?? 'Unknown')).toString()),
            if ((data['table']?.toString() ?? '').isNotEmpty)
              _metaRow(l10n?.tableColon ?? 'Table:', data['table'].toString()),
            _metaRow(l10n?.paymentColon ?? 'Payment:', (data['payment_method'] ?? (l10n?.unknown ?? 'Unknown')).toString()),

            const _DashedLine(),

            // ── Items list ────────────────────────────────────
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${line['qty']}× ${bilingualName(line, fallback: l10n?.item ?? 'Item')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$currency ${money((line['subtotal'] as num?)?.toDouble() ?? 0.0)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

            const _DashedLine(),

            // ── Discount ───────────────────────────────────────
            if (discount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.discount ?? 'Discount',
                        style: const TextStyle(color: Ld.danger),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '-$currency ${money(data['amount_discount'] as num)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Ld.danger),
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
                    l10n?.totalAmount ?? 'Total Amount',
                    style: Ld.title(19, color: Ld.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$currency ${money(data['amount_total'] as num)}',
                      style: Ld.price(24),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: Ld.sans, color: Ld.muted, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: Ld.sans, fontWeight: FontWeight.w500, fontSize: 14, color: Ld.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed rule between receipt sections, like the printed slip.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: CustomPaint(painter: _DashPainter()),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Ld.faint
      ..strokeWidth = 1;
    const dash = 4.0, gap = 3.0;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}
