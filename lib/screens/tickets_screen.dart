import 'dart:async';
import 'package:ladolce/l10n/app_localizations.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';
import '../widgets/topping_picker.dart';
import '../utils/money.dart';
import '../theme/ld.dart';

/// Result object returned when a ticket is resumed
class ResumedTicket {
  final int? orderId; // null for offline tickets
  final String orderName;
  final int? tableId;
  final String? tableName;
  final String ticketLabel;
  final int queueNumber;
  final String paymentType;
  final int? paymentMethodId;
  final String paymentMethodName;
  final List<CartItem> cartItems;
  final bool isOffline;
  final bool isSelfOrder;
  final String deliveryStatus;
  final int? partnerId;
  final String partnerName;
  final String deliveryPlaceName;
  final String deliveryPlaceAddress;
  final String discountType;
  final double discountValue;
  final double discountAmount;

  ResumedTicket({
    this.orderId,
    required this.orderName,
    this.tableId,
    this.tableName,
    this.ticketLabel = '',
    this.queueNumber = 0,
    this.paymentType = '',
    this.paymentMethodId,
    this.paymentMethodName = '',
    required this.cartItems,
    this.isOffline = false,
    this.isSelfOrder = false,
    this.deliveryStatus = 'none',
    this.partnerId,
    this.partnerName = '',
    this.deliveryPlaceName = '',
    this.deliveryPlaceAddress = '',
    this.discountType = '',
    this.discountValue = 0.0,
    this.discountAmount = 0.0,
  });
}

/// A display-ready ticket that merges online & offline sources
class _DisplayTicket {
  final int? id; // null if offline
  final String name;
  final int? tableId;
  final String? tableName;
  final String ticketLabel;
  final double amountTotal;
  final int queueNumber;
  final String paymentType;
  final int? paymentMethodId;
  final String paymentMethodName;
  final List<TicketLine> lines;
  final bool isOffline;
  final int? offlineIndex;

  /// When the ticket was first opened — used to show live duration badge.
  final DateTime? openedAt;
  final String note;
  final bool isSelfOrder;
  final String deliveryStatus;
  final int? partnerId;
  final String partnerName;
  final String deliveryPlaceName;
  final String deliveryPlaceAddress;
  final String discountType;
  final double discountValue;
  final double discountAmount;

  _DisplayTicket({
    this.id,
    required this.name,
    this.tableId,
    this.tableName,
    this.ticketLabel = '',
    required this.amountTotal,
    this.queueNumber = 0,
    this.paymentType = '',
    this.paymentMethodId,
    this.paymentMethodName = '',
    required this.lines,
    this.isOffline = false,
    this.offlineIndex,
    this.openedAt,
    this.note = '',
    this.isSelfOrder = false,
    this.deliveryStatus = 'none',
    this.partnerId,
    this.partnerName = '',
    this.deliveryPlaceName = '',
    this.deliveryPlaceAddress = '',
    this.discountType = '',
    this.discountValue = 0.0,
    this.discountAmount = 0.0,
  });
}

class TicketsScreen extends StatefulWidget {
  final List<Product> cachedProducts;

  const TicketsScreen({super.key, required this.cachedProducts});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<_DisplayTicket> _tickets = [];
  final Set<int> _notifyingReadyOrderIds = {};
  // Ready sent in this session (the list refresh brings delivery_status).
  final Set<int> _readySentOrderIds = {};
  Timer? _tickTimer;
  late final Map<int, Product> _productById;

  /// List rows instead of the card grid; remembered per device.
  static const _listViewKey = 'tickets_list_view';
  bool _listView = false;

