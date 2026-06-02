import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'receipt_detail_screen.dart';
import '../theme/ladolce_pos_ui.dart';

/// Paginated Receipt History Screen optimized for large datasets.
///
/// Key optimizations:
/// - Lazy loading with pagination (100 initial, 50 per load more)
/// - ListView.builder for efficient rendering
/// - No UI blocking during data fetch
/// - Cached loaded receipts in memory
/// - Load More button at bottom with loading state
class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final ApiService _apiService = ApiService();
  
  // Pagination state
  final List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  
  // Pagination config
  static const int _initialLimit = 100;
  static const int _loadMoreLimit = 50;
  int _currentOffset = 0;
  
  // Prevent duplicate fetch requests
  bool _isFetching = false;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _iconCashBg = Color(0xFFDCFCE7);
  static const Color _iconBankBg = Color(0xFFDBEAFE);
  static const Color _iconOtherBg = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _fetchInitialReceipts();
  }

  /// Fetch initial batch of receipts (100)
  Future<void> _fetchInitialReceipts() async {
    if (_isFetching) return;
    _isFetching = true;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.fetchReceiptHistoryPaginated(
        limit: _initialLimit,
        offset: 0,
      );

      if (!mounted) return;

      setState(() {
        _receipts.clear();
        _receipts.addAll(result.receipts);
        _hasMore = result.hasMore;
        _currentOffset = result.receipts.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    } finally {
      _isFetching = false;
    }
  }

  /// Load more receipts (50 per call)
  Future<void> _loadMoreReceipts() async {
    if (_isFetching || _isLoadingMore || !_hasMore) return;
    _isFetching = true;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _apiService.fetchReceiptHistoryPaginated(
        limit: _loadMoreLimit,
        offset: _currentOffset,
      );

      if (!mounted) return;

      setState(() {
        _receipts.addAll(result.receipts);
        _hasMore = result.hasMore;
        _currentOffset += result.receipts.length;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      // Show error but don't clear existing data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      _isFetching = false;
    }
  }

  /// Refresh and reload from start
  Future<void> _refreshReceipts() async {
    if (_isFetching) return;
    
    setState(() {
      _currentOffset = 0;
      _hasMore = true;
    });
    
    await _fetchInitialReceipts();
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

  String _getDayKey(Map<String, dynamic> receipt) {
    String dateStr = (receipt['date_order'] ?? '').toString();
    if (dateStr.isEmpty) {
      dateStr = (receipt['date_paid'] ?? '').toString();
    }
    
    if (dateStr.isEmpty) return 'Unknown Date';
    
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(dt.year, dt.month, dt.day);

      if (dateOnly == today) return 'TODAY';
      if (dateOnly == yesterday) return 'YESTERDAY';
      return DateFormat('MMMM d, yyyy').format(dt).toUpperCase();
    } catch (_) {
      return 'Unknown Date';
    }
  }

  String _getTimeStr(Map<String, dynamic> receipt) {
    final dateStr = receipt['date_order']?.toString() ?? '';
    if (dateStr.isEmpty) return '';
    
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('h:mma').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _showReceiptDetails(int orderId) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReceiptDetailScreen(orderId: orderId)),
    );
    if (!mounted) return;
    if (refreshed == true) {
      await _refreshReceipts();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshReceipts,
          ),
        ],
      ),
      body: _isLoading && _receipts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _receipts.isEmpty
              ? _buildError()
              : _receipts.isEmpty
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
              width: 64,
              height: 64,
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
              onPressed: _fetchInitialReceipts,
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.receipt_long_outlined, color: _accent.withValues(alpha: 0.5), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('No paid receipts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Completed orders will appear here',
              style: TextStyle(fontSize: 14, color: LaDolcePosUi.mutedText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    // Group receipts by date for display
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var receipt in _receipts) {
      final dayKey = _getDayKey(receipt);
      grouped.putIfAbsent(dayKey, () => []).add(receipt);
    }

    return RefreshIndicator(
      onRefresh: _refreshReceipts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: grouped.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show Load More button at the end
          if (index >= grouped.length) {
            return _buildLoadMoreButton();
          }

          final entry = grouped.entries.elementAt(index);
          final dateKey = entry.key;
          final receipts = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
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
              // Receipts card for this date
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
                    final timeStr = _getTimeStr(receipt);

                    return Column(
                      children: [
                        _buildReceiptTile(receipt, paymentMethod, timeStr, i == 0, isLast),
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
        },
      ),
    );
  }

  Widget _buildReceiptTile(
    Map<String, dynamic> receipt,
    String paymentMethod,
    String timeStr,
    bool isFirst,
    bool isLast,
  ) {
    return InkWell(
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
        top: isFirst ? Radius.circular(LaDolcePosUi.radius) : Radius.zero,
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
                  if ((receipt['amount_discount'] is num && (receipt['amount_discount'] as num) > 0))
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
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton.icon(
                onPressed: _hasMore ? _loadMoreReceipts : null,
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(_hasMore ? 'Load More' : 'No more receipts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LaDolcePosUi.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
      ),
    );
  }
}
