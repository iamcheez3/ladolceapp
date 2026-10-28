import 'dart:io';
import '../utils/bilingual_name.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../utils/money.dart';

import '../theme/ld.dart';

/// Full-screen order status / receipt (customer self-order).
class CustomerOrderDetailScreen extends StatelessWidget {
  const CustomerOrderDetailScreen({
    super.key,
    required this.item,
    required this.api,
    this.onRefresh,
  });

  final Map<String, dynamic> item;
  final ApiService api;
  final Future<void> Function()? onRefresh;

  /// Same state -> label mapping as before; labels are now sentence case and
  /// localised where a key with the same meaning exists.
  String _statusLabel(
    AppLocalizations? l10n,
    String rawState,
    String paymentMethod, {
    String? deliveryStatus,
  }) {
    final ds = (deliveryStatus ?? '').toLowerCase().trim();
    if (ds == 'delivered') return l10n?.statusDelivered ?? 'Delivered';
    // Cashier pressed Order Ready on this pickup order.
    if (ds == 'ready' && rawState != 'paid' && rawState != 'cancelled') {
      return l10n?.statusReadyPill ?? 'Ready for pickup';
    }
    if (rawState == 'waiting_transfer_review') {
      return l10n?.waitingReview ?? 'Waiting review';
    }
    if (rawState == 'draft' &&
        paymentMethod.toLowerCase().contains('transfer')) {
      return l10n?.statusPreparing ?? 'Preparing';
    }
    if (rawState == 'draft') return l10n?.confirmed ?? 'Confirmed';
    if (rawState == 'paid') return l10n?.statusComplete ?? 'Complete';
    if (rawState == 'cancelled') return l10n?.statusCancelled ?? 'Cancelled';
    return rawState.isEmpty ? '-' : rawState;
  }

  bool _isPaidState(String s) {
    return s == 'paid';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final proofPath = item['proof_image_path']?.toString() ?? '';
    final proofUrl = item['transfer_proof_url']?.toString() ?? '';
    final hasLocalProof = proofPath.isNotEmpty;
    final hasServerProof = proofUrl.isNotEmpty;
    final lines = ((item['lines'] as List?) ?? const []).cast<dynamic>();
    final rawState = (item['state'] ?? '').toString();
    final payMethod = (item['payment_method'] ?? (l10n?.unknown ?? 'Unknown')).toString();
    final name = item['name']?.toString() ?? (l10n?.order ?? 'Order');
    final amount =
        double.tryParse((item['amount_total'] ?? 0).toString()) ?? 0.0;
    final dateStr = (item['date_order'] ?? '').toString();
    final date = DateTime.tryParse(dateStr);
    final dateFmt = date != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal())
        : (dateStr.isNotEmpty ? dateStr : '-');
    final deliveryStatus = item['delivery_status']?.toString();
    final statusText = _statusLabel(
      l10n,
      rawState,
      payMethod,
      deliveryStatus: deliveryStatus,
    );
    final isCancelled = rawState == 'cancelled';
    final positive = _isPaidState(rawState) ||
        rawState == 'draft' ||
        deliveryStatus?.toLowerCase().trim() == 'delivered';

