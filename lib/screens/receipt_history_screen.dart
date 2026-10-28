import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'receipt_detail_screen.dart';
import '../theme/ld.dart';
import '../utils/money.dart';

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

  /// Receipt shown beside the list on tablets (null = the newest one).
  int? _selectedId;

  static const Color _iconCashBg = Ld.successWash;
  static const Color _iconBankBg = Ld.infoWash;
  static const Color _iconOtherBg = Ld.ground;

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
    return '₭${money(amount)}';
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
    
    if (dateStr.isEmpty) return (AppLocalizations.of(context)?.unknownDate ?? 'Unknown Date');
    
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(dt.year, dt.month, dt.day);

      if (dateOnly == today) return (AppLocalizations.of(context)?.today ?? 'Today');
      if (dateOnly == yesterday) return (AppLocalizations.of(context)?.yesterday ?? 'Yesterday');
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (_) {
      return (AppLocalizations.of(context)?.unknownDate ?? 'Unknown Date');
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

  /// Landscape tablets show the list and the selected receipt side by side;
  /// narrower screens open the receipt as its own page.
  bool _isSplit(BuildContext context) =>
      Ld.isTablet(context) && MediaQuery.sizeOf(context).width >= 900;

  /// The receipt shown on the right in the split view: the one tapped, or
  /// the newest one until something is tapped.
  int? _shownReceiptId() {
    if (_selectedId != null &&
        _receipts.any((r) => _resolveReceiptId(r) == _selectedId)) {
      return _selectedId;
    }
    for (final r in _receipts) {
      final id = _resolveReceiptId(r);
      if (id != null) return id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final split = _isSplit(context);
    final Widget list = _isLoading && _receipts.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null && _receipts.isEmpty
            ? _buildError()
            : _receipts.isEmpty
                ? _buildEmpty()
                : _buildList(split: split);

    Widget body = list;
    if (split) {
      final width = MediaQuery.sizeOf(context).width;
      final shownId = _receipts.isEmpty ? null : _shownReceiptId();
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: (width * 0.42).clamp(340.0, 460.0),
            decoration: const BoxDecoration(
              color: Ld.surface,
              border: Border(right: BorderSide(color: Ld.line)),
            ),
            child: list,
          ),
          Expanded(
            child: shownId == null
                ? const ColoredBox(
                    color: Ld.ground,
                    child: Center(child: Icon(Icons.receipt_long_outlined, size: 64, color: Ld.faint)),
                  )
                : ReceiptDetailScreen(
                    key: ValueKey(shownId),
                    orderId: shownId,
                    embedded: true,
                    onRefunded: _refreshReceipts,
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: AppLocalizations.of(context)?.receiptsHistory ?? 'Receipts History',
        actions: [
          LdNavIconButton(
            icon: Icons.refresh_rounded,
            tooltip: AppLocalizations.of(context)?.refresh ?? 'Refresh',
            onPressed: _isLoading ? null : _refreshReceipts,
          ),
        ],
      ),
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _fetchInitialReceipts,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LdIconTile(Icons.receipt_long_outlined, size: 80, background: Ld.surface),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)?.noPaidReceiptsYet ?? 'No paid receipts yet',
              textAlign: TextAlign.center,
              style: Ld.title(20),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)?.completedOrdersWillAppearHere ?? 'Completed orders will appear here',
              textAlign: TextAlign.center,
              style: Ld.label,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList({required bool split}) {
    // Group receipts by date for display
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var receipt in _receipts) {
      final dayKey = _getDayKey(receipt);
      grouped.putIfAbsent(dayKey, () => []).add(receipt);
    }
    final shownId = split ? _shownReceiptId() : null;
    final side = split ? 8.0 : 16.0;

    return RefreshIndicator(
      onRefresh: _refreshReceipts,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(side, 4, side, 24 + Ld.navInset(context)),
        itemCount: grouped.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show Load More button at the end
          if (index >= grouped.length) {
            return _buildLoadMoreButton();
          }

          final entry = grouped.entries.elementAt(index);
          final dateKey = entry.key;
          final receipts = entry.value;

          final tiles = List.generate(receipts.length, (i) {
            final receipt = receipts[i];
            final paymentMethod = (receipt['payment_method'] ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown')).toString();
            final isLast = i == receipts.length - 1;
            final timeStr = _getTimeStr(receipt);
            final selected = split && shownId != null && _resolveReceiptId(receipt) == shownId;

            return Column(
              children: [
                _buildReceiptTile(receipt, paymentMethod, timeStr, i == 0, isLast,
                    split: split, selected: selected),
                if (!isLast && !split)
                  const Divider(height: 1, thickness: 1, indent: 68, color: Ld.lineSoft),
              ],
            );
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date header
              Padding(
                padding: EdgeInsets.fromLTRB(split ? 8 : 4, 16, 4, 8),
                child: Text(
                  dateKey,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Ld.muted),
                ),
              ),
              // Receipts card for this date (plain rows in the split list)
              if (split)
                ...tiles
              else
                Container(
                  decoration: Ld.card(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: tiles),
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
    bool isLast, {
    bool split = false,
    bool selected = false,
  }) {
    final dur = _formatVisitDuration(receipt);
    final offline = receipt['offline'] == true ||
        receipt['synced'] == false ||
        (receipt['id'] is int && (receipt['id'] as int) < 0);
    final hasDiscount = receipt['amount_discount'] is num && (receipt['amount_discount'] as num) > 0;
    final ref = (receipt['name'] ?? receipt['order_reference'] ?? '').toString();
    final meta = [if (timeStr.isNotEmpty) timeStr, paymentMethod].join(' · ');

    final radius = split
        ? BorderRadius.circular(Ld.r)
        : BorderRadius.vertical(
            top: isFirst ? const Radius.circular(Ld.rLg) : Radius.zero,
            bottom: isLast ? const Radius.circular(Ld.rLg) : Radius.zero,
          );

    return Material(
      color: selected ? Ld.ground : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: () {
          final id = _resolveReceiptId(receipt);
          if (id == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)?.thisReceiptIsMissingAnOrder ?? 'This receipt is missing an order id. Please refresh and try again.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          if (_isSplit(context)) {
            setState(() => _selectedId = id);
            return;
          }
          _showReceiptDetails(id);
        },
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: split ? 10 : 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: selected ? Ld.surface : _getIconBg(paymentMethod),
                  borderRadius: BorderRadius.circular(Ld.rSm),
                ),
                child: Image.asset(_getPaymentAsset(paymentMethod), fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Ld.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ld.small),
                    if (hasDiscount)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Discount: -₭${money((receipt['amount_discount'] as num))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Ld.danger, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatAmount(receipt['amount_total']),
                        style: Ld.price(17, color: Ld.ink, weight: FontWeight.w600),
                      ),
                    ),
                    if (offline || dur != null) const SizedBox(height: 4),
                    if (offline)
                      LdPill(
                        AppLocalizations.of(context)?.unsynced ?? 'Unsynced',
                        background: Ld.warningWash,
                        foreground: Ld.warning,
                        icon: Icons.cloud_off_rounded,
                      )
                    else if (dur != null)
                      LdPill(dur, background: Ld.ground, foreground: Ld.muted, icon: Icons.timer_outlined),
                    if (offline && dur != null) ...[
                      const SizedBox(height: 4),
                      LdPill(dur, background: Ld.ground, foreground: Ld.muted, icon: Icons.timer_outlined),
                    ],
                  ],
                ),
              ),
              if (!split) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Ld.faint, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton.icon(
                onPressed: _hasMore ? _loadMoreReceipts : null,
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                label: Text(_hasMore ? (AppLocalizations.of(context)?.loadMore ?? 'Load More') : (AppLocalizations.of(context)?.noMoreReceipts ?? 'No more receipts')),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Ld.surface,
                  foregroundColor: Ld.navy,
                  side: const BorderSide(color: Ld.line),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
      ),
    );
  }
}
