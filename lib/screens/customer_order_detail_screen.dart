import 'dart:io';
import '../utils/bilingual_name.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

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

  String _statusLabel(String rawState, String paymentMethod, {String? deliveryStatus}) {
    final ds = (deliveryStatus ?? '').toLowerCase().trim();
    if (ds == 'delivered') return 'DELIVERED';
    if (rawState == 'waiting_transfer_review') {
      return 'Waiting review';
    }
    if (rawState == 'draft' &&
        paymentMethod.toLowerCase().contains('transfer')) {
      return 'Preparing';
    }
    if (rawState == 'draft') return 'Confirmed';
    if (rawState == 'paid') return 'COMPLETE';
    if (rawState == 'cancelled') return 'CANCELLED';
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
    final lines = ((item['lines'] as List?) ?? const []).cast<dynamic>();
    final rawState = (item['state'] ?? '').toString();
    final payMethod = (item['payment_method'] ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown')).toString();
    final name = item['name']?.toString() ?? (AppLocalizations.of(context)?.order ?? 'Order');
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
                      _summaryRow('Amount', '₭${amount.toStringAsFixed(2)}', boldValue: true),
                      const SizedBox(height: 8),
                      _summaryRow('Payment', payMethod),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalizations.of(context)?.status ?? (AppLocalizations.of(context)?.status ?? 'Status'),
                            style: TextStyle(
                              color: _labelMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          _statusPill(
                            _statusLabel(
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
                        _summaryRow('Date', dateFmt),
                      ],
                      if (hasLocalProof || hasServerProof) ...[
                        const SizedBox(height: 22),
                        _sectionTitle('TRANSFER PROOF'),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: hasLocalProof
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
                      ],
                      const SizedBox(height: 22),
                      const Divider(color: _lineMuted, height: 1, thickness: 1),
                      const SizedBox(height: 14),
                      _sectionTitle('ORDER ITEMS'),
                      const SizedBox(height: 12),
                      if (lines.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(AppLocalizations.of(context)?.noLineItems ?? (AppLocalizations.of(context)?.noLineItems ?? 'No line items'),
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
      final productName = bilingualName(line, fallback: 'Item');
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