  @override
  void initState() {
    super.initState();
    _productById = {for (final p in widget.cachedProducts) p.id: p};
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getBool(_listViewKey) ?? false;
      if (mounted && saved != _listView) setState(() => _listView = saved);
    }).catchError((_) {});
    _fetchTickets(backgroundRefresh: false);
    // Rebuild every minute so duration badges stay current
    _tickTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTickets({required bool backgroundRefresh}) async {
    if (!backgroundRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      // Keep UI responsive while refreshing in background.
      setState(() => _errorMessage = null);
    }

    final List<_DisplayTicket> combined = [];

    // ── 1. Load offline queue ──────────────────────────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineList = prefs.getStringList('offline_orders') ?? [];
      for (int i = 0; i < offlineList.length; i++) {
        final raw = offlineList[i];
        try {
          final Map<String, dynamic> task = jsonDecode(raw);
          // Only show offline DRAFT/OPEN tickets here.
          // Paid orders are represented in Receipt History as "Unsynced" and must NOT be resumable.
          //
          // We treat only 'create' as an open ticket. 'submit' is used for paid offline receipts.
          if (task['action'] != 'create' && task['action'] != null) {
            continue;
          }
          final mapPayload =
              task['payload'] ?? task; // Fallback to task if old format
          if (mapPayload is Map && mapPayload['is_paid'] == true) {
            continue;
          }
          final rawLines = mapPayload['lines'] as List? ?? [];

          final List<TicketLine> lines = rawLines.map((l) {
            final product = _productById[l['product_id']];
            return TicketLine(
              productId: l['product_id'],
              productName: product?.name ?? 'Product #${l['product_id']}',
              qty: (l['qty'] ?? 1).toInt(),
              priceUnit: ((l['price_unit'] ?? 0) as num).toDouble(),
              note: (l['note'] ?? '').toString(),
            );
          }).toList();

          final total = lines.fold<double>(
            0.0,
            (sum, l) => sum + l.qty * l.priceUnit,
          );

          combined.add(
            _DisplayTicket(
              id: task['mock_id'], // So it can be identified
              name: 'OFFLINE #${i + 1}',
              tableId: mapPayload['table_id'],
              // A ticket saved under a name offline shows that name.
              tableName: (mapPayload['ticket_label'] ?? '').toString().isNotEmpty
                  ? mapPayload['ticket_label'].toString()
                  : null,
              ticketLabel: (mapPayload['ticket_label'] ?? '').toString(),
              amountTotal: total,
              lines: lines,
              isOffline: true,
              offlineIndex: i, // Save actual index in list
              partnerId: mapPayload['partner_id'] is int
                  ? mapPayload['partner_id'] as int
                  : null,
            ),
          );
        } catch (_) {}
      }
    } catch (_) {
      // ignore offline parse errors
    }

    // ── 2. Load online tickets from Odoo ──────────────────────────────────
    try {
      // Load cached tickets instantly for fast UI, then refresh server in background.
      final onlineTickets = await _apiService.fetchOpenTickets(
        forceRefresh: false,
      );
      for (final t in onlineTickets) {
        // Prevent showing duplicate mock tickets that exist in BOTH offline_queue and cached_open_tickets
        if (combined.any((existing) => existing.id == t.id)) {
          continue;
        }

        combined.add(
          _DisplayTicket(
            id: t.id,
            name: t.name,
            tableId: t.tableId,
            tableName: t.tableName,
            ticketLabel: t.ticketLabel,
            amountTotal: t.amountTotal,
            queueNumber: t.queueNumber,
            paymentType: t.paymentType,
            paymentMethodId: t.paymentMethodId,
            paymentMethodName: t.paymentMethodName,
            lines: t.lines,
            isOffline: false,
            openedAt: t.openedAt,
            note: t.note,
            isSelfOrder: t.isSelfOrder,
            deliveryStatus: t.deliveryStatus,
            partnerId: t.partnerId,
            partnerName: t.partnerName,
            deliveryPlaceName: t.deliveryPlaceName,
            deliveryPlaceAddress: t.deliveryPlaceAddress,
            discountType: t.discountType,
            discountValue: t.discountValue,
            discountAmount: t.discountAmount,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Tickets] fetchOpenTickets failed: $e');
      if (combined.isEmpty) {
        setState(() {
          _errorMessage = 'Could not load tickets. Please check your connection and try again.';
          _isLoading = false;
        });
        return;
      }
      // If we have offline tickets, just show them even if online fails
    }

    setState(() {
      _tickets = combined;
      _isLoading = false;
    });

    // Background refresh: update with freshest server state without blocking UI.
    if (!backgroundRefresh) {
      // ignore: unawaited_futures
      _refreshFromServer();
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final onlineTickets = await _apiService.fetchOpenTickets(
        forceRefresh: true,
      );
      if (!mounted) return;
      final List<_DisplayTicket> refreshed = [];

      // Keep offline tickets on top as before
      final offline = _tickets.where((t) => t.isOffline).toList();
      refreshed.addAll(offline);

      for (final t in onlineTickets) {
        if (refreshed.any((existing) => existing.id == t.id)) continue;
        refreshed.add(
          _DisplayTicket(
            id: t.id,
            name: t.name,
            tableId: t.tableId,
            tableName: t.tableName,
            ticketLabel: t.ticketLabel,
            amountTotal: t.amountTotal,
            queueNumber: t.queueNumber,
            paymentType: t.paymentType,
            paymentMethodId: t.paymentMethodId,
            paymentMethodName: t.paymentMethodName,
            lines: t.lines,
            isOffline: false,
            openedAt: t.openedAt,
            note: t.note,
            isSelfOrder: t.isSelfOrder,
            deliveryStatus: t.deliveryStatus,
            partnerId: t.partnerId,
            partnerName: t.partnerName,
            deliveryPlaceName: t.deliveryPlaceName,
            deliveryPlaceAddress: t.deliveryPlaceAddress,
            discountType: t.discountType,
            discountValue: t.discountValue,
            discountAmount: t.discountAmount,
          ),
        );
      }

      setState(() {
        _tickets = refreshed;
        _isLoading = false;
      });
    } catch (_) {
      // Silent background refresh failure; cached UI remains usable.
    }
  }

  Future<void> _resumeTicket(_DisplayTicket ticket) async {
    List<CartItem> cartItems = [];
    for (var line in ticket.lines) {
      final product = widget.cachedProducts
          .where((p) => p.id == line.productId)
          .firstOrNull;
      if (product != null) {
        cartItems.add(
          CartItem(
            product: product,
            quantity: line.qty,
            isSaved: true,
            isPrinted: true, // already sent to kitchen when originally saved
            priceUnitFromOrder: line.priceUnit,
            kitchenNote: line.note,
            isFreePromo: line.isFreePromo,
            promotionId: line.promotionId,
            // Choices (Iced, Size L...) were dropped on reopen, so the cart
            // and the receipt lost them. The price above already includes them.
            selectedToppings: ToppingRules.ordered([
              for (final t in product.toppings)
                if (line.toppingIds.contains(t.id)) t,
            ]),
          ),
        );
      } else {
        debugPrint('Product ${line.productId} not found in catalog. Creating dummy product for line.');
        final dummyProduct = Product(
          id: line.productId,
          name: line.productName.isNotEmpty ? line.productName : (AppLocalizations.of(context)?.discountCustomItem ?? 'Discount / Custom Item'),
          price: line.priceUnit,
          category: (AppLocalizations.of(context)?.system ?? 'System'),
        );
        cartItems.add(
          CartItem(
            product: dummyProduct,
            quantity: line.qty,
            isSaved: true,
            isPrinted: true,
            priceUnitFromOrder: line.priceUnit,
            kitchenNote: line.note,
          ),
        );
      }
    }

    // If it's an offline ticket, popping it removes it from the queue so it can be merged/charged
    if (ticket.isOffline && ticket.offlineIndex != null) {
      final prefs = await SharedPreferences.getInstance();
      var offlineList = prefs.getStringList('offline_orders') ?? [];
      if (ticket.offlineIndex! < offlineList.length) {
        offlineList.removeAt(ticket.offlineIndex!);
        await prefs.setStringList('offline_orders', offlineList);
      }
    }

    if (!mounted) return;

    Navigator.pop(
      context,
      ResumedTicket(
        orderId: ticket.id,
        orderName: ticket.name,
        queueNumber: ticket.queueNumber,
        tableId: ticket.tableId,
        tableName: ticket.tableName,
        ticketLabel: ticket.ticketLabel,
        paymentType: ticket.paymentType,
        paymentMethodId: ticket.paymentMethodId,
        paymentMethodName: ticket.paymentMethodName,
        cartItems: cartItems,
        isOffline: ticket.isOffline,
        isSelfOrder: ticket.isSelfOrder,
        partnerId: ticket.partnerId,
        partnerName: ticket.partnerName,
        deliveryPlaceName: ticket.deliveryPlaceName,
        deliveryPlaceAddress: ticket.deliveryPlaceAddress,
        discountType: ticket.discountType,
        discountValue: ticket.discountValue,
        discountAmount: ticket.discountAmount,
      ),
    );
  }

  Future<void> _notifySelfOrderReady(_DisplayTicket ticket) async {
    final orderId = ticket.id;
    if (orderId == null || _notifyingReadyOrderIds.contains(orderId)) return;

    setState(() => _notifyingReadyOrderIds.add(orderId));
    try {
      await _apiService.notifySelfOrderReady(orderId);
      if (!mounted) return;
      setState(() => _readySentOrderIds.add(orderId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ticket.name} ready notification sent.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[Tickets] notifyReady failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.couldNotSendNotificationPleaseTry ?? (AppLocalizations.of(context)?.couldNotSendNotificationPleaseTry ?? 'Could not send notification. Please try again.')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _notifyingReadyOrderIds.remove(orderId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showSummary = !_isLoading && _errorMessage == null && _tickets.isNotEmpty;
    final grandTotal = _tickets.fold<double>(0, (s, t) => s + t.amountTotal);
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.openTickets ?? 'Open Tickets',
        subtitle: showSummary ? '${_tickets.length}  ·  ₭${money(grandTotal)}' : null,
        actions: [
          LdNavIconButton(
            icon: _listView ? Icons.grid_view_rounded : Icons.view_list_rounded,
            tooltip: _listView
                ? (l10n?.switchToGrid ?? 'Switch to Grid')
                : (l10n?.switchToList ?? 'Switch to List'),
            onPressed: () {
              setState(() => _listView = !_listView);
              SharedPreferences.getInstance()
                  .then((prefs) => prefs.setBool(_listViewKey, _listView))
                  .catchError((_) => false);
            },
          ),
          LdNavIconButton(
            icon: Icons.refresh_rounded,
            tooltip: l10n?.refresh ?? 'Refresh',
            onPressed: () => _fetchTickets(backgroundRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LdIconTile(Icons.wifi_off_rounded, size: 64, background: Ld.dangerWash, color: Ld.danger),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: Ld.body.copyWith(color: Ld.danger)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _fetchTickets(backgroundRefresh: false),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n?.retry ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchTickets(backgroundRefresh: true),
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
                      const LdIconTile(Icons.receipt_long_outlined, size: 72, background: Colors.white),
                      const SizedBox(height: 14),
                      Text(
                        l10n?.noOpenTickets ?? 'No open tickets',
                        textAlign: TextAlign.center,
                        style: Ld.title(20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Bottom inset: last ticket stays above the 3-button navigation bar.
    final bottom = 16 + Ld.navInset(context);
    final tablet = Ld.isTablet(context);
    final side = tablet ? 24.0 : 16.0;

    if (_listView) {
      return RefreshIndicator(
        onRefresh: () => _fetchTickets(backgroundRefresh: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, 16, side, bottom),
          itemCount: _tickets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildTicketRow(_tickets[index]),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 14.0;
        final avail = c.maxWidth - side * 2;
        // One card per row on the smallest phones, two on phones, and
        // cards about 360 px wide on tablets (three across at 1280).
        final int cols;
        if (c.maxWidth < 340) {
          cols = 1;
        } else if (!tablet) {
          cols = (avail / 300).floor().clamp(2, 3);
        } else {
          cols = ((avail + spacing) / (360 + spacing)).floor().clamp(2, 5);
        }
        final cellW = (avail - spacing * (cols - 1)) / cols;
        final narrow = cellW < _wideCardMin;
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
        // Fixed height that grows with the text size.
        final extent = (narrow ? 236.0 : 192.0) * scale;
        return RefreshIndicator(
          onRefresh: () => _fetchTickets(backgroundRefresh: true),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, 16, side, bottom),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: extent,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: _tickets.length,
            itemBuilder: (context, index) => _buildTicketCard(_tickets[index], narrow: narrow),
          ),
        );
      },
    );
  }

  /// Cards narrower than this stack the total above the "order ready" button.
  static const double _wideCardMin = 300;

  /// Returns a human-readable "open for" string, e.g. "5 min", "1h 23m".
  String _formatElapsed(DateTime openedAt) {
    final diff = DateTime.now().difference(openedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Color for the duration badge based on how long the table has been open.
  Color _durationColor(DateTime openedAt) {
    final mins = DateTime.now().difference(openedAt).inMinutes;
    if (mins < 30) return Ld.success;
    if (mins < 60) return Ld.warning;
    return Ld.danger; // over 1 hour — draw attention
  }

  Color _durationWash(DateTime openedAt) {
    final mins = DateTime.now().difference(openedAt).inMinutes;
    if (mins < 30) return Ld.successWash;
    if (mins < 60) return Ld.warningWash;
    return Ld.dangerWash;
  }

  /// The offline label without its emoji (an icon is shown instead).
  String _offlineText() =>
      (AppLocalizations.of(context)?.offline ?? 'Offline').replaceAll('⚡', '').trim();

  String _itemsText(int count) =>
      AppLocalizations.of(context)?.itemsCount('$count') ?? '$count item${count == 1 ? '' : 's'}';

  /// Time-open pill (colored by age) or the offline pill, plus the note.
  List<Widget> _statusPills(_DisplayTicket ticket) {
    final openedAt = ticket.openedAt;
    return [
      if (ticket.isOffline)
        LdPill(_offlineText(), background: Ld.warningWash, foreground: Ld.warning, icon: Icons.cloud_off_rounded)
      else if (openedAt != null)
        LdPill(
          _formatElapsed(openedAt),
          background: _durationWash(openedAt),
          foreground: _durationColor(openedAt),
          icon: Icons.schedule_rounded,
        ),
      if (!ticket.isOffline && ticket.note.isNotEmpty)
        LdPill(ticket.note, background: Ld.goldWash, foreground: Ld.goldWashInk, icon: Icons.edit_note_rounded),
    ];
  }

  Widget _buildTicketCard(_DisplayTicket ticket, {required bool narrow}) {
    final isSelfOrderTicket = ticket.isSelfOrder && !ticket.isOffline;
    final isNotifyingReady =
        ticket.id != null && _notifyingReadyOrderIds.contains(ticket.id);
    final hasPlace = ticket.tableName != null || ticket.tableId != null;
    final total = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        '₭${money(ticket.amountTotal)}',
        maxLines: 1,
        style: Ld.price(narrow ? 19 : 22, color: Ld.ink),
      ),
    );

    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rLg),
        side: BorderSide(color: ticket.isOffline ? Ld.gold : Ld.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _resumeTicket(ticket),
        child: Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 12 : 18, 14, narrow ? 12 : 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _placeText(ticket),
                          maxLines: narrow ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ld.title(narrow ? 17 : 21, color: hasPlace ? Ld.navy : Ld.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ticket.name}, ${_itemsText(ticket.lines.length)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ld.small,
                        ),
                      ],
                    ),
                  ),
                  if (!narrow) ...[
                    const SizedBox(width: 10),
                    Icon(ticket.isOffline ? Icons.cloud_off_rounded : _placeIcon(ticket),
                        color: Ld.faint, size: 22),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: _statusPills(ticket)),
              const Spacer(),
              if (!isSelfOrderTicket)
                total
              else if (narrow) ...[
                total,
                const SizedBox(height: 8),
                SizedBox(height: 44, child: _orderReadyButton(ticket, isNotifyingReady)),
              ] else
                Row(
                  children: [
                    Expanded(child: total),
                    const SizedBox(width: 10),
                    SizedBox(height: 44, child: _orderReadyButton(ticket, isNotifyingReady)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A named ticket has no table; its tableName then holds the name.
  IconData _placeIcon(_DisplayTicket ticket) {
    if (ticket.ticketLabel.isNotEmpty) return Icons.person_pin_rounded;
    return ticket.tableName != null ? Icons.table_restaurant_rounded : Icons.receipt_rounded;
  }

  String _placeText(_DisplayTicket ticket) =>
      ticket.tableName ??
      (ticket.tableId != null
          ? 'Table #${ticket.tableId}'
          : (AppLocalizations.of(context)?.noTable2 ?? 'No Table'));

  Widget _orderReadyButton(_DisplayTicket ticket, bool isNotifyingReady) {
    final sent = ticket.deliveryStatus == 'ready' ||
        (ticket.id != null && _readySentOrderIds.contains(ticket.id));
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Ld.r)));
    if (sent && !isNotifyingReady) {
      // Already told the customer; tapping sends the notification again.
      return OutlinedButton.icon(
        onPressed: () => _notifySelfOrderReady(ticket),
        icon: const Icon(Icons.check_circle_rounded, size: 18),
        label: FittedBox(
          child: Text(
            AppLocalizations.of(context)?.orderReadySent ?? 'Ready ✓',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Ld.success,
          side: const BorderSide(color: Ld.success),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: shape,
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: isNotifyingReady ? null : () => _notifySelfOrderReady(ticket),
      icon: isNotifyingReady
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Ld.success),
            )
          : const Icon(Icons.notifications_active_outlined, size: 18),
      label: FittedBox(
        child: Text(
          AppLocalizations.of(context)?.orderReady ?? 'Order Ready',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Ld.successStrong,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Ld.successWash,
        disabledForegroundColor: Ld.success,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: shape,
      ),
    );
  }

  /// One open ticket as a full-width row: name or table, reference and item
  /// count, how long it has been open, and the total on the right.
  Widget _buildTicketRow(_DisplayTicket ticket) {
    final isOffline = ticket.isOffline;
    final isSelfOrderTicket = ticket.isSelfOrder && !isOffline;
    final isNotifyingReady =
        ticket.id != null && _notifyingReadyOrderIds.contains(ticket.id);
    final hasPlace = ticket.tableName != null || ticket.tableId != null;
    final pills = _statusPills(ticket);

    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rMd),
        side: BorderSide(color: isOffline ? Ld.gold : Ld.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _resumeTicket(ticket),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              LdIconTile(
                isOffline ? Icons.cloud_off_rounded : _placeIcon(ticket),
                background: isOffline ? Ld.warningWash : Ld.ground,
                color: isOffline ? Ld.warning : Ld.navy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _placeText(ticket),
                      style: Ld.title(17, color: hasPlace ? Ld.navy : Ld.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ticket.name}, ${_itemsText(ticket.lines.length)}',
                      style: Ld.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: pills),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('₭${money(ticket.amountTotal)}', style: Ld.price(18, color: Ld.ink)),
                    ),
                    if (isSelfOrderTicket) ...[
                      const SizedBox(height: 6),
                      SizedBox(height: 44, child: _orderReadyButton(ticket, isNotifyingReady)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
