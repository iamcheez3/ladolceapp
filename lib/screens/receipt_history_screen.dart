import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'receipt_detail_screen.dart';
import '../theme/ladolce_pos_ui.dart';

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, List<Map<String, dynamic>>> _groupedReceipts = {};

  // ─── Theme Colors ──────────────────────────────────────────────────────────
  static const Color _brandNavy = LaDolcePosUi.navy;
  static const Color _cardBg       = Color(0xFFFFFFFF);
  static const Color _textDark     = Color(0xFF1A1A2E);
  static const Color _textSub      = Color(0xFF6B7280);
  static const Color _dateLabel    = Color(0xFF9CA3AF);
  static const Color _iconCash     = Color(0xFF22C55E);
  static const Color _iconBank     = Color(0xFF3B82F6);
  static const Color _iconDefault  = Color(0xFF6B7280);
  static const Color _iconCashBg   = Color(0xFFDCFCE7);
  static const Color _iconBankBg   = Color(0xFFDBEAFE);
  static const Color _iconDefBg    = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final history = await _apiService.fetchReceiptHistory();

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (var receipt in history) {
        String dateStr = receipt['date_order'] ?? '';
        String dayKey  = 'Unknown Date';

        if (dateStr.isNotEmpty) {
          try {
            final dt      = DateTime.parse(dateStr).toLocal();
            final now     = DateTime.now();
            final today   = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final dateOnly  = DateTime(dt.year, dt.month, dt.day);

            if (dateOnly == today) {
              dayKey = 'TODAY';
            } else if (dateOnly == yesterday) {
              dayKey = 'YESTERDAY';
            } else {
              // e.g. "APRIL 20, 2026"
              dayKey = DateFormat('MMMM d, yyyy').format(dt).toUpperCase();
            }
          } catch (_) {}
        }

        grouped.putIfAbsent(dayKey, () => []).add(receipt);
      }

      if (mounted) {
        setState(() {
          _groupedReceipts = grouped;
          _isLoading       = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading    = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ─── Payment helpers ───────────────────────────────────────────────────────
  IconData _getPaymentIcon(String method) {
    method = method.toLowerCase();
    if (method.contains('cash'))                          return Icons.point_of_sale_rounded;
    if (method.contains('bank') || method.contains('card')) return Icons.credit_card_rounded;
    return Icons.receipt_long_rounded;
  }

  Color _getIconColor(String method) {
    method = method.toLowerCase();
    if (method.contains('cash'))                            return _iconCash;
    if (method.contains('bank') || method.contains('card')) return _iconBank;
    return _iconDefault;
  }

  Color _getIconBg(String method) {
    method = method.toLowerCase();
    if (method.contains('cash'))                            return _iconCashBg;
    if (method.contains('bank') || method.contains('card')) return _iconBankBg;
    return _iconDefBg;
  }

  String _formatAmount(dynamic raw) {
    final amount = double.tryParse(raw.toString()) ?? 0.0;
    // Format with no decimal if whole number, otherwise 2 dp
    if (amount == amount.truncateToDouble()) {
      return 'K${NumberFormat('#,###').format(amount.toInt())}';
    }
    return 'K${NumberFormat('#,##0.00').format(amount)}';
  }

  /// Format the duration a customer stayed (opened_at to date_paid).
  String? _formatVisitDuration(Map<String, dynamic> receipt) {
    try {
      final openedStr = receipt['date_order']?.toString() ?? '';
      final paidStr   = receipt['date_paid']?.toString()  ?? '';
      if (openedStr.isEmpty || paidStr.isEmpty) return null;
      final opened = DateTime.parse(openedStr);
      final paid   = DateTime.parse(paidStr);
      final diff   = paid.difference(opened);
      if (diff.inMinutes < 1) return null; // instant — don't show
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    } catch (_) {
      return null;
    }
  }

  void _showReceiptDetails(int orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptDetailScreen(orderId: orderId)),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandNavy,
      appBar: AppBar(
        backgroundColor: _brandNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Receipts History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
              ? _buildError()
              : _groupedReceipts.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchHistory,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _textDark),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        'No paid receipts found.',
        style: TextStyle(fontSize: 16, color: _dateLabel),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _groupedReceipts.length,
      itemBuilder: (context, index) {
        final dateKey = _groupedReceipts.keys.elementAt(index);
        final receipts = _groupedReceipts[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _dateLabel,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // ── White Card Container ─────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: List.generate(receipts.length, (i) {
                  final receipt       = receipts[i];
                  final paymentMethod = receipt['payment_method'] ?? 'Unknown';
                  final isLast        = i == receipts.length - 1;

                  String timeStr = '';
                  if (receipt['date_order'] != null) {
                    try {
                      final dt = DateTime.parse(receipt['date_order']).toLocal();
                      timeStr  = DateFormat('h:mma').format(dt);
                    } catch (_) {}
                  }

                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _showReceiptDetails(receipt['id']),
                        borderRadius: BorderRadius.vertical(
                          top:    i == 0 ? const Radius.circular(16) : Radius.zero,
                          bottom: isLast ? const Radius.circular(16) : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getIconBg(paymentMethod),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getPaymentIcon(paymentMethod),
                                  color: _getIconColor(paymentMethod),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Amount + ref / time
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatAmount(receipt['amount_total']),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _textDark,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(receipt['name'] ?? receipt['order_reference'] ?? '').toString()} · $timeStr',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textSub,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Right side: duration / unsynced / chevron
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Visit duration chip
                                  Builder(builder: (_) {
                                    final dur = _formatVisitDuration(receipt);
                                    if (dur == null) return const SizedBox(height: 0);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488)
                                            .withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '⏱ $dur',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0D9488),
                                        ),
                                      ),
                                    );
                                  }),
                                  Builder(builder: (_) {
                                    final offline = receipt['offline'] == true ||
                                        receipt['synced'] == false ||
                                        (receipt['id'] is int &&
                                            (receipt['id'] as int) < 0);
                                    if (!offline) return const SizedBox(height: 0);
                                    return const Text(
                                      'Unsynced',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange,
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 6),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _dateLabel,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Divider between items (not after last)
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 68,
                          endIndent: 0,
                          color: Colors.grey.shade100,
                        ),
                    ],
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}