    final content = <Widget>[
      // Status steps, pulled up over the navy band like the mockup.
      Transform.translate(
        offset: const Offset(0, -18),
        child: _card(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: _buildSteps(l10n, rawState, payMethod, deliveryStatus, statusText),
        ),
      ),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow(
              l10n?.amount ?? 'Amount',
              Text(
                '₭${money(amount)}',
                textAlign: TextAlign.right,
                style: Ld.price(19),
              ),
            ),
            const SizedBox(height: 10),
            _summaryRow(l10n?.payment ?? 'Payment', _valueText(payMethod)),
            const SizedBox(height: 10),
            _summaryRow(
              l10n?.status ?? 'Status',
              _statusPill(statusText, positive: positive, cancelled: isCancelled),
            ),
            if (dateFmt != '-') ...[
              const SizedBox(height: 10),
              _summaryRow(l10n?.date ?? 'Date', _valueText(dateFmt)),
            ],
          ],
        ),
      ),
      if (hasLocalProof || hasServerProof) ...[
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(l10n?.transferProof ?? 'Transfer proof'),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(Ld.r),
                child: ColoredBox(
                  color: Ld.ground,
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
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(l10n?.orderItems ?? 'Order items'),
            const SizedBox(height: 12),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    l10n?.noLineItems ?? 'No line items',
                    style: Ld.label,
                  ),
                ),
              )
            else
              ..._buildLineWidgets(lines),
            const SizedBox(height: 4),
            const _DottedRule(),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    l10n?.total ?? 'Total',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Ld.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '₭${money(amount)}',
                    textAlign: TextAlign.right,
                    style: Ld.price(20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: name,
        subtitle: dateFmt != '-' ? dateFmt : null,
        actions: [
          LdNavIconButton(
            icon: Icons.refresh_rounded,
            tooltip: l10n?.refresh ?? 'Refresh',
            onPressed: onRefresh == null
                ? null
                : () async {
                    await onRefresh!();
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 24 + Ld.navInset(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBand(l10n, statusText, amount, payMethod, isCancelled),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navy band under the header: status in large type, total in gold.
  Widget _statusBand(
    AppLocalizations? l10n,
    String statusText,
    double amount,
    String payMethod,
    bool isCancelled,
  ) {
    return Container(
      color: Ld.navy,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      child: Column(
        children: [
          Text(
            l10n?.status ?? 'Status',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Ld.onNavyMuted),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCancelled ? Icons.cancel_outlined : Icons.receipt_long_outlined,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  statusText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ld.title(24, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₭${money(amount)}',
              style: Ld.price(38, color: Ld.gold),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            payMethod,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Ld.onNavyMuted),
          ),
        ],
      ),
    );
  }

  /// Vertical progress list derived only from state / delivery_status.
  Widget _buildSteps(
    AppLocalizations? l10n,
    String rawState,
    String payMethod,
    String? deliveryStatus,
    String statusText,
  ) {
    final ds = (deliveryStatus ?? '').toLowerCase().trim();
    if (rawState == 'cancelled') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            const LdIconTile(
              Icons.cancel_outlined,
              background: Ld.dangerWash,
              color: Ld.danger,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: LdPill(
                  statusText,
                  background: Ld.dangerWash,
                  foreground: Ld.danger,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isDelivery =
        ds == 'on_the_way' || ds == 'arrived' || ds == 'delivered';
    final labels = <String>[
      rawState == 'waiting_transfer_review'
          ? (l10n?.waitingReview ?? 'Waiting review')
          : (l10n?.statusOrderConfirmed ?? 'Order confirmed'),
      l10n?.statusPreparing ?? 'Preparing',
      isDelivery
          ? (ds == 'arrived'
              ? (l10n?.statusRiderArrived ?? 'Rider arrived')
              : (l10n?.statusOnTheWay ?? 'On the way'))
          : (l10n?.statusReadyPill ?? 'Ready for pickup'),
      isDelivery
          ? (l10n?.statusDelivered ?? 'Delivered')
          : (l10n?.statusComplete ?? 'Complete'),
    ];

    // Index of the step in progress; everything before it is done.
    int current;
    if (rawState == 'paid' || ds == 'delivered') {
      current = labels.length; // all done
    } else if (ds == 'on_the_way' || ds == 'arrived' || ds == 'ready') {
      current = 2;
    } else if (ds == 'preparing' ||
        (rawState == 'draft' && payMethod.toLowerCase().contains('transfer'))) {
      current = 1;
    } else {
      current = 0;
    }

    return Column(
      children: [
        for (var i = 0; i < labels.length; i++)
          _stepRow(
            index: i,
            label: labels[i],
            done: i < current,
            active: i == current,
            hasLine: i < labels.length - 1,
          ),
      ],
    );
  }

  Widget _stepRow({
    required int index,
    required String label,
    required bool done,
    required bool active,
    required bool hasLine,
  }) {
    final Color dotBg = done ? Ld.navy : (active ? Ld.gold : Ld.ground);
    final Color dotFg = done ? Colors.white : (active ? Ld.navy : Ld.muted);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dotBg,
                    shape: BoxShape.circle,
                    border: done || active ? null : Border.all(color: Ld.line),
                  ),
                  child: done
                      ? Icon(Icons.check_rounded, size: 16, color: dotFg)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: dotFg,
                          ),
                        ),
                ),
                if (hasLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: 20),
                      color: done ? Ld.navy : Ld.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 14),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: (done || active) ? Ld.ink : Ld.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      padding: padding,
      child: child,
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
      final qtyText = qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2);

      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$qtyText×',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.35,
                  color: Ld.muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.35,
                    color: Ld.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₭${money(subtotal)}',
                style: Ld.price(15),
              ),
            ],
          ),
        ),
      );
      if (!isLast) {
        out.add(const _DottedRule());
        out.add(const SizedBox(height: 10));
      }
    }
    return out;
  }

  Widget _valueText(String value) {
    return Text(
      value,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Ld.ink,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );
  }

  Widget _summaryRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Ld.label),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Ld.ink,
      ),
    );
  }

  Widget _statusPill(String text, {required bool positive, bool cancelled = false}) {
    if (cancelled) {
      return LdPill(
        text,
        background: Ld.dangerWash,
        foreground: Ld.danger,
        icon: Icons.cancel_outlined,
      );
    }
    return LdPill(
      text,
      background: positive ? Ld.successWash : Ld.warningWash,
      foreground: positive ? Ld.success : Ld.warning,
      icon: positive ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
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
            color: const Color(0xFFC9CFE0),
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
