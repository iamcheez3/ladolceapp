import 'package:fl_chart/fl_chart.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/ld.dart';
import 'login_screen.dart';
import 'ranking_screen.dart';
import '../utils/money.dart';

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
  static const Color _brandNavy = Ld.navy;

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
  bool _showHourlyOrders = true; // true = order count, false = revenue
  int? _touchedDay; // bar under the finger in "Sales by date" (gold)

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
    return '₭${money(n)}';
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
    final name = (u['name'] ?? (AppLocalizations.of(context)?.admin ?? 'Admin')).toString();
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

  // ── Layout ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.adminReports ?? 'Admin Reports',
        // Admin home: no back button (it is the landing page).
        leading: widget.asAdminHome ? const SizedBox.shrink() : null,
        actions: [
          if (widget.asAdminHome)
            LdNavIconButton(
              onPressed: _openRanking,
              icon: Icons.emoji_events_outlined,
              tooltip: l10n?.ranking ?? 'Ranking',
            ),
          LdNavIconButton(
            onPressed: _load,
            icon: Icons.refresh_rounded,
            tooltip: l10n?.refresh ?? 'Refresh',
          ),
          if (widget.asAdminHome)
            LdNavIconButton(
              onPressed: _logout,
              icon: Icons.lock_outline_rounded,
              tooltip: l10n?.lockSwitchUser ?? 'Lock / Switch User',
            ),
        ],
        bottom: _filterBar(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Ld.navy))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  /// Branch + date range, in the navy header (Reports mockup).
  PreferredSizeWidget _filterBar() {
    final l10n = AppLocalizations.of(context);
    final rangeLabel =
        '${DateFormat('MMM d').format(_range.start)} - ${DateFormat('MMM d').format(_range.end)}';
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.only(left: 14, right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Ld.r),
                  border: Border.all(color: Ld.navyLine),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedBranchId,
                    isExpanded: true,
                    dropdownColor: Ld.surface,
                    iconEnabledColor: Colors.white,
                    icon: const Icon(Icons.expand_more_rounded),
                    borderRadius: BorderRadius.circular(Ld.r),
                    hint: Text(l10n?.branch ?? 'Branch',
                        style: const TextStyle(color: Ld.onNavyMuted, fontSize: 15)),
                    style: const TextStyle(fontFamily: Ld.sans, fontSize: 15, color: Ld.ink),
                    selectedItemBuilder: (ctx) => [
                      _branchLabelOnNavy(l10n?.allBranches ?? 'All branches'),
                      ..._branches.map((b) => _branchLabelOnNavy(_branchLabel(b))),
                    ],
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l10n?.allBranches ?? 'All branches'),
                      ),
                      ..._branches.map((b) {
                        final id = (b['id'] is int)
                            ? b['id'] as int
                            : int.tryParse('${b['id']}');
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text(_branchLabel(b), maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) async {
                      setState(() => _selectedBranchId = v);
                      await _load();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sized to its label so the dates stay readable; the branch
            // menu takes the rest.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Tooltip(
                message: l10n?.selectDateRange ?? 'Select date range',
                child: Material(
                  color: Ld.surface,
                  borderRadius: BorderRadius.circular(Ld.r),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Ld.r),
                    onTap: _pickRange,
                    child: SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.date_range_outlined, size: 18, color: Ld.navy),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                rangeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Ld.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _branchLabel(Map b) {
    final name = (b['name'] ?? '').toString();
    final code = (b['code'] ?? '').toString().trim();
    return code.isNotEmpty ? '$name ($code)' : name;
  }

  Widget _branchLabelOnNavy(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
      );

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LdIconTile(Icons.error_outline_rounded,
                size: 56, background: Ld.dangerWash, color: Ld.danger),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Failed to load',
              style: const TextStyle(color: Ld.danger, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context);
    final data = _report?['data'] as Map<String, dynamic>? ?? {};
    final grandTotal = (data['grand_total'] as num?) ?? 0;
    final salesByDay = (data['sales_by_day'] as List?)?.cast<Map>() ?? const [];
    final byPayment =
        (data['sales_by_payment_method'] as List?)?.cast<Map>() ?? const [];
    final byProduct =
        (data['sales_by_product'] as List?)?.cast<Map>() ?? const [];
    final byBranch =
        (data['sales_by_branch'] as List?)?.cast<Map>() ?? const [];
    final salesByHour =
        (data['sales_by_hour'] as List?)?.cast<Map>() ?? const [];

    final salesCard = _chartCard(
      title: l10n?.salesByDate ?? 'Sales by date',
      child: SizedBox(height: 240, child: _salesByDayChart(salesByDay)),
    );
    final peakCard = _hourlyPeakCard(salesByHour);
    final paymentCard = _chartCard(
      title: l10n?.salesByPaymentType ?? 'Sales by payment type',
      child: _paymentTable(byPayment),
    );
    final productCard = _chartCard(
      title: l10n?.salesByProductTop ?? 'Sales by product (top)',
      child: _topProductsList(
        byProduct
            .take(12)
            .map((e) => _BarItem(
                  label: (e['name'] ?? (l10n?.item ?? 'Item')).toString(),
                  value: (e['total'] as num?)?.toDouble() ?? 0,
                ))
            .toList(),
      ),
    );
    final branchCard = _chartCard(
      title: l10n?.branchRanking ?? 'Branch ranking',
      child: _branchRankingList(byBranch),
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: Ld.navy,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final pad = wide ? 24.0 : 16.0;
          const gap = SizedBox(height: 14, width: 14);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 24 + Ld.navInset(context)),
            children: [
              _statTiles(grandTotal, salesByDay, byPayment, wide),
              gap,
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 16,
                      child: Column(children: [salesCard, gap, peakCard]),
                    ),
                    gap,
                    Expanded(
                      flex: 10,
                      child: Column(children: [paymentCard, gap, productCard, gap, branchCard]),
                    ),
                  ],
                )
              else ...[
                salesCard,
                gap,
                peakCard,
                gap,
                paymentCard,
                gap,
                productCard,
                gap,
                branchCard,
              ],
            ],
          );
        },
      ),
    );
  }

  /// Headline numbers: total sales, transactions, day-over-day change.
  Widget _statTiles(num grandTotal, List<Map> salesByDay, List<Map> byPayment, bool wide) {
    final l10n = AppLocalizations.of(context);
    final totalTx = byPayment.fold<int>(
        0, (sum, e) => sum + ((e['transactions'] as num?)?.toInt() ?? 0));
    final total = _tile(
      label: l10n?.total ?? 'Total',
      value: _money(grandTotal),
    );
    final tx = byPayment.isEmpty
        ? null
        : _tile(
            label: l10n?.transactions ?? 'Transactions',
            value: NumberFormat('#,###').format(totalTx),
          );
    final delta = _dayOverDayKpi(salesByDay);

    final small = [?tx, ?delta];
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: total),
            for (final t in small) ...[const SizedBox(width: 14), Expanded(child: t)],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        total,
        if (small.isNotEmpty) ...[
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < small.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: small[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile({required String label, required String value, Widget? sub, Color valueColor = Ld.navy}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: Ld.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ld.label),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: Ld.price(26, color: valueColor)),
          ),
          if (sub != null) ...[const SizedBox(height: 4), sub],
        ],
      ),
    );
  }

  Widget? _dayOverDayKpi(List<Map> salesByDay) {
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
      return null;
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
    final color = pct == null
        ? Ld.muted
        : up
            ? Ld.success
            : Ld.danger;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: Ld.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ld.label),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                pct == null
                    ? Icons.remove
                    : up
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                size: 22,
                color: color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(pctText, style: Ld.price(26, color: color)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: Ld.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Ld.ink),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _noData() => SizedBox(
        height: 80,
        child: Center(
          child: Text(AppLocalizations.of(context)?.noData ?? 'No data', style: Ld.label),
        ),
      );

  /// Sales by date: one navy bar per day, gold while touched.
  Widget _salesByDayChart(List<Map> rows) {
    if (rows.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)?.noData ?? 'No data', style: Ld.label));
    }
    final values = <double>[];
    final labels = <String>[];
    for (var i = 0; i < rows.length; i++) {
      values.add((rows[i]['total'] as num?)?.toDouble() ?? 0);
      final raw = (rows[i]['date'] ?? '').toString();
      // Expect ISO yyyy-mm-dd; fallback to raw
      String out = raw;
      try {
        if (raw.length >= 10) {
          final d = DateTime.tryParse(raw.substring(0, 10));
          if (d != null) out = DateFormat('MM/dd').format(d);
        }
      } catch (_) {}
      labels.add(out);
    }
    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);

    return LayoutBuilder(builder: (context, c) {
      final plotW = (c.maxWidth - 54).clamp(40.0, double.infinity);
      final slot = plotW / values.length;
      final barW = (slot * 0.62).clamp(3.0, 40.0);
      final maxLabels = (plotW / 46).floor().clamp(1, 1000);
      final step = (values.length / maxLabels).ceil().clamp(1, 1000);

      return BarChart(
        BarChartData(
          maxY: maxV <= 0 ? 1 : maxV * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _niceInterval(maxV),
            getDrawingHorizontalLine: (_) => const FlLine(color: Ld.lineSoft, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(bottom: BorderSide(color: Ld.line)),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, resp) {
              final idx = resp?.spot?.touchedBarGroupIndex;
              final next = event.isInterestedForInteractions ? idx : null;
              if (next != _touchedDay) setState(() => _touchedDay = next);
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Ld.ink,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${labels[groupIndex]}\n${_money(values[groupIndex])}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 54,
                interval: _niceInterval(maxV),
                getTitlesWidget: (value, meta) => Text(
                  NumberFormat.compact().format(value),
                  style: const TextStyle(fontSize: 11, color: Ld.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  if (i % step != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: const TextStyle(fontSize: 11, color: Ld.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: _touchedDay == i ? Ld.gold : Ld.navy,
                    width: barW,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      );
    });
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

  /// Ranked rows with a navy share bar under each (top products).
  Widget _topProductsList(List<_BarItem> items) {
    if (items.isEmpty) return _noData();
    final maxV = items.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _rankRow(rank: i + 1, label: items[i].label, value: items[i].value, maxV: maxV, first: i == 0),
      ],
    );
  }

  Widget _rankRow({
    required int rank,
    required String label,
    required double value,
    required double maxV,
    bool first = false,
    String? detail,
  }) {
    final share = maxV <= 0 ? 0.0 : (value / maxV).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: Ld.lineSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text('$rank', style: const TextStyle(fontSize: 13, color: Ld.muted, height: 1.6)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: Ld.ink, height: 1.35),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_money(value), style: Ld.price(15, color: Ld.ink, weight: FontWeight.w600)),
                  ],
                ),
                if (detail != null)
                  Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ld.small),
                const SizedBox(height: 6),
                _shareBar(share),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareBar(double share) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Ld.ground)),
            FractionallySizedBox(
              widthFactor: share,
              heightFactor: 1,
              child: const ColoredBox(color: Ld.navy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchRankingList(List<Map> rows) {
    if (rows.isEmpty) return _noData();
    final items = rows
        .map(
          (e) => _BarItem(
            label: (e['branch_name'] ?? '').toString().trim(),
            value: (e['total'] as num?)?.toDouble() ?? 0,
          ),
        )
        .where((e) => e.label.isNotEmpty)
        .toList();
    if (items.isEmpty) return _noData();
    items.sort((a, b) => b.value.compareTo(a.value));

    final shown = items.length > 12 ? 12 : items.length;
    final maxV = items.first.value;
    return Column(
      children: [
        for (var i = 0; i < shown; i++)
          _rankRow(rank: i + 1, label: items[i].label, value: items[i].value, maxV: maxV, first: i == 0),
      ],
    );
  }

  Widget _paymentTable(List<Map> rows) {
    if (rows.isEmpty) return _noData();
    final l10n = AppLocalizations.of(context);

    final items = rows
        .map((e) {
          final name = (e['payment_method'] ?? (l10n?.unknown ?? 'Unknown')).toString();
          final total = (e['total'] as num?)?.toDouble() ?? 0;
          final tx = (e['transactions'] as num?)?.toInt();
          return _PaymentRow(name: name, transactions: tx, total: total);
        })
        .toList();

    final totalTx = items.fold<int>(0, (sum, r) => sum + (r.transactions ?? 0));
    final totalAmt = items.fold<double>(0, (sum, r) => sum + r.total);
    final maxV = items.map((e) => e.total).fold<double>(0, (a, b) => a > b ? a : b);
    final txLabel = l10n?.transactions ?? 'Transactions';

    String txText(int? tx) => '$txLabel: ${tx == null ? '—' : NumberFormat('#,###').format(tx)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: Ld.ink, height: 1.35),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_money(r.total), style: Ld.price(15, color: Ld.ink, weight: FontWeight.w600)),
                  ],
                ),
                Text(txText(r.transactions), style: Ld.small),
                const SizedBox(height: 6),
                _shareBar(maxV <= 0 ? 0 : (r.total / maxV).clamp(0.0, 1.0)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ld.line))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.total ?? 'Total',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Ld.ink),
                    ),
                    Text(txText(totalTx), style: Ld.small),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(_money(totalAmt), style: Ld.price(17)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hourlyPeakCard(List<Map> rows) {
    final l10n = AppLocalizations.of(context);
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: Ld.card(),
        child: SizedBox(
          height: 100,
          child: Center(
            child: Text(
              l10n?.noHourlyPeakDataAvailable ?? 'No hourly peak data available',
              style: Ld.label,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Identify maximum value to highlight peak hours (>=85% of max)
    double maxV = 0.0;
    for (final r in rows) {
      final val = _showHourlyOrders
          ? ((r['order_count'] as num?)?.toDouble() ?? 0.0)
          : ((r['total'] as num?)?.toDouble() ?? 0.0);
      if (val > maxV) maxV = val;
    }

    return _chartCard(
      title: l10n?.peakOrderHours ?? 'Peak order hours',
      // Segmented controls for switching modes
      trailing: Wrap(
        spacing: 8,
        children: [
          LdChoiceChip(
            label: l10n?.orders ?? 'Orders',
            selected: _showHourlyOrders,
            onTap: () => setState(() => _showHourlyOrders = true),
          ),
          LdChoiceChip(
            label: l10n?.revenue ?? 'Revenue',
            selected: !_showHourlyOrders,
            onTap: () => setState(() => _showHourlyOrders = false),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxV <= 0 ? 1 : maxV * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Ld.lineSoft, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(bottom: BorderSide(color: Ld.line)),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => _brandNavy,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final h = (rows[groupIndex]['hour'] as num?)?.toInt() ?? 0;
                      final count = (rows[groupIndex]['order_count'] as num?)?.toInt() ?? 0;
                      final amt = (rows[groupIndex]['total'] as num?)?.toDouble() ?? 0.0;
                      final timeStr = '${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00';
                      final countStr = '$count order${count == 1 ? "" : "s"}';
                      final amtStr = _money(amt);
                      return BarTooltipItem(
                        '$timeStr\n$countStr\n$amtStr',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: _niceInterval(maxV),
                      getTitlesWidget: (v, meta) => Text(
                        NumberFormat.compact().format(v),
                        style: const TextStyle(fontSize: 10, color: Ld.muted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final h = value.round();
                        if (h < 0 || h > 23) return const SizedBox.shrink();
                        // Label every 3 hours to avoid overlap
                        if (h % 3 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(fontSize: 10, color: Ld.muted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < rows.length; i++)
                    BarChartGroupData(
                      x: (rows[i]['hour'] as num?)?.toInt() ?? i,
                      barRods: [
                        BarChartRodData(
                          toY: _showHourlyOrders
                              ? ((rows[i]['order_count'] as num?)?.toDouble() ?? 0.0)
                              : ((rows[i]['total'] as num?)?.toDouble() ?? 0.0),
                          // Peak hours (>= 85 % of the busiest) are highlighted
                          // in gold; the staffing tip below names them.
                          color: maxV > 0 &&
                                  (_showHourlyOrders
                                      ? ((rows[i]['order_count'] as num?)?.toDouble() ?? 0.0)
                                      : ((rows[i]['total'] as num?)?.toDouble() ?? 0.0)) >=
                                      maxV * 0.85
                              ? Ld.gold
                              : Ld.navy,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _peakStaffingSummary(rows),
        ],
      ),
    );
  }

  Widget _peakStaffingSummary(List<Map> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Sort by order_count descending
    final sorted = List<Map>.from(rows)
      ..sort((a, b) {
        final ac = (a['order_count'] as num?)?.toInt() ?? 0;
        final bc = (b['order_count'] as num?)?.toInt() ?? 0;
        return bc.compareTo(ac);
      });

    final topHours = <int>[];
    for (var i = 0; i < sorted.length && i < 3; i++) {
      final count = (sorted[i]['order_count'] as num?)?.toInt() ?? 0;
      if (count > 0) {
        topHours.add((sorted[i]['hour'] as num).toInt());
      }
    }

    if (topHours.isEmpty) {
      return Text(
        AppLocalizations.of(context)?.noOrderTrafficRecordedInThis ?? 'No order traffic recorded in this range.',
        style: Ld.small,
      );
    }

    topHours.sort();
    final hoursStr = topHours.map((h) => '${h.toString().padLeft(2, '0')}:00').join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Ld.infoWash,
        borderRadius: BorderRadius.circular(Ld.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Ld.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Staffing Tip: Peak traffic occurs around $hoursStr. Consider preparing additional staff or scheduling shifts to cover these times.',
              style: const TextStyle(fontSize: 13, color: Ld.ink, height: 1.45),
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

