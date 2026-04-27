import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/ladolce_pos_ui.dart';
import 'login_screen.dart';
import 'ranking_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  /// When true, the screen acts as the admin's main landing page:
  ///  - back button is hidden
  ///  - AppBar exposes a Lock / Switch User action
  /// When false, it behaves as a regular pushed page (back button shown).
  final bool asAdminHome;

  const AdminReportsScreen({super.key, this.asAdminHome = false});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  static const Color _brandNavy = LaDolcePosUi.navy;

  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );

  List<Map<String, dynamic>> _branches = const [];
  int? _selectedBranchId; // null = all

  Map<String, dynamic>? _report;
  Map<String, dynamic>? _cachedUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _api.getCachedUser();
    final role = user?['role']?.toString();
    if (role != 'admin') {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Forbidden (admin only)';
      });
      return;
    }
    _cachedUser = user;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Branch list is safe to load without session; avoid cookie/session flakiness on some clients.
      final branches = await _api.fetchBranchesPublic();
      final report = await _api.fetchAdminReportSummary(
        from: _range.start,
        to: _range.end,
        branchId: _selectedBranchId,
      );
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _load();
  }

  String _money(num v) {
    final n = v.toDouble();
    return '₭${NumberFormat('#,###').format(n.round())}';
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await _api.logout();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openRanking() {
    final u = _cachedUser ?? const <String, dynamic>{};
    final name = (u['name'] ?? 'Admin').toString();
    final points = int.tryParse((u['reward_points'] ?? 0).toString()) ?? 0;
    final img = u['image_base64']?.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RankingScreen(
          myRank: null,
          myPoints: points,
          myName: name,
          myImageBase64: img,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandNavy,
      appBar: AppBar(
        backgroundColor: _brandNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.asAdminHome,
        title: const Text('Admin Reports'),
        actions: [
          IconButton(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
            tooltip: 'Select date range',
          ),
          if (widget.asAdminHome)
            IconButton(
              onPressed: _openRanking,
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: 'Ranking',
            ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          if (widget.asAdminHome)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Lock / Switch User',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Failed to load',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _report?['data'] as Map<String, dynamic>? ?? {};
    final grandTotal = (data['grand_total'] as num?) ?? 0;
    final salesByDay = (data['sales_by_day'] as List?)?.cast<Map>() ?? const [];
    final byPayment =
        (data['sales_by_payment_method'] as List?)?.cast<Map>() ?? const [];
    final byProduct =
        (data['sales_by_product'] as List?)?.cast<Map>() ?? const [];
    final byBranch =
        (data['sales_by_branch'] as List?)?.cast<Map>() ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _filtersCard(grandTotal, salesByDay),
        const SizedBox(height: 12),
        _chartCard(
          title: 'Sales by date',
          child: _salesLineChart(salesByDay),
        ),
        const SizedBox(height: 12),
        _chartCard(
          title: 'Sales by payment type',
          child: _paymentTable(byPayment),
        ),
        const SizedBox(height: 12),
        _chartCard(
          title: 'Sales by product (top)',
          child: _simpleBarChart(
            byProduct
                .take(12)
                .map((e) => _BarItem(
                      label: (e['name'] ?? 'Item').toString(),
                      value: (e['total'] as num?)?.toDouble() ?? 0,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _chartCard(
          title: 'Branch ranking',
          child: _branchRankingList(byBranch),
        ),
      ],
    );
  }

  Widget _filtersCard(num grandTotal, List<Map> salesByDay) {
    final rangeLabel =
        '${DateFormat('MMM d').format(_range.start)} - ${DateFormat('MMM d').format(_range.end)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${_money(grandTotal)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                rangeLabel,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _dayOverDayKpi(salesByDay),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            value: _selectedBranchId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Branch',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All branches'),
              ),
              ..._branches.map((b) {
                final id = (b['id'] is int)
                    ? b['id'] as int
                    : int.tryParse('${b['id']}');
                final name = (b['name'] ?? '').toString();
                final code = (b['code'] ?? '').toString().trim();
                final label = code.isNotEmpty ? '$name ($code)' : name;
                return DropdownMenuItem<int?>(
                  value: id,
                  child: Text(label),
                );
              }),
            ],
            onChanged: (v) async {
              setState(() => _selectedBranchId = v);
              await _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _dayOverDayKpi(List<Map> salesByDay) {
    // Use the last 2 points in the series (already filtered by branch/date range).
    // If the range includes today, this effectively shows Today vs Yesterday.
    DateTime? parseDay(dynamic v) {
      final s = (v ?? '').toString().trim();
      if (s.isEmpty) return null;
      // Prefer ISO yyyy-mm-dd
      if (s.length >= 10) {
        final iso = s.substring(0, 10);
        final dt = DateTime.tryParse(iso);
        if (dt != null) return DateTime(dt.year, dt.month, dt.day);
      }
      // Fallback: try DateTime.parse on full string
      final dt2 = DateTime.tryParse(s);
      if (dt2 != null) return DateTime(dt2.year, dt2.month, dt2.day);
      return null;
    }

    final points = salesByDay
        .map((e) => {
              'd': parseDay(e['date']),
              't': (e['total'] as num?)?.toDouble() ?? 0.0,
            })
        .where((e) => e['d'] != null)
        .toList()
      ..sort((a, b) => (a['d'] as DateTime).compareTo(b['d'] as DateTime));

    if (points.length < 2) {
      return const SizedBox.shrink();
    }

    final last = points[points.length - 1];
    final prev = points[points.length - 2];
    final lastD = last['d'] as DateTime;
    final prevD = prev['d'] as DateTime;
    final lastT = (last['t'] as double);
    final prevT = (prev['t'] as double);

    final denom = prevT.abs();
    final pct = denom <= 0 ? null : ((lastT - prevT) / denom) * 100.0;
    final up = pct != null && pct >= 0;

    final label = 'Δ ${DateFormat('MMM d').format(prevD)} → ${DateFormat('MMM d').format(lastD)}';
    final pctText = pct == null ? '—' : '${pct.abs().toStringAsFixed(1)}%';
    final chipColor = pct == null
        ? const Color(0xFFE2E8F0)
        : up
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2);
    final chipTextColor = pct == null
        ? const Color(0xFF334155)
        : up
            ? const Color(0xFF166534)
            : const Color(0xFF991B1B);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pct == null
                    ? Icons.remove
                    : up
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                size: 16,
                color: chipTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                pctText,
                style: TextStyle(
                  color: chipTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chartCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 240, child: child),
        ],
      ),
    );
  }

  Widget _salesLineChart(List<Map> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final spots = <FlSpot>[];
    final labels = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final v = (rows[i]['total'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
      labels.add((rows[i]['date'] ?? '').toString());
    }
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: _niceInterval(spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b)),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 54,
              interval: _niceInterval(spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b)),
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact().format(value),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: labels.length <= 7 ? 1 : 2,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                final raw = labels[i];
                // Expect ISO yyyy-mm-dd; fallback to raw
                String out = raw;
                try {
                  if (raw.length >= 10) {
                    final d = DateTime.tryParse(raw.substring(0, 10));
                    if (d != null) out = DateFormat('MM/dd').format(d);
                  }
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    out,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            color: LaDolcePosUi.gold,
          ),
        ],
      ),
    );
  }

  double _niceInterval(double maxV) {
    if (maxV <= 0) return 1;
    final rough = maxV / 4.0;
    if (rough <= 10) return 10;
    if (rough <= 50) return 50;
    if (rough <= 100) return 100;
    if (rough <= 500) return 500;
    if (rough <= 1000) return 1000;
    if (rough <= 5000) return 5000;
    if (rough <= 10000) return 10000;
    return (rough / 10000).ceilToDouble() * 10000;
  }

  Widget _simpleBarChart(List<_BarItem> items) {
    if (items.isEmpty) return const Center(child: Text('No data'));
    final maxV = items.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: maxV <= 0 ? 1 : maxV * 1.15,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 54,
              interval: _niceInterval(maxV),
              getTitlesWidget: (v, meta) => Text(
                NumberFormat.compact().format(v),
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                final t = items[i].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: 66,
                    child: Text(
                      t,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].value,
                  color: LaDolcePosUi.navy2,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _branchRankingList(List<Map> rows) {
    if (rows.isEmpty) return const Center(child: Text('No data'));
    final items = rows
        .map(
          (e) => _BarItem(
            label: (e['branch_name'] ?? '').toString().trim(),
            value: (e['total'] as num?)?.toDouble() ?? 0,
          ),
        )
        .where((e) => e.label.isNotEmpty)
        .toList();
    if (items.isEmpty) return const Center(child: Text('No data'));
    items.sort((a, b) => b.value.compareTo(a.value));

    return ListView.separated(
      itemCount: items.length > 12 ? 12 : items.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final it = items[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: Text(
                  it.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _money(it.value),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentTable(List<Map> rows) {
    if (rows.isEmpty) return const Center(child: Text('No data'));

    final items = rows
        .map((e) {
          final name = (e['payment_method'] ?? 'Unknown').toString();
          final total = (e['total'] as num?)?.toDouble() ?? 0;
          final tx = (e['transactions'] as num?)?.toInt();
          return _PaymentRow(name: name, transactions: tx, total: total);
        })
        .toList();

    final totalTx = items.fold<int>(0, (sum, r) => sum + (r.transactions ?? 0));
    final totalAmt = items.fold<double>(0, (sum, r) => sum + r.total);

    return Column(
      children: [
        _paymentHeaderRow(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: items.length + 1,
            separatorBuilder: (_, i) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              if (i == items.length) {
                return _paymentDataRow(
                  label: 'Total',
                  tx: totalTx,
                  amt: totalAmt,
                  isTotal: true,
                );
              }
              final r = items[i];
              return _paymentDataRow(
                label: r.name,
                tx: r.transactions,
                amt: r.total,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _paymentHeaderRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'Payment type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Transactions',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Amount',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentDataRow({
    required String label,
    required int? tx,
    required double amt,
    bool isTotal = false,
  }) {
    final style = TextStyle(
      fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
      fontSize: 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 3,
            child: Text(
              tx == null ? '—' : NumberFormat('#,###').format(tx),
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _money(amt),
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  _BarItem({required this.label, required this.value});
}

class _PaymentRow {
  final String name;
  final int? transactions;
  final double total;
  _PaymentRow({required this.name, required this.transactions, required this.total});
}

