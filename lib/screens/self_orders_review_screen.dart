import 'package:flutter/material.dart';
import '../utils/bilingual_name.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';

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
      debugPrint('[SelfOrders] load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load orders. Please check your connection and try again.';
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
        SnackBar(
          content: Text(AppLocalizations.of(context)?.transferConfirmedOrderMovedToOpen ?? (AppLocalizations.of(context)?.transferConfirmedOrderMovedToOpen ?? 'Transfer confirmed. Order moved to Open Tickets.')),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      debugPrint('[SelfOrders] confirm failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.couldNotConfirmOrderPleaseTry ?? (AppLocalizations.of(context)?.couldNotConfirmOrderPleaseTry ?? 'Could not confirm order. Please try again.')), backgroundColor: Colors.red),
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
        title: Text(AppLocalizations.of(context)?.rejectOrder2 ?? (AppLocalizations.of(context)?.rejectOrder2 ?? 'Reject Order?')),
        content: Text(
            'Are you sure you want to reject and cancel order ${order['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)?.keep ?? (AppLocalizations.of(context)?.keep ?? 'Keep'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)?.reject ?? (AppLocalizations.of(context)?.reject ?? 'Reject'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.rejectSelfOrder(orderId as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.orderRejectedAndCancelled ?? (AppLocalizations.of(context)?.orderRejectedAndCancelled ?? 'Order rejected and cancelled.')),
          backgroundColor: Colors.orange,
        ),
      );
      await _load();
    } catch (e) {
      debugPrint('[SelfOrders] reject failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.couldNotRejectOrderPleaseTry ?? (AppLocalizations.of(context)?.couldNotRejectOrderPleaseTry ?? 'Could not reject order. Please try again.')), backgroundColor: Colors.red),
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
                  if (absUrl.isEmpty) return Text(AppLocalizations.of(context)?.noProofImageUploaded ?? (AppLocalizations.of(context)?.noProofImageUploaded ?? 'No proof image uploaded'));
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
                                  Text(AppLocalizations.of(context)?.cannotLoadProofImage ?? (AppLocalizations.of(context)?.cannotLoadProofImage ?? 'Cannot load proof image')),
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
                          label: Text(AppLocalizations.of(context)?.fullscreen ?? (AppLocalizations.of(context)?.fullscreen ?? 'Fullscreen')),
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
                  child: Text(AppLocalizations.of(context)?.close ?? (AppLocalizations.of(context)?.close ?? 'Close')),
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
              errorBuilder: (_, _, _) => Text(AppLocalizations.of(context)?.cannotLoadProofImage ?? (AppLocalizations.of(context)?.cannotLoadProofImage ?? 'Cannot load proof image'),
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
    final l10n = AppLocalizations.of(context);
    final pending = _isLoading || _error != null ? 0 : _orders.length;
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.selfOrdersReview ?? 'Self Orders Review',
        actions: [
          if (pending > 0 && !Ld.isTablet(context))
            Tooltip(
              message: l10n?.waitingReview ?? 'Waiting review',
              child: LdBadge('$pending'),
            ),
          if (pending > 0 && Ld.isTablet(context))
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Ld.danger,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  '$pending ${l10n?.waitingReview ?? 'Waiting review'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          LdNavIconButton(
            onPressed: _load,
            icon: Icons.refresh_rounded,
            tooltip: l10n?.refresh ?? 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Ld.navy))
          : _error != null
              ? _buildError()
              : _orders.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LdIconTile(Icons.wifi_off_rounded,
                  size: 72, background: Ld.surface, color: Ld.muted),
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: Ld.body.copyWith(color: Ld.muted)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: Ld.navy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, Ld.tap),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => RefreshIndicator(
        onRefresh: _load,
        color: Ld.navy,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LdIconTile(Icons.inbox_outlined,
                          size: 80, background: Ld.surface, color: Ld.faint),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.of(context)?.noPendingSelfOrders ??
                            'No pending self orders',
                        textAlign: TextAlign.center,
                        style: Ld.body.copyWith(color: Ld.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildCard(Map<String, dynamic> order) => _OrderCard(
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

  Widget _buildList() => LayoutBuilder(
        builder: (context, c) {
          final bottom = 24 + Ld.navInset(context);
          // Two columns of cards on wide screens (tablet landscape).
          if (c.maxWidth >= 900) {
            final left = <Widget>[];
            final right = <Widget>[];
            for (var i = 0; i < _orders.length; i++) {
              (i.isEven ? left : right).add(Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCard(_orders[i]),
              ));
            }
            return RefreshIndicator(
              onRefresh: _load,
              color: Ld.navy,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 22, 24, bottom),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: left)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(children: right)),
                  ],
                ),
              ),
            );
          }
          final side = c.maxWidth >= 600 ? 24.0 : 12.0;
          return RefreshIndicator(
            onRefresh: _load,
            color: Ld.navy,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(side, 14, side, bottom),
              itemCount: _orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildCard(_orders[index]),
            ),
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

  bool get _isPayAtStore {
    final paymentType = (order['payment_type'] ?? '').toString();
    final hasProof = order['transfer_proof_uploaded'] == true ||
        ((order['transfer_proof_url'] ?? '').toString().isNotEmpty);
    return paymentType == 'pay_at_store' ||
        (paymentType != 'transfer' && !hasProof);
  }

  bool get _hasDeliveryPlace {
    return (order['delivery_place_name']?.toString().trim().isNotEmpty ??
            false) ||
        (order['delivery_place_address']?.toString().trim().isNotEmpty ??
            false);
  }

  Future<void> _callCustomer(BuildContext context) async {
    final phone = orderPhoneLine(order).replaceAll(RegExp(r'[^0-9+]'), '');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.callCustomer ?? (AppLocalizations.of(context)?.callCustomer ?? 'Call Customer?')),
        content: Text('Do you want to call $phone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? (AppLocalizations.of(context)?.cancel ?? 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)?.call ?? (AppLocalizations.of(context)?.call ?? 'Call')),
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

  @override
  Widget build(BuildContext context) {
    final lines = (order['lines'] as List?) ?? [];

    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 440;
          final pad = wide ? 20.0 : 14.0;
          final showSlipTile = !_isPayAtStore && wide;
          return Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, wide: wide),
                if (_hasDeliveryPlace) ...[
                  const SizedBox(height: 12),
                  _buildDeliveryPlaceSection(context),
                ],
                if ((order['note']?.toString() ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildNoteSection(context),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildItemsSection(context, lines)),
                    if (showSlipTile) ...[
                      const SizedBox(width: 16),
                      _buildSlipTile(context),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _buildActions(context,
                    showProofButton: !_isPayAtStore && !wide,
                    width: c.maxWidth - 2 * pad),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool wide}) {
    final customer = order['customer']?.toString() ?? '-';
    final phone = orderPhoneLine(order);
    final canCall = phone != '—';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[
                _paymentBadge(context),
                const SizedBox(height: 6),
              ],
              Text(
                customer,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Ld.title(20),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PhoneLink(
                    phone: phone,
                    onTap: canCall ? () => _callCustomer(context) : null,
                  ),
                  Text(
                    order['name']?.toString() ?? 'Order',
                    style: Ld.label,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.table_restaurant_outlined,
                      size: 15, color: Ld.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Table: ${order['table_name'] ?? '-'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ld.small,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (wide) ...[
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: _paymentBadge(context),
          ),
        ],
      ],
    );
  }

  Widget _paymentBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isPayAtStore) {
      return LdPill(
        l10n?.payAtStore2 ?? 'Pay at Store',
        background: Ld.infoWash,
        foreground: Ld.info,
        icon: Icons.storefront_outlined,
      );
    }
    return LdPill(
      l10n?.bankTransfer ?? 'Bank Transfer',
      background: Ld.warningWash,
      foreground: Ld.warning,
      icon: Icons.account_balance_outlined,
    );
  }

  Widget _buildDeliveryPlaceSection(BuildContext context) {
    final name = (order['delivery_place_name'] ?? '').toString().trim();
    final address = (order['delivery_place_address'] ?? '').toString().trim();
    final mapsUrl = (order['delivery_maps_url'] ?? '').toString().trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: Ld.card(radius: Ld.r, color: Ld.infoWash, border: Ld.lineSoft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.place_outlined, color: Ld.info, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.customerPlace ?? 'Customer place:',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Ld.info,
                  ),
                ),
                const SizedBox(height: 2),
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ld.ink,
                    ),
                  ),
                if (address.isNotEmpty)
                  Text(address, style: Ld.label),
                if (mapsUrl.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Ld.navy,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () async {
                        final url = Uri.parse(mapsUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(AppLocalizations.of(context)?.openMap ?? 'Open map'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(BuildContext context) {
    final note = (order['note']?.toString() ?? '').trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: Ld.card(radius: Ld.r, color: Ld.warningWash, border: Ld.lineSoft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.edit_note_rounded, color: Ld.warning, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.orderNotePickupTime ??
                      'Order Note / Pickup Time:',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Ld.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(note, style: Ld.body.copyWith(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context, List lines) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lines.isNotEmpty) ...[
          // Toggle header
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(Ld.rSm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 18, color: Ld.navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n?.itemsCount('${lines.length}') ??
                          '${lines.length} Item${lines.length == 1 ? '' : 's'} ordered',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Ld.navy,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 24, color: Ld.navy),
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
            crossFadeState:
                expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(bottom: 4),
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
        // Total (always visible)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Ld.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n?.total ?? 'Total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Ld.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatKip(order['amount_total'] ?? 0),
                    style: Ld.price(19),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Transfer slip placeholder beside the lines (wide cards); opens the
  /// same proof dialog as the "View Proof" button.
  Widget _buildSlipTile(BuildContext context) {
    final label = AppLocalizations.of(context)?.viewProof ?? 'View Proof';
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Ld.ground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ld.r),
          side: const BorderSide(color: Ld.faint),
        ),
        child: InkWell(
          onTap: onViewProof,
          borderRadius: BorderRadius.circular(Ld.r),
          child: SizedBox(
            width: 120,
            height: 140,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_search_rounded,
                      size: 34, color: Ld.navy),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Ld.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context,
      {required bool showProofButton, required double width}) {
    final l10n = AppLocalizations.of(context);
    final rejectLabel = _isPayAtStore
        ? (l10n?.reject ?? 'Reject')
        : (l10n?.rejectOrder ?? 'Reject Order');
    final confirmLabel = _isPayAtStore
        ? (l10n?.quickConfirm ?? 'Quick Confirm')
        : (l10n?.confirm ?? 'Confirm');
    const shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Ld.rMd)));
    final reject = OutlinedButton.icon(
      onPressed: onReject,
      icon: const Icon(Icons.close_rounded, size: 20),
      label: Text(rejectLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Ld.danger,
        side: const BorderSide(color: Ld.dangerLine),
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
    final confirm = FilledButton.icon(
      onPressed: onConfirm,
      icon: Icon(
          _isPayAtStore
              ? Icons.done_all_rounded
              : Icons.check_circle_outline_rounded,
          size: 20),
      label: Text(confirmLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showProofButton) ...[
          OutlinedButton.icon(
            onPressed: onViewProof,
            icon: const Icon(Icons.image_search_rounded, size: 20),
            label: Text(l10n?.viewProof ?? 'View Proof',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: Ld.navy,
              side: const BorderSide(color: Ld.line),
              minimumSize: const Size.fromHeight(Ld.tap),
              shape: shape,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (width < 440) ...[
          // Narrow cards: main action on top, full width.
          confirm,
          const SizedBox(height: 10),
          reject,
        ] else
          Row(
            children: [
              Expanded(child: reject),
              const SizedBox(width: 10),
              Expanded(flex: width >= 560 ? 2 : 1, child: confirm),
            ],
          ),
      ],
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
    final name = bilingualName(
      line,
      fallback: AppLocalizations.of(context)?.item ?? 'Item',
    );
    final qty = line['qty'] ?? line['quantity'] ?? 1;
    final subtotal = line['subtotal'] ??
        line['price_subtotal'] ??
        line['price_unit'] ??
        0;
    final toppings = (line['toppings'] as List?) ?? [];
    final note = line['note']?.toString() ?? '';

    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: isLast ? 2 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${qty.toString()}×',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Ld.navy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Ld.ink,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatKip(subtotal),
                style: Ld.price(15, color: Ld.ink, weight: FontWeight.w600),
              ),
            ],
          ),
          if (toppings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(
                '+ ${toppings.map((t) => t['name'] ?? t.toString()).join(', ')}',
                style: Ld.small,
              ),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(
                'Note: $note',
                style: const TextStyle(
                  fontSize: 13,
                  color: Ld.warning,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 26),
              child: Divider(height: 1, thickness: 1, color: Ld.lineSoft),
            ),
        ],
      ),
    );
  }
}

// ─── Small helpers ───────────────────────────────────────────────────────────

/// Customer phone; tappable (call confirmation) when there is a number.
class _PhoneLink extends StatelessWidget {
  const _PhoneLink({required this.phone, this.onTap});
  final String phone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.phone_outlined,
            size: 16, color: active ? Ld.navy : Ld.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            phone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: active ? Ld.navy : Ld.muted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              decoration: active ? TextDecoration.underline : null,
            ),
          ),
        ),
      ],
    );
    if (!active) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: body,
        ),
      ),
    );
  }
}
