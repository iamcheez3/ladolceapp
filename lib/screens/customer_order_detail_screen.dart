import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../utils/localized_name.dart';
import '../utils/l10n_ext.dart';

/// Full-screen order receipt / detail (customer self-order) — matches app reference styling.
class CustomerOrderDetailScreen extends StatelessWidget {
  const CustomerOrderDetailScreen({
    super.key,
    required this.item,
    required this.api,
    this.onRefresh,
  });

  static const Color _headerNavy = Color(0xFF001460);
  static const Color _labelMuted = Color(0xFF526684);
  static const Color _lineMuted = Color(0xFFCBD5E1);

  final Map<String, dynamic> item;
  final ApiService api;
  final Future<void> Function()? onRefresh;

  String _statusLabel(BuildContext context, String rawState, String paymentMethod, {String? deliveryStatus}) {
    final ds = (deliveryStatus ?? '').toLowerCase().trim();
    if (ds == 'delivered') return context.l10n.delivered;
    if (rawState == 'waiting_transfer_review') {
      return context.l10n.waitingReview;
    }
    if (rawState == 'draft' &&
        paymentMethod.toLowerCase().contains('transfer')) {
      return context.l10n.statusPreparing;
    }
    if (rawState == 'draft') return context.l10n.confirmed;
    if (rawState == 'paid') return context.l10n.complete;
    if (rawState == 'cancelled') return context.l10n.cancelled;
    return rawState.isEmpty ? '-' : rawState.toUpperCase();
  }

  bool _isPaidState(String s) {
    return s == 'paid';
  }

  @override
  Widget build(BuildContext context) {
    final proofPath = item['proof_image_path']?.toString() ?? '';
    final proofUrl = item['transfer_proof_url']?.toString() ?? '';
    final hasLocalProof = proofPath.isNotEmpty;
    final hasServerProof = proofUrl.isNotEmpty;
    // A slip only counts as delivered once the backend holds it — a local file
    // means the customer picked it, not that the store ever received it.
    final proofWaiting =
        !hasServerProof && (item['proof_pending'] == true || hasLocalProof);
    final lines = ((item['lines'] as List?) ?? const []).cast<dynamic>();
    final rawState = (item['state'] ?? '').toString();
    final payMethod = (item['payment_method'] ?? 'Unknown').toString();
    final name = item['name']?.toString() ?? 'Order';
    final amount =
        double.tryParse((item['amount_total'] ?? 0).toString()) ?? 0.0;
    final dateStr = (item['date_order'] ?? '').toString();
    final date = DateTime.tryParse(dateStr);
    final dateFmt = date != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal())
        : (dateStr.isNotEmpty ? dateStr : '-');

