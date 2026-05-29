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

  static const Color _accent = Color(0xFF0D9488);
  static const Color _iconCashBg = Color(0xFFDCFCE7);
  static const Color _iconBankBg = Color(0xFFDBEAFE);
  static const Color _iconOtherBg = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchHistory(forceRefresh: true);
  }

  Future<void> _fetchHistory({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final history =
          await _apiService.fetchReceiptHistory(forceRefresh: forceRefresh);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (var receipt in history) {
        String dateStr = (receipt['date_order'] ?? '').toString();
        if (dateStr.isEmpty) {
          dateStr = (receipt['date_paid'] ?? '').toString();
        }
        String dayKey = 'Unknown Date';

        if (dateStr.isNotEmpty) {
          try {
            final dt = DateTime.parse(dateStr).toLocal();
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final dateOnly = DateTime(dt.year, dt.month, dt.day);

            if (dateOnly == today) {
              dayKey = 'TODAY';
            } else if (dateOnly == yesterday) {
              dayKey = 'YESTERDAY';
            } else {
              dayKey = DateFormat('MMMM d, yyyy').format(dt).toUpperCase();
            }
          } catch (_) {}
        }

        grouped.putIfAbsent(dayKey, () => []).add(receipt);
      }

      if (mounted) {
        setState(() {
          _groupedReceipts = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _getPaymentAsset(String method) {
    method = method.toLowerCase();
    if (method.contains('cash')) return 'assets/images/cash.png';
    return 'assets/images/bank.png';
  }

  Color _getIconBg(String method) {
    method = method.toLowerCase();
    if (method.contains('cash')) return _iconCashBg;
    if (method.contains('bank') || method.contains('card')) return _iconBankBg;
    return _iconOtherBg;
  }

  String _formatAmount(dynamic raw) {
    final amount = double.tryParse(raw.toString()) ?? 0.0;
    if (amount == amount.truncateToDouble()) {
      return 'K${NumberFormat('#,###').format(amount.toInt())}';
    }
    return 'K${NumberFormat('#,##0.00').format(amount)}';
  }

  String? _formatVisitDuration(Map<String, dynamic> receipt) {
    try {
      final openedStr = receipt['date_order']?.toString() ?? '';
      final paidStr = receipt['date_paid']?.toString() ?? '';
      if (openedStr.isEmpty || paidStr.isEmpty) return null;
      final opened = DateTime.parse(openedStr);
      final paid = DateTime.parse(paidStr);
      final diff = paid.difference(opened);
      if (diff.inMinutes < 1) return null;
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    } catch (_) {
      return null;
    }
  }

  Future<void> _showReceiptDetails(int orderId) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReceiptDetailScreen(orderId: orderId)),
    );
    if (!mounted) return;
    if (refreshed == true) {
      await _fetchHistory(forceRefresh: true);
    }
  }

  int? _resolveReceiptId(Map<String, dynamic> receipt) {
    final raw = receipt['id'] ?? receipt['order_id'] ?? receipt['orderId'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LaDolcePosUi.surface,
      appBar: AppBar(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Receipts History',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _groupedReceipts.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
            ),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchHistory,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: LaDolcePosUi.primaryButtonStyle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.receipt_long_outlined, color: _accent.withValues(alpha: 0.5), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('No paid receipts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Completed orders will appear here',
                style: TextStyle(fontSize: 14, color: LaDolcePosUi.mutedText)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _groupedReceipts.entries.map((entry) {
          final dateKey = entry.key;
          final receipts = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Text(
                  dateKey,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LaDolcePosUi.mutedText,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
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
                  children: List.generate(receipts.length, (i) {
                    final receipt = receipts[i];
                    final paymentMethod = receipt['payment_method'] ?? 'Unknown';
                    final isLast = i == receipts.length - 1;

                    String timeStr = '';
                    if (receipt['date_order'] != null) {
                      try {
                        final dt = DateTime.parse(receipt['date_order']).toLocal();
                        timeStr = DateFormat('h:mma').format(dt);
                      } catch (_) {}
                    }

                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            final id = _resolveReceiptId(receipt);
                            if (id == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('This receipt is missing an order id. Please refresh and try again.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            _showReceiptDetails(id);
                          },
                          borderRadius: BorderRadius.vertical(
                            top: i == 0 ? Radius.circular(LaDolcePosUi.radius) : Radius.zero,
                            bottom: isLast ? Radius.circular(LaDolcePosUi.radius) : Radius.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getIconBg(paymentMethod),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Image.asset(
                                      _getPaymentAsset(paymentMethod),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatAmount(receipt['amount_total']),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A1A2E),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(receipt['name'] ?? receipt['order_reference'] ?? '').toString()} · $timeStr',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: LaDolcePosUi.mutedText,
                                        ),
                                      ),
                                      if ((receipt['amount_discount'] is num && (receipt['amount_discount'] as num) > 0) ||
                                          (receipt['amount_discount'] is double && receipt['amount_discount'] > 0))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Discount: -K${(receipt['amount_discount'] as num).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Builder(builder: (_) {
                                      final dur = _formatVisitDuration(receipt);
                                      if (dur == null) return const SizedBox.shrink();
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '⏱ $dur',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _accent,
                                          ),
                                        ),
                                      );
                                    }),
                                    Builder(builder: (_) {
                                      final offline = receipt['offline'] == true ||
                                          receipt['synced'] == false ||
                                          (receipt['id'] is int && (receipt['id'] as int) < 0);
                                      if (!offline) return const SizedBox.shrink();
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Unsynced',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange),
                                        ),
                                      );
                                    }),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: LaDolcePosUi.mutedText,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 68,
                            endIndent: 0,
                            color: LaDolcePosUi.border,
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
