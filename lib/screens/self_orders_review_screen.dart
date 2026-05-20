import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class SelfOrdersReviewScreen extends StatefulWidget {
  const SelfOrdersReviewScreen({super.key});

  @override
  State<SelfOrdersReviewScreen> createState() => _SelfOrdersReviewScreenState();
}

class _SelfOrdersReviewScreenState extends State<SelfOrdersReviewScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  // Track which cards have their item list expanded
  final Set<dynamic> _expandedOrders = {};

  static const _navy = Color(0xFF1E3A8A);
  static const _navyLight = Color(0xFF2D55C0);
  static const _surface = Color(0xFFF8FAFF);
  static const _cardBg = Colors.white;
  static const _divider = Color(0xFFE8EDF5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.fetchPendingSelfOrders();
      if (!mounted) return;
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmOrder(Map<String, dynamic> order) async {
    final orderId = order['id'];
    if (orderId == null) return;
    try {
      await _apiService.confirmSelfOrderTransfer(orderId as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer confirmed. Order moved to Open Tickets.'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Confirm failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectOrder(Map<String, dynamic> order) async {
    final orderId = order['id'];
    if (orderId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Order?'),
        content: Text(
            'Are you sure you want to reject and cancel order ${order['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.rejectSelfOrder(orderId as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order rejected and cancelled.'),
          backgroundColor: Colors.orange,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openProofDialog(Map<String, dynamic> order) {
    final proofUrl = (order['transfer_proof_url'] ?? '').toString();
    final title = 'Proof - ${order['name'] ?? ''}';
    final proofFuture = proofUrl.isEmpty
        ? Future.value(const <dynamic>['', <String, String>{}])
        : Future.wait<dynamic>([
            _apiService.resolveMediaUrlAsync(proofUrl),
            _apiService.buildImageHeaders(),
          ]);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>>(
                future: proofFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final absUrl = (snapshot.data![0] as String?) ?? '';
                  final headers =
                      (snapshot.data![1] as Map<String, String>?) ?? const {};
                  if (absUrl.isEmpty) return const Text('No proof image uploaded');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 420,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 8,
                          child: GestureDetector(
                            onDoubleTap: () => _openProofFullScreen(
                              title: title,
                              imageUrl: absUrl,
                              headers: headers,
                            ),
                            child: Image.network(
                              absUrl,
                              headers: headers,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (_, _, _) =>
                                  const Text('Cannot load proof image'),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _openProofFullScreen(
                            title: title,
                            imageUrl: absUrl,
                            headers: headers,
                          ),
                          icon: const Icon(Icons.zoom_out_map),
                          label: const Text('Fullscreen'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _orderPhoneLine(Map<String, dynamic> order) {
    final p = (order['customer_phone'] ??
            order['phone'] ??
            order['mobile'] ??
            order['partner_phone'] ??
            '')
        .toString()
        .trim();
    return p.isEmpty ? '—' : p;
  }

  void _openProofFullScreen({
    required String title,
    required String imageUrl,
    required Map<String, String> headers,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          title: Text(title, style: const TextStyle(fontSize: 16)),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 12,
            child: Image.network(
              imageUrl,
              headers: headers,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'Cannot load proof image',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatKip(dynamic value) {
    final num = double.tryParse(value?.toString() ?? '0') ?? 0;
    final int = num.toInt();
    // Basic thousands-separator formatter
    final str = int.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '₭$str';
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Self Orders Review',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _orders.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: _navy,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 72,
                color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No pending self orders',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );

  Widget _buildList() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _OrderCard(
            order: order,
            expanded: _expandedOrders.contains(order['id']),
            onToggleExpand: () => setState(() {
              final id = order['id'];
              if (_expandedOrders.contains(id)) {
                _expandedOrders.remove(id);
              } else {
                _expandedOrders.add(id);
              }
            }),
            formatKip: _formatKip,
            orderPhoneLine: _orderPhoneLine,
            onConfirm: () => _confirmOrder(order),
            onReject: () => _rejectOrder(order),
            onViewProof: () => _openProofDialog(order),
          );
        },
      );
}

// ─── Order Card ─────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.expanded,
    required this.onToggleExpand,
    required this.formatKip,
    required this.orderPhoneLine,
    required this.onConfirm,
    required this.onReject,
    required this.onViewProof,
  });

  final Map<String, dynamic> order;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final String Function(dynamic) formatKip;
  final String Function(Map<String, dynamic>) orderPhoneLine;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onViewProof;

  static const _navy = Color(0xFF1E3A8A);
  static const _divider = Color(0xFFE8EDF5);

  bool get _isPayAtStore {
    final paymentType = (order['payment_type'] ?? '').toString();
    final hasProof = order['transfer_proof_uploaded'] == true ||
        ((order['transfer_proof_url'] ?? '').toString().isNotEmpty);
    return paymentType == 'pay_at_store' ||
        (paymentType != 'transfer' && !hasProof);
  }

  @override
  Widget build(BuildContext context) {
    final lines = (order['lines'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          // ── Info row ──────────────────────────────────────────────────────
          _buildInfoSection(context),
          // ── Note section ──────────────────────────────────────────────────
          if ((order['note']?.toString() ?? '').trim().isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE8EDF5)),
            _buildNoteSection(context),
          ],
          // ── Items section ─────────────────────────────────────────────────
          if (lines.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE8EDF5)),
            _buildItemsSection(lines),
          ],
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          // ── Actions ───────────────────────────────────────────────────────
          _buildActions(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _navy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: _navy, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order['name']?.toString() ?? 'Order',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Table: ${order['table_name'] ?? '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Payment badge
          _paymentBadge(),
        ],
      ),
    );
  }

  Widget _paymentBadge() {
    if (_isPayAtStore) {
      return _Badge(
        label: 'Pay at Store',
        color: const Color(0xFF059669),
        icon: Icons.store_rounded,
      );
    }
    return _Badge(
      label: 'Bank Transfer',
      color: const Color(0xFF2D55C0),
      icon: Icons.account_balance_rounded,
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _InfoChip(
            icon: Icons.person_outline_rounded,
            label: order['customer']?.toString() ?? '-',
          ),
          const SizedBox(width: 8),
          _InfoChip(
            icon: Icons.phone_outlined,
            label: orderPhoneLine(order),
            onTap: orderPhoneLine(order) != '—'
                ? () async {
                    final phone = orderPhoneLine(order).replaceAll(RegExp(r'[^0-9+]'), '');
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Call Customer?'),
                        content: Text('Do you want to call $phone?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final url = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    }
                  }
                : null,
          ),
          const Spacer(),
          // Total amount
          Text(
            formatKip(order['amount_total'] ?? 0),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(BuildContext context) {
    final note = (order['note']?.toString() ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.amber.shade800, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Note / Pickup Time:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF451A03),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(List lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle header
        InkWell(
          onTap: onToggleExpand,
          borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu_rounded,
                    size: 16, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 6),
                Text(
                  '${lines.length} Item${lines.length == 1 ? '' : 's'} ordered',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
          ),
        ),
        // Animated item list
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          crossFadeState: expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            color: const Color(0xFFF5F7FF),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: lines.asMap().entries.map((entry) {
                final i = entry.key;
                final line = entry.value as Map<String, dynamic>? ?? {};
                return _LineRow(
                  index: i,
                  line: line,
                  formatKip: formatKip,
                  isLast: i == lines.length - 1,
                );
              }).toList(),
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildActions() {
    if (_isPayAtStore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Quick Confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Transfer payment
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewProof,
                  icon: const Icon(Icons.image_search_rounded, size: 18),
                  label: const Text('View Proof'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _navy,
                    side: const BorderSide(color: _navy),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Reject Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Line Row ────────────────────────────────────────────────────────────────

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.index,
    required this.line,
    required this.formatKip,
    required this.isLast,
  });

  final int index;
  final Map<String, dynamic> line;
  final String Function(dynamic) formatKip;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final name = line['product_name']?.toString() ?? 'Item';
    final qty = line['qty'] ?? line['quantity'] ?? 1;
    final subtotal = line['subtotal'] ??
        line['price_subtotal'] ??
        line['price_unit'] ??
        0;
    final toppings = (line['toppings'] as List?) ?? [];
    final note = line['note']?.toString() ?? '';

    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: isLast ? 4 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index circle
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'x${qty.toString()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatKip(subtotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          if (toppings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 3),
              child: Text(
                '+ ${toppings.map((t) => t['name'] ?? t.toString()).join(', ')}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: Text(
                'Note: $note',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 32),
              child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey.shade300),
            ),
        ],
      ),
    );
  }
}

// ─── Small helpers ───────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
  });
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: onTap != null ? const Color(0xFF1E3A8A) : Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: onTap != null ? const Color(0xFF1E3A8A) : Colors.grey.shade700,
            fontWeight: onTap != null ? FontWeight.bold : FontWeight.normal,
            decoration: onTap != null ? TextDecoration.underline : null,
          ),
        ),
      ],
    );

    if (onTap == null) return body;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: body,
      ),
    );
  }
}
