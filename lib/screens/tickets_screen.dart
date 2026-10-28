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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.openTickets ?? (AppLocalizations.of(context)?.openTickets ?? 'Open Tickets')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_listView ? Icons.grid_view_rounded : Icons.view_list_rounded),
            tooltip: _listView
                ? (AppLocalizations.of(context)?.switchToGrid ?? 'Switch to Grid')
                : (AppLocalizations.of(context)?.switchToList ?? 'Switch to List'),
            onPressed: () {
              setState(() => _listView = !_listView);
              SharedPreferences.getInstance()
                  .then((prefs) => prefs.setBool(_listViewKey, _listView))
                  .catchError((_) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context)?.refresh ?? (AppLocalizations.of(context)?.refresh ?? 'Refresh'),
            onPressed: () => _fetchTickets(backgroundRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchTickets(backgroundRefresh: false),
              child: Text(AppLocalizations.of(context)?.retry ?? (AppLocalizations.of(context)?.retry ?? 'Retry')),
            ),
          ],
        ),
      );
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(AppLocalizations.of(context)?.noOpenTickets ?? (AppLocalizations.of(context)?.noOpenTickets ?? 'No open tickets'),
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_listView) {
      return ListView.separated(
        // Bottom inset: last ticket stays above the 3-button navigation bar.
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildTicketRow(_tickets[index]),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }

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
    if (mins < 30) return Colors.green.shade600;
    if (mins < 60) return Colors.orange.shade700;
    return Colors.red.shade600; // over 1 hour — draw attention
  }

  Widget _buildTicketCard(_DisplayTicket ticket) {
    final isOffline = ticket.isOffline;
    final isSelfOrderTicket = ticket.isSelfOrder && !isOffline;
    final accentColor = isOffline ? Colors.orange : const Color(0xFF1E3A8A);
    final openedAt = ticket.openedAt;
    final isNotifyingReady =
        ticket.id != null && _notifyingReadyOrderIds.contains(ticket.id);
    final bodyIconSize = isSelfOrderTicket ? 20.0 : 28.0;
    final tableFontSize = isSelfOrderTicket ? 12.0 : 15.0;
    final itemFontSize = isSelfOrderTicket ? 10.0 : 11.0;
    final totalFontSize = isSelfOrderTicket ? 16.0 : 18.0;

    return InkWell(
      onTap: () => _resumeTicket(ticket),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header row ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    isOffline ? Icons.cloud_off : Icons.receipt_long,
                    color: accentColor,
                    size: 18,
                  ),
                  Flexible(
                    child: Text(
                      ticket.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: accentColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),

              // ── Offline badge OR duration badge ───────────────────────
              if (isOffline)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(AppLocalizations.of(context)?.offline ?? (AppLocalizations.of(context)?.offline ?? '⚡ OFFLINE'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                if (openedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _durationColor(openedAt).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🕐 ${_formatElapsed(openedAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _durationColor(openedAt),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (ticket.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 14,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ticket.note,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const Divider(height: 1),

              // ── Body ─────────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _placeIcon(ticket),
                          color: accentColor,
                          size: bodyIconSize,
                        ),
                        SizedBox(height: isSelfOrderTicket ? 2 : 4),
                        Text(
                          _placeText(ticket),
                          style: TextStyle(
                            fontSize: tableFontSize,
                            fontWeight: FontWeight.bold,
                            color:
                                ticket.tableName != null ||
                                    ticket.tableId != null
                                ? Colors.black87
                                : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '${ticket.lines.length} item${ticket.lines.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: itemFontSize,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // ── Total ────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(top: isSelfOrderTicket ? 4 : 6),
                child: Text(
                  '₭${money(ticket.amountTotal)}',
                  style: TextStyle(
                    fontSize: totalFontSize,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isSelfOrderTicket) ...[
                const SizedBox(height: 6),
                SizedBox(height: 32, child: _orderReadyButton(ticket, isNotifyingReady)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A named ticket has no table; its tableName then holds the name.
  IconData _placeIcon(_DisplayTicket ticket) {
    if (ticket.ticketLabel.isNotEmpty) return Icons.person_pin_rounded;
    return ticket.tableName != null ? Icons.table_restaurant : Icons.receipt;
  }

  String _placeText(_DisplayTicket ticket) =>
      ticket.tableName ??
      (ticket.tableId != null
          ? 'Table #${ticket.tableId}'
          : (AppLocalizations.of(context)?.noTable2 ?? 'No Table'));

  Widget _orderReadyButton(_DisplayTicket ticket, bool isNotifyingReady) {
    final sent = ticket.deliveryStatus == 'ready' ||
        (ticket.id != null && _readySentOrderIds.contains(ticket.id));
    if (sent && !isNotifyingReady) {
      // Already told the customer; tapping sends the notification again.
      return OutlinedButton.icon(
        onPressed: () => _notifySelfOrderReady(ticket),
        icon: const Icon(Icons.check_circle_rounded, size: 15),
        label: FittedBox(
          child: Text(
            AppLocalizations.of(context)?.orderReadySent ?? 'Ready ✓',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF059669),
          side: const BorderSide(color: Color(0xFF059669)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: isNotifyingReady ? null : () => _notifySelfOrderReady(ticket),
      icon: isNotifyingReady
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_rounded, size: 15),
      label: FittedBox(
        child: Text(
          AppLocalizations.of(context)?.orderReady ?? 'Order Ready',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.green.shade100,
        disabledForegroundColor: Colors.green.shade800,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _badge(String text, Color color, {IconData? icon}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// One open ticket as a full-width row: name or table, reference and item
  /// count, how long it has been open, and the total on the right.
  Widget _buildTicketRow(_DisplayTicket ticket) {
    final isOffline = ticket.isOffline;
    final isSelfOrderTicket = ticket.isSelfOrder && !isOffline;
    final accentColor = isOffline ? Colors.orange : const Color(0xFF1E3A8A);
    final openedAt = ticket.openedAt;
    final isNotifyingReady =
        ticket.id != null && _notifyingReadyOrderIds.contains(ticket.id);
    final hasPlace = ticket.tableName != null || ticket.tableId != null;
    final itemCount = ticket.lines.length;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _resumeTicket(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accentColor.withOpacity(0.1),
                child: Icon(
                  isOffline ? Icons.cloud_off : _placeIcon(ticket),
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _placeText(ticket),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasPlace ? Colors.black87 : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ticket.name} · $itemCount item${itemCount == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isOffline)
                          _badge(
                            AppLocalizations.of(context)?.offline ?? '⚡ OFFLINE',
                            Colors.orange,
                          )
                        else if (openedAt != null)
                          _badge(
                            '🕐 ${_formatElapsed(openedAt)}',
                            _durationColor(openedAt),
                          ),
                        if (ticket.note.isNotEmpty)
                          _badge(
                            ticket.note,
                            Colors.amber.shade800,
                            icon: Icons.edit_note_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₭${money(ticket.amountTotal)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  if (isSelfOrderTicket) ...[
                    const SizedBox(height: 6),
                    SizedBox(height: 30, child: _orderReadyButton(ticket, isNotifyingReady)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