    return Scaffold(
      backgroundColor: _headerNavy,
      appBar: AppBar(
        backgroundColor: _headerNavy,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        centerTitle: true,
        title: const Text(
          'LaDolce',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: onRefresh == null
                  ? null
                  : () async {
                      await onRefresh!();
                    },
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.refresh, size: 22),
            ),
          ),
        ],
      ),
      body: ColoredBox(
        color: _headerNavy,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _summaryRow(context.l10n.amount, '₭${amount.toStringAsFixed(2)}', boldValue: true),
                      const SizedBox(height: 8),
                      _summaryRow(context.l10n.payment, payMethod),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.status,
                            style: TextStyle(
                              color: _labelMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          _statusPill(
                            _statusLabel(
                              context,
                              rawState,
                              payMethod,
                              deliveryStatus: item['delivery_status']?.toString(),
                            ),
                            positive: _isPaidState(rawState) ||
                                rawState == 'draft' ||
                                item['delivery_status']?.toString().toLowerCase().trim() == 'delivered',
                          ),
                        ],
                      ),
                      if (dateFmt != '-') ...[
                        const SizedBox(height: 8),
                        _summaryRow(context.l10n.date, dateFmt),
                      ],
                      if (hasLocalProof || hasServerProof) ...[
                        const SizedBox(height: 22),
                        _sectionTitle(context.l10n.transferProof),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          // Show what the store can actually see when it has
                          // it; the local file is only a stand-in until then.
                          child: !hasServerProof
                              ? Image.file(
                                  File(proofPath),
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stack) =>
                                      const SizedBox.shrink(),
                                )
                              : FutureBuilder<List<dynamic>>(
                                  future: Future.wait<dynamic>([
                                    api.resolveMediaUrlAsync(proofUrl),
                                    api.buildImageHeaders(),
                                  ]),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox(
                                        height: 220,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    final resolved =
                                        (snapshot.data![0] as String?) ?? '';
                                    final headers =
                                        (snapshot.data![1] as Map<String, String>?) ?? const {};
                                    if (resolved.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Image.network(
                                      resolved,
                                      headers: headers,
                                      height: 220,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stack) =>
                                          const SizedBox.shrink(),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 10),
                        _ProofDeliveryStatus(
                          delivered: hasServerProof,
                          waiting: proofWaiting,
                          api: api,
                          onRefresh: onRefresh,
                        ),
                      ],
                      const SizedBox(height: 22),
                      const Divider(color: _lineMuted, height: 1, thickness: 1),
                      const SizedBox(height: 14),
                      _sectionTitle(context.l10n.orderItems),
                      const SizedBox(height: 12),
                      if (lines.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              context.l10n.noLineItems,
                              style: TextStyle(
                                color: _labelMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._buildLineWidgets(lines),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLineWidgets(List<dynamic> lines) {
    final out = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i] as Map<dynamic, dynamic>;
      final qty =
          double.tryParse((line['qty'] ?? 0).toString()) ?? 0;
      final subtotal =
          double.tryParse((line['subtotal'] ?? 0).toString()) ?? 0.0;
      final productName = localizedLineName(line);
      final isLast = i == lines.length - 1;

      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Qty: ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}',
                      style: const TextStyle(
                        color: _labelMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₭${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      );
      if (!isLast) {
        out.add(const _DottedRule());
        out.add(const SizedBox(height: 12));
      }
    }
    return out;
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool boldValue = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _labelMuted,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontWeight: boldValue ? FontWeight.w900 : FontWeight.w600,
              fontSize: boldValue ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: _labelMuted,
      ),
    );
  }

  Widget _statusPill(String text, {required bool positive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFDCF4E0) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: positive ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DottedRule extends StatelessWidget {
  const _DottedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 1),
          painter: _DottedLinePainter(
            color: const Color(0xFFCBD5E1),
          ),
        );
      },
    );
  }
}

/// Tells the customer whether the transfer slip actually reached the store,
/// and offers a manual resend when the automatic retries have not got through.
///
/// Without this the screen showed the local file either way, so a slip that
/// never left the phone looked identical to one the POS could see.
class _ProofDeliveryStatus extends StatefulWidget {
  const _ProofDeliveryStatus({
    required this.delivered,
    required this.waiting,
    required this.api,
    this.onRefresh,
  });

  final bool delivered;
  final bool waiting;
  final ApiService api;
  final Future<void> Function()? onRefresh;

  @override
  State<_ProofDeliveryStatus> createState() => _ProofDeliveryStatusState();
}

class _ProofDeliveryStatusState extends State<_ProofDeliveryStatus> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    var uploaded = 0;
    try {
      uploaded = await widget.api.syncPendingTransferProofs(force: true);
    } catch (e) {
      debugPrint('[Proof] manual resend failed: $e');
    }
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uploaded > 0
              ? 'Transfer slip sent to the store.'
              : 'Could not send the slip yet. Please check your connection '
                    'and try again.',
        ),
        backgroundColor: uploaded > 0 ? Colors.green : Colors.red,
      ),
    );
    if (uploaded > 0) await widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.delivered) {
      return const Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF059669)),
          SizedBox(width: 6),
          Text(
            'Received by the store',
            style: TextStyle(
              color: Color(0xFF059669),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    if (!widget.waiting) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFB45309)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Not received by the store yet',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _sending ? null : _resend,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send slip to the store again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CustomerOrderDetailScreen._headerNavy,
              side: const BorderSide(
                color: CustomerOrderDetailScreen._headerNavy,
              ),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dash < size.width) ? x + dash : size.width;
      canvas.drawLine(Offset(x, 0), Offset(end, 0), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
