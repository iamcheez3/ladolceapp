import 'package:flutter/material.dart';
import '../utils/bilingual_name.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/table.dart';
import '../models/payment_method.dart';
import '../models/ticket.dart';
import '../widgets/product_grid.dart';
import '../widgets/product_list.dart';
import '../widgets/cart_sidebar.dart';
import '../widgets/customer_selection_sheet.dart';
import '../widgets/skeleton_loaders.dart';
import '../screens/tickets_screen.dart';
import '../screens/receipt_history_screen.dart';
import '../screens/manage_items_screen.dart';
import '../screens/login_screen.dart';
import '../screens/split_ticket_screen.dart';
import '../screens/self_orders_review_screen.dart';
import '../screens/pos_settings_screen.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../services/push_notifications_service.dart';
import '../widgets/app_update_flow.dart';
import '../models/topping.dart';
import '../widgets/topping_picker.dart';
import '../models/free_promotion.dart';
import '../models/combo.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/ld.dart';
import 'package:intl/intl.dart';
import '../models/pos_tax_config.dart';
import '../models/pos_discount_config.dart';
import '../utils/pos_discount.dart';
import '../utils/responsive_layout.dart';
import '../utils/money.dart';
import 'package:flutter/services.dart';

class PosScreen extends StatefulWidget {
  final String cashierName;
  final int cashierId;
  final String role;

  const PosScreen({
    super.key,
    this.cashierName = 'Demo Cashier',
    this.cashierId = 1,
    this.role = 'cashier',
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  static const Color _brandNavy = Ld.navy;

  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  String? _cachedPosName;
  String? _cachedBranchName;
  PosTaxConfig _taxConfig = PosTaxConfig.disabled;
  PosDiscountConfig _discountConfig = PosDiscountConfig.disabled;
  PosDiscountOption? _selectedDiscountOption;
  DiscountBreakdown _discountBreakdown = DiscountBreakdown.none;
  double? _pendingDiscountManualValue;

  /// Shorthand for the generated lookups. Null-safe so every call site can
  /// fall back to its English literal if localisation is not ready yet.
  AppLocalizations? get _l10n => AppLocalizations.of(context);

  String? get _appliedDiscountType {
    if (!_discountConfig.enabled || !_discountBreakdown.active) return null;
    return _selectedDiscountOption?.type;
  }

  double? get _appliedDiscountValue {
    if (!_discountConfig.enabled || !_discountBreakdown.active) return null;
    final opt = _selectedDiscountOption;
    if (opt == null) return null;
    if (opt.type == 'percentage') {
      return opt.value ?? _pendingDiscountManualValue ?? 0.0;
    }
    return _discountBreakdown.discountAmount;
  }

  int _pendingSelfOrdersCount = 0;
  final Set<int> _pendingSelfOrderKnownIds = {};
  Timer? _pendingSelfOrdersTimer;
  bool _pendingSelfOrdersFetching = false;

  static int? _parseSelfOrderId(Map<String, dynamic> order) {
    final raw = order['id'];
    if (raw is int) return raw > 0 ? raw : null;
    return int.tryParse(raw?.toString() ?? '');
  }

  /// Pending list uses `customer`; newer APIs may send `customer_name` / `customer_phone`.
  static String _selfOrderNamePhoneSummary(Map<String, dynamic> order) {
    final name =
        (order['customer'] ??
                order['customer_name'] ??
                order['partner_name'] ??
                '')
            .toString()
            .trim();
    final phone =
        (order['customer_phone'] ??
                order['phone'] ??
                order['mobile'] ??
                order['partner_phone'] ??
                '')
            .toString()
            .trim();
    if (name.isEmpty && phone.isEmpty) return '';
    if (name.isNotEmpty && phone.isNotEmpty) return '$name · $phone';
    if (name.isNotEmpty) return name;
    return phone;
  }

  static String _newSelfOrderSnackText(Map<String, dynamic> order) {
    final summary = _selfOrderNamePhoneSummary(order);
    if (summary.isEmpty) return 'New self order waiting review';
    return 'New self order: $summary';
  }

  // ── Printer helper ────────────────────────────────────────────────────────
  List<CartItem> _filterItemsForPrinter(
    List<CartItem> items,
    PrinterProfile p,
  ) {
    if (p.categoryFilters.isEmpty) return items;
    final filters = p.categoryFilters
        .map((e) => e.trim().toLowerCase())
        .toSet();
    return items
        .where((i) => filters.contains(i.product.category.trim().toLowerCase()))
        .toList();
  }

  List<PrinterProfile> _resolveOrderPrinters() {
    final orderPrinters = printerService.profiles
        .where((p) => p.printOrders)
        .toList();
    if (orderPrinters.isNotEmpty) return orderPrinters;

    // Fallback: if no dedicated kitchen printer is enabled, use selected/default printer
    // so Save Ticket still sends order slips.
    if (printerService.profiles.isEmpty) return [];
    final selected = printerService.selectedReceiptPrinterId;
    if (selected != null) {
      final match = printerService.profiles
          .where((p) => p.id == selected)
          .toList();
      if (match.isNotEmpty) return [match.first];
    }
    return [printerService.profiles.first];
  }

  Future<int> _printOrderItemsToKitchen(
    List<CartItem> items, {
    required bool respectCategoryFilters,
    int? queueNumber,
  }) async {
    int printedCount = 0;
    Map<String, dynamic>? tpl;
    try {
      tpl = await _apiService.fetchBillTemplate(type: 'kitchen');
    } catch (_) {}
    final headerText = (tpl?['header_text'] ?? '').toString();
    final footerText = (tpl?['footer_text'] ?? '').toString();
    for (final p in _resolveOrderPrinters()) {
      final toPrint = respectCategoryFilters
          ? _filterItemsForPrinter(items, p)
          : items;
      if (toPrint.isEmpty) continue;
      final ok = await printerService.printOrderTicketDirect(
        profile: p,
        items: toPrint,
        cashierName: widget.cashierName,
        headerText: headerText,
        footerText: footerText,
        queueNumber: queueNumber,
      );
      if (ok) printedCount++;
    }
    return printedCount;
  }

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // View toggle
  bool _isGridView = true;

  List<Category> _categories = [Category(id: 'All', name: 'All Items')];

  List<Product> _products = [];
  List<CartItem> _cartItems = [];
  List<PosTable> _tables = [];
  List<PaymentMethod> _paymentMethods = [];
  PaymentMethod? _selectedPaymentMethod;

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Widget? trailing,
    /// Quick action row (slightly smaller, under the divider).
    bool quick = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? Ld.ground : Colors.transparent,
        borderRadius: BorderRadius.circular(Ld.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Ld.r),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: quick ? 52 : 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: isActive ? Ld.navy : Ld.muted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: quick ? 16 : 17,
                        height: 1.3,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? Ld.navy : Ld.ink,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPendingSelfOrders({bool notifyOnIncrease = true}) async {
    if (_pendingSelfOrdersFetching) return;
    _pendingSelfOrdersFetching = true;
    try {
      final data = await _apiService.fetchPendingSelfOrders();
      if (!mounted) return;
      final nextCount = data.length;
      final prevCount = _pendingSelfOrdersCount;
      final currentIds = <int>{
        for (final o in data)
          if (_parseSelfOrderId(o) != null) _parseSelfOrderId(o)!,
      };
      final newIds = currentIds.difference(_pendingSelfOrderKnownIds);

      setState(() {
        _pendingSelfOrdersCount = nextCount;
        _pendingSelfOrderKnownIds
          ..clear()
          ..addAll(currentIds);
      });

      if (!notifyOnIncrease) return;

      if (newIds.isNotEmpty) {
        final newcomers = data
            .where((o) => newIds.contains(_parseSelfOrderId(o)))
            .toList();
        if (newcomers.length == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_newSelfOrderSnackText(newcomers.first)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          final parts = newcomers
              .map(_selfOrderNamePhoneSummary)
              .where((s) => s.isNotEmpty)
              .toList();
          final detail = parts.isEmpty ? 'waiting review' : parts.join('; ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.newSelfOrdersCount('${newcomers.length}', detail) ??
        '${newcomers.length} new self orders: $detail'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } else if (nextCount > prevCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n?.newSelfOrderWaitingCount('$nextCount') ??
        'New self order waiting review ($nextCount pending)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // best-effort: no blocking UI
    } finally {
      _pendingSelfOrdersFetching = false;
    }
  }

  // Active ticket tracking: when a ticket is resumed, we know its backend order ID
  int? _activeTicketId;
  String? _activeTicketName;
  int? _activeTicketTableId;
  int _activeTicketQueueNumber = 0;
  String _activeTicketPaymentType = '';
  int? _activeTicketPaymentMethodId;
  String _activeTicketPaymentMethodName = '';
  bool _activeTicketIsSelfOrder = false;
  /// Customer already stored on the resumed ticket, so a save can tell whether
  /// the cashier changed it.
  int? _activeTicketPartnerId;
  String _activeTicketPartnerName = '';
  /// Name given to the ticket in place of a table ('' when it has none).
  String _activeTicketLabel = '';
  String _activeTicketDeliveryPlaceName = '';
  // ignore: unused_field
  String _activeTicketDeliveryPlaceAddress = '';
  Map<String, dynamic>? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _loadPromotionPriceSetting();
    PushNotificationsService.setAppActive(true);
    printerService.initialize();
    _loadPosProfileLabels();
    _fetchOdooProducts();
    // New app build uploaded in Odoo? Offer it once per app start, after the
    // menu has had time to load.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) AppUpdateFlow.checkOnStart(context);
    });

    // Self-order alert/badge: poll backend so POS is alerted even without FCM.
    _refreshPendingSelfOrders(notifyOnIncrease: false);
    _pendingSelfOrdersTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshPendingSelfOrders(),
    );
  }

  Future<void> _loadPromotionPriceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final usePromotion = prefs.getBool('pos_use_promotion_price') ?? true;
    if (mounted) {
      setState(() {
        Product.disablePromotionPrice = !usePromotion;
      });
    }
  }

  Future<void> _loadPosProfileLabels() async {
    try {
      final posName = await _apiService.getCachedPosName();
      final branchName = await _apiService.getCachedBranchName();
      final tax = await _apiService.getPosTaxConfig();
      final discount = await PosDiscountConfig.load();
      if (!mounted) return;
      setState(() {
        _cachedPosName = posName;
        _cachedBranchName = branchName;
        _taxConfig = tax;
        _discountConfig = discount;
        _selectedDiscountOption =
            _resolveSelectedDiscount(discount, _selectedDiscountOption);
        if (_selectedDiscountOption == null) {
          _pendingDiscountManualValue = null;
        }
      });
      _recomputeDiscount(manualValue: _pendingDiscountManualValue);
    } catch (_) {}
  }

  /// Re-points [current] at the equivalent option inside [config] after a
  /// reload. PosDiscountConfig.load() rebuilds its options from JSON and
  /// PosDiscountOption has no value equality, so keeping the old instance would
  /// trip DropdownButton's "exactly one item" assertion in the checkout sheet.
  /// Returns null when discounts are off or the option no longer exists.
  PosDiscountOption? _resolveSelectedDiscount(
    PosDiscountConfig config,
    PosDiscountOption? current,
  ) {
    if (!config.enabled || current == null) return null;
    for (final option in config.options) {
      if (option.id == current.id) return option;
    }
    return null;
  }

  void _recomputeDiscount({double? manualValue}) {
    final linesSum = _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final bd = computePosDiscount(
      linesSum,
      _selectedDiscountOption,
      manualValue: manualValue,
    );
    setState(() {
      _discountBreakdown = bd;
      _pendingDiscountManualValue = manualValue;
    });
  }

  void _clearDiscount() {
    setState(() {
      _selectedDiscountOption = null;
      _discountBreakdown = DiscountBreakdown.none;
      _pendingDiscountManualValue = null;
    });
  }

  // ignore: unused_element
  void _showApplyDiscountDialog() {
    final linesSum = _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    if (linesSum <= 0) return;

    PosDiscountOption? selectedOption = _selectedDiscountOption;
    double? manualVal = _pendingDiscountManualValue;

    final manualCtrl = TextEditingController(
      text: manualVal?.toStringAsFixed(0) ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(Icons.discount_outlined, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(_l10n?.applyDiscount ?? 'Apply Discount'),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_l10n?.selectDiscountOption ?? 'Select Discount Option',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PosDiscountOption?>(
                        value: selectedOption,
                        hint: Text(_l10n?.noDiscount ?? 'No Discount'),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<PosDiscountOption?>(
                            value: null,
                            child: Text(_l10n?.noDiscount ?? 'No Discount'),
                          ),
                          ..._discountConfig.options.map((opt) {
                            String valStr = '';
                            if (opt.value == null) {
                              valStr = opt.type == 'percentage'
                                  ? (_l10n?.customPercent ?? '(Custom %)')
                                  : (_l10n?.customAmount ?? '(Custom Amount)');
                            } else {
                              valStr = opt.type == 'percentage'
                                  ? '(${opt.value!.toStringAsFixed(0)}%)'
                                  : '(₭${money(opt.value!)})';
                            }
                            return DropdownMenuItem<PosDiscountOption?>(
                              value: opt,
                              child: Text('${opt.name} $valStr'),
                            );
                          }),
                        ],
                        onChanged: (opt) {
                          setDialogState(() {
                            selectedOption = opt;
                            if (opt == null || !opt.isManual) {
                              manualVal = null;
                              manualCtrl.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (selectedOption != null && selectedOption!.isManual) ...[
                    const SizedBox(height: 16),
                    Text(
                      selectedOption!.type == 'percentage'
                          ? (_l10n?.enterDiscountPercentage ?? 'Enter Discount Percentage')
                          : (_l10n?.enterDiscountAmount ?? 'Enter Discount Amount'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: manualCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixText: selectedOption!.type == 'percentage'
                            ? '%'
                            : null,
                        prefixText: selectedOption!.type == 'value'
                            ? '₭ '
                            : null,
                        hintText: selectedOption!.type == 'percentage'
                            ? (_l10n?.egTen ?? 'e.g. 10')
                            : (_l10n?.egFiveThousand ?? 'e.g. 5000'),
                      ),
                      onChanged: (v) {
                        manualVal = double.tryParse(v);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_l10n?.cancel ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _clearDiscount();
                  Navigator.pop(ctx);
                },
                child: Text(_l10n?.removeDiscount ?? 'Remove Discount',
                  style: TextStyle(color: Colors.red.shade400),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001460),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _selectedDiscountOption = selectedOption;
                    _pendingDiscountManualValue = manualVal;
                  });
                  _recomputeDiscount(manualValue: manualVal);
                  Navigator.pop(ctx);
                },
                child: Text(_l10n?.apply ?? 'Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  CartBreakdown _cartBreakdown() {
    final linesSum = _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    return computeCartBreakdown(
      linesSum,
      _taxConfig,
      selectedDiscountOption: _selectedDiscountOption,
      discountManualValue: _pendingDiscountManualValue,
    );
  }

  @override
  void dispose() {
    PushNotificationsService.setAppActive(false);
    _searchController.dispose();
    _pendingSelfOrdersTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOdooProducts({bool backgroundRefresh = false}) async {
    final branchId = await _apiService.getCachedBranchId();
    // "Buy X get Y free" promotions running at this branch (cart banner).
    _apiService.fetchFreePromotions(branchId: branchId).then((promos) {
      if (mounted) setState(() => _freePromotions = promos);
    });
    // ── Step 1: Load from cache instantly if available ────────────────────────
    if (!backgroundRefresh) {
      final cachedProducts = await _apiService.getCachedProducts(branchId: branchId);
      final cachedTables = await _apiService.getCachedTables();
      final cachedMethods = await _apiService.getCachedPaymentMethods();

      if (cachedProducts != null) {
        // We have cache — show it immediately, mark as NOT loading
        final Set<String> uniqueCategories = cachedProducts
            .map((p) => p.category)
            .toSet();
        setState(() {
          _products = cachedProducts;
          _tables = cachedTables ?? [];
          _paymentMethods = cachedMethods ?? [];
          if (_paymentMethods.isNotEmpty && _selectedPaymentMethod == null) {
            _selectedPaymentMethod = _paymentMethods.first;
          }
          _categories = [
            Category(id: 'All', name: 'All Items'),
            ...uniqueCategories.map((name) => Category(id: name, name: name)),
          ];
          _isLoading = false; // Show products right away!
        });

        // Then refresh silently in the background
        _fetchOdooProducts(backgroundRefresh: true);
        return;
      }

      // No cache — show spinner and do a full load
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // ── Step 2: Fetch fresh data from server ──────────────────────────────────
    try {
      // Sync offline orders quietly
      _apiService.syncOfflineOrders().then((syncedCount) {
        if (syncedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.syncedOfflineOrders('$syncedCount') ??
        '✅ Synced $syncedCount offline orders to server.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });

      // forceRefresh: fetchProducts is cache-first, so this "refresh" used to
      // hand back the same branch cache forever: nothing else writes it (Sync
      // fills the branch-less one), so product, price and topping changes never
      // reached the POS. Offline it still falls back to that cache.
      final products = await _apiService.fetchProducts(
        branchId: branchId,
        forceRefresh: true,
      );
      final rawCombos = await _apiService.fetchCombos();
      final combos = rawCombos
          .map((c) => Product.fromCombo(Combo.fromJson(c)))
          .toList();

      // Inject combos so they appear in POS
      products.addAll(combos);

      final tables = await _apiService.fetchTables();
      // Fresh: the drawer checkbox may have changed in the backend.
      final methods = await _apiService.fetchPaymentMethods(forceRefresh: true);

      final Set<String> uniqueCategories = products
          .map((p) => p.category)
          .toSet();

      // If there are combos, ensure 'Combos' is a distinct category tab
      if (combos.isNotEmpty) {
        uniqueCategories.add('Combos');
      }

      if (mounted) {
        setState(() {
          _products = products;
          _tables = tables;
          _paymentMethods = methods;
          if (_paymentMethods.isNotEmpty && _selectedPaymentMethod == null) {
            _selectedPaymentMethod = _paymentMethods.first;
          }
          _categories = [
            Category(id: 'All', name: 'All Items'),
            ...uniqueCategories.map((name) => Category(id: name, name: name)),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !backgroundRefresh) {
        // Only show error if we have nothing to show
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _syncAllDataAndRefresh() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.syncAllData();
      // Rebuild POS UI from the freshly-updated caches
      await _fetchOdooProducts(backgroundRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.syncedAllData ?? '✅ Synced all data.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n?.syncFailed('$e') ?? 'Sync failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addToCart(Product product) {
    if (product.toppings.isNotEmpty) {
      _showToppingsSelection(product);
    } else {
      _addDirectlyToCart(product, []);
    }
  }

  /// A product saved with price 0 has no fixed price: the cashier types it
  /// when adding it (combos and free promo items excepted).
  bool _isOpenPrice(Product product) =>
      !product.isCombo && product.price <= 0 && product.effectivePrice <= 0;

  Future<double?> _askOpenPrice(Product product) async {
    final ctrl = TextEditingController();
    double? valid() {
      final v = parseMoney(ctrl.text);
      return v > 0 ? v : null;
    }

    final price = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n?.enterPrice ?? 'Enter price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_l10n?.enterPriceHelp(product.displayName) ??
                '${product.displayName} has no fixed price. Enter the price for this order.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                prefixText: '₭ ',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                final v = valid();
                if (v != null) Navigator.pop(ctx, v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = valid();
              if (v != null) Navigator.pop(ctx, v);
            },
            child: Text(_l10n?.add ?? 'Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return price;
  }

  void _addDirectlyToCart(
    Product product,
    List<Topping> selectedToppings, {
    FreePromotion? freePromo,
    double? openPrice,
  }) {
    if (freePromo == null && openPrice == null && _isOpenPrice(product)) {
      _askOpenPrice(product).then((price) {
        if (price != null && mounted) {
          _addDirectlyToCart(product, selectedToppings, openPrice: price);
        }
      });
      return;
    }
    // Typed price (+ paid choices) for one unit; null = the product's price.
    final unitOverride = openPrice == null
        ? null
        : openPrice + selectedToppings.fold<double>(0, (s, t) => s + t.extraPrice);
    setState(() {
      // Check if there's already a NEW (unsaved) item with EXACTLY the same toppings
      final existingNewIndex = _cartItems.indexWhere((item) {
        if (item.product.id != product.id || item.isSaved) return false;
        if (item.kitchenNote.trim().isNotEmpty) return false;
        // A free item only stacks with free items of the same promotion.
        if (item.isFreePromo != (freePromo != null) || item.promotionId != freePromo?.id) {
          return false;
        }
        // Typed prices only stack when they are the same.
        if (item.priceUnitFromOrder != unitOverride) return false;

        // Compare toppings exactly
        if (item.selectedToppings.length != selectedToppings.length) {
          return false;
        }
        final selectedIds = selectedToppings.map((t) => t.id).toSet();
        final itemToppingIds = item.selectedToppings.map((t) => t.id).toSet();
        if (selectedIds.containsAll(itemToppingIds) &&
            itemToppingIds.containsAll(selectedIds)) {
          return true;
        }
        return false;
      });

      if (existingNewIndex >= 0) {
        _cartItems[existingNewIndex].quantity++;
      } else {
        _cartItems.add(
          CartItem(
            product: product,
            isSaved: false,
            selectedToppings: selectedToppings,
            isFreePromo: freePromo != null,
            promotionId: freePromo?.id,
            promotionName: freePromo?.name ?? '',
            priceUnitFromOrder: unitOverride,
          ),
        );
      }
    });
  }

  Future<void> _editCartItemKitchenNote(
    CartItem item, {
    VoidCallback? onUpdated,
  }) async {
    final controller = TextEditingController(text: item.kitchenNote);
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(_l10n?.kitchenNote ?? 'Kitchen note',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: _l10n?.kitchenNoteHint ?? 'Less sugar, no ice, extra spicy...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(_l10n?.clear ?? 'Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandNavy,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_l10n?.save ?? 'Save'),
          ),
        ],
      ),
    );
    if (note == null) return;
    setState(() => item.kitchenNote = note.trim());
    onUpdated?.call();
  }

  /// Names the open ticket (e.g. after the customer) instead of a table. The
  /// server releases the table for a new order; the name only lives on this
  /// order, so it is gone once the ticket is charged or cleared.
  Future<void> _showRenameTicketDialog(BuildContext context) async {
    final orderId = _activeTicketId;
    if (orderId == null || orderId <= 0) return;
    final label = await _promptTicketName(
      context,
      title: _l10n?.renameTicketAction ?? 'Rename ticket',
      help: _l10n?.ticketNameHelp ??
          'The ticket shows this name instead of a table, and its table becomes free for a new order.',
      initial: _activeTicketLabel,
    );
    if (label == null || label.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _apiService.renameTicket(
        orderId: orderId,
        label: label,
        releasedTableId: _activeTicketTableId,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_l10n?.renameTicketFailed('$e') ?? 'Rename failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _activeTicketLabel = label;
      // The table now belongs to no one: later saves must not send it back.
      _activeTicketTableId = null;
    });
    try {
      final freshTables = await _apiService.fetchTables(forceRefresh: true);
      if (mounted) setState(() => _tables = freshTables);
    } catch (_) {}
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _l10n?.ticketRenamed(label) ?? 'Ticket renamed to $label. Its table is free again.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Asks for a ticket name; suggests [initial], else the selected customer.
  /// Returns null when cancelled.
  Future<String?> _promptTicketName(
    BuildContext context, {
    required String title,
    required String help,
    String initial = '',
  }) {
    final suggestion = initial.isNotEmpty
        ? initial
        : (_selectedCustomer?['name']?.toString() ?? '');
    final controller = TextEditingController(text: suggestion);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              decoration: InputDecoration(
                labelText: _l10n?.ticketNameLabel ?? 'Ticket name',
                hintText: _l10n?.ticketNameHint ?? 'e.g. customer name',
                border: const OutlineInputBorder(),
              ),
            ),
            Text(help, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandNavy,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_l10n?.save ?? 'Save'),
          ),
        ],
      ),
    );
  }

  void _showToppingsSelection(Product product, {FreePromotion? freePromo, VoidCallback? onAdded}) {
    // Admin defaults (e.g. Hot, Size M) are ticked when the sheet opens.
    List<Topping> selectedToppings = ToppingRules.defaults(product.toppings);
    final hasRequired = product.toppings.any((t) => t.groupId != null && t.groupRequired);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                16 + LaDolcePosUi.modalBottomPadding(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _l10n?.selectToppingsFor(product.displayName) ??
        'Select Toppings for ${product.displayName}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Ld.title(21),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: ToppingPicker(
                        toppings: product.toppings,
                        selected: selectedToppings,
                        accent: Ld.navy,
                        addOnsTitle: _l10n?.toppingAddOns ?? 'Add-ons',
                        onChanged: (next) =>
                            setSheetState(() => selectedToppings = next),
                      ),
                    ),
                  ),
                  Builder(builder: (context) {
                    final missing =
                        ToppingRules.missing(product.toppings, selectedToppings);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (missing.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _l10n?.toppingChooseMissing(
                                    missing.map((s) => s.title).join(', '),
                                  ) ??
                                  'Please choose: ${missing.map((s) => s.title).join(', ')}',
                              style: const TextStyle(
                                color: Ld.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Not offered when a choice is required (e.g. Size).
                            if (!hasRequired) ...[
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(64, 52),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _addDirectlyToCart(
                                      product,
                                      [],
                                      freePromo: freePromo,
                                    ); // Skip toppings completely
                                    onAdded?.call();
                                  },
                                  child: Text(
                                    _l10n?.addWithoutToppings ?? 'Add Without Toppings',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Ld.navy,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Ld.line,
                                  minimumSize: const Size(64, 52),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                onPressed: missing.isNotEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _addDirectlyToCart(product, selectedToppings, freePromo: freePromo);
                                        onAdded?.call();
                                      },
                                child: Text(
                                  _l10n?.addToOrder ?? 'Add To Order',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateQuantity(CartItem item, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.remove(item);
      } else {
        item.quantity = newQuantity;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _activeTicketId = null;
      _activeTicketName = null;
      _activeTicketTableId = null;
      _activeTicketQueueNumber = 0;
      _activeTicketPaymentType = '';
      _activeTicketPaymentMethodId = null;
      _activeTicketPaymentMethodName = '';
      _activeTicketPartnerId = null;
      _activeTicketLabel = '';
      _selectedCustomer = null;
      _discountBreakdown = DiscountBreakdown.none;
      _pendingDiscountManualValue = null;
    });
  }

  void _applyResumedTicket(ResumedTicket result) {
    setState(() {
      _cartItems = result.cartItems;
      _activeTicketId = result.orderId;
      _activeTicketName = result.orderName;
      _activeTicketQueueNumber = result.queueNumber;
      _activeTicketTableId = result.tableId;
      _activeTicketLabel = result.ticketLabel;
      _activeTicketPaymentType = result.paymentType;
      _activeTicketPaymentMethodId = result.paymentMethodId;
      _activeTicketPaymentMethodName = result.paymentMethodName;
      _activeTicketIsSelfOrder = result.isSelfOrder;
      _activeTicketPartnerId = result.partnerId;
      _activeTicketPartnerName = result.partnerName;
      // Resuming used to leave the customer empty, so the next save or charge
      // sent no partner and the customer looked lost.
      _selectedCustomer = result.partnerId != null
          ? {'id': result.partnerId, 'name': result.partnerName}
          : null;
      _activeTicketDeliveryPlaceName = result.deliveryPlaceName;
      _activeTicketDeliveryPlaceAddress = result.deliveryPlaceAddress;

      if (result.discountType.isNotEmpty) {
        if (result.discountType == 'percentage') {
          _selectedDiscountOption = _discountConfig.options.firstWhere(
            (o) => o.type == 'percentage' && o.value == result.discountValue,
            orElse: () => PosDiscountOption(id: 'custom_perc', type: 'percentage', value: result.discountValue, name: '${result.discountValue.toStringAsFixed(0)}% Off'),
          );
          _pendingDiscountManualValue = null;
        } else {
          _selectedDiscountOption = _discountConfig.options.firstWhere(
            (o) => o.type == 'value' && o.isManual,
            orElse: () => PosDiscountOption(id: 'custom_val', type: 'value', value: null, name: 'Discount (Value)'),
          );
          _pendingDiscountManualValue = result.discountValue > 0 ? result.discountValue : result.discountAmount;
        }
      } else {
        _selectedDiscountOption = null;
        _pendingDiscountManualValue = null;
      }
    });
    _recomputeDiscount(manualValue: _pendingDiscountManualValue);
  }

  /// Per-unit line price for API payloads (base + topping extras).
  /// Matches [CartItem.totalPrice] / qty so offline cached totals are consistent.
  double _lineUnitPrice(CartItem item) {
    if (item.isFreePromo) return 0.0;
    if (item.priceUnitFromOrder != null) {
      return item.priceUnitFromOrder!;
    }
    double unit = item.product.effectivePrice;
    for (final t in item.selectedToppings) {
      unit += t.extraPrice;
    }
    return unit;
  }

  Map<String, dynamic> _orderLinePayload(CartItem item) {
    final note = item.kitchenNote.trim();
    return {
      'product_id': item.product.id,
      'qty': item.quantity,
      'price_unit': _lineUnitPrice(item),
      'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
      if (note.isNotEmpty) 'note': note,
      if (item.isFreePromo) ...{
        'is_free_promo': true,
        'promotion_id': item.promotionId,
      },
    };
  }

  Future<void> _handleClearTicket(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_activeTicketId == null) {
      _clearCart();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(_l10n?.ticketCleared ?? 'Ticket cleared.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final adminPin = await _promptAdminPin(context);
    if (adminPin == null) return;

    try {
      await _apiService.deleteOrderWithAdminPin(
        orderId: _activeTicketId!,
        adminPin: adminPin,
      );
      _clearCart();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_l10n?.ticketRemovedByAdminPin ?? 'Ticket removed by Admin PIN.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_l10n?.cannotClearTicket('$e') ?? 'Cannot clear ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _promptAdminPin(BuildContext context) async {
    const pinLength = 4;
    String pin = '';
    bool hasError = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          void onDigit(String digit) {
            if (pin.length >= pinLength) return;
            setDialogState(() {
              pin += digit;
              hasError = false;
            });
            if (pin.length == pinLength) {
              Navigator.pop(dialogCtx, pin);
            }
          }

          void onBackspace() {
            if (pin.isEmpty) return;
            setDialogState(() {
              pin = pin.substring(0, pin.length - 1);
              hasError = false;
            });
          }

          Widget numButton(String number) {
            return InkWell(
              onTap: () => onDigit(number),
              borderRadius: BorderRadius.circular(36),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Ld.navyRaised,
                  border: Border.all(color: Ld.navyLine),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: Ld.price(28, color: Colors.white, weight: FontWeight.w600),
                  ),
                ),
              ),
            );
          }

          Widget actionButton(IconData icon, VoidCallback onTap) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(36),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Center(child: Icon(icon, color: Colors.white, size: 32)),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: _brandNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(_l10n?.adminPinRequired ?? 'Admin PIN Required',
              style: Ld.title(21, color: Colors.white),
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_l10n?.enterPinToClearTicket ?? 'Enter PIN to clear selected ticket',
                    style: TextStyle(color: Ld.onNavyMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pinLength,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < pin.length
                              ? Ld.gold
                              : Colors.transparent,
                          border: Border.all(
                            color: hasError
                                ? Ld.dangerLine
                                : (index < pin.length ? Ld.gold : Ld.onNavyMuted),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasError)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(_l10n?.pinIsRequired ?? 'PIN is required',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [numButton('1'), numButton('2'), numButton('3')],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [numButton('4'), numButton('5'), numButton('6')],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [numButton('7'), numButton('8'), numButton('9')],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72, height: 72),
                      numButton('0'),
                      actionButton(Icons.backspace_outlined, onBackspace),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, null),
                child: Text(_l10n?.cancel ?? 'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showInlineCart = ResponsiveLayout.showsPosCartRail(context);

    // Android Back used to close the POS and throw the unsaved cart away.
    return PopScope(
      canPop: !_cartItems.any((i) => !i.isSaved),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(_l10n?.leaveUnsavedTitle ?? 'Unsaved items'),
            content: Text(_l10n?.leaveUnsavedBody ??
                'The ticket has items that are not saved. Leave and discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_l10n?.cancel ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Ld.danger),
                child: Text(_l10n?.leaveUnsavedDiscard ?? 'Discard'),
              ),
            ],
          ),
        );
        if (leave != true || !context.mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          SystemNavigator.pop();
        }
      },
      child: GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        // Disable resizeToAvoidBottomInset to prevent keyboard animation loops
        // Each dialog/sheet handles its own keyboard padding via useSafeArea
        resizeToAvoidBottomInset: false,
        backgroundColor: Ld.ground,
        // Tablets (inline ticket rail): no app bar, the tools sit above the
        // products and on the ticket rail, as in the design.
        appBar: showInlineCart ? null : _buildPhoneAppBar(context),
        drawer: _buildDrawer(context),
        body: showInlineCart
            ? _buildTabletBody(context)
            : SafeArea(
                top: false,
                child: _buildCatalog(context, tablet: false),
              ),
        bottomNavigationBar: !showInlineCart && _cartItems.isNotEmpty
            ? _buildMobileCartBar(context)
            : null,
      ),
      ),
    );
  }

  /// Open Tickets screen; a picked ticket is loaded into the cart.
  Future<void> _openTicketsScreen(BuildContext context) async {
    final result = await Navigator.push<ResumedTicket>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketsScreen(cachedProducts: _products),
      ),
    );
    if (result != null) {
      _applyResumedTicket(result);
    }
  }

  /// Quantity of each product in the ticket (gold badge on the tiles).
  Map<int, int> _cartQuantities() {
    final out = <int, int>{};
    for (final item in _cartItems) {
      out[item.product.id] = (out[item.product.id] ?? 0) + item.quantity;
    }
    return out;
  }

  /// Name shown on the ticket: custom name, else table, else order name.
  String? get _ticketTitle {
    if (_activeTicketId == null) return null;
    if (_activeTicketLabel.isNotEmpty) return _activeTicketLabel;
    final table = _tables.where((t) => t.id == _activeTicketTableId).firstOrNull;
    if (table != null) return table.name;
    return _activeTicketName;
  }

  /// Order number under the ticket name when the name is a table / label.
  String? get _ticketSubtitle {
    final title = _ticketTitle;
    if (title == null || title == _activeTicketName) return null;
    return _activeTicketName;
  }

  String _categoryLabel(Category c) =>
      c.id == 'All' ? (_l10n?.allItems ?? c.name) : c.name;

  int _categoryCount(Category c) => c.name == 'All Items'
      ? _products.length
      : _products.where((p) => p.category == c.name).length;

  // ── Phone app bar ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildPhoneAppBar(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return AppBar(
      backgroundColor: Ld.navy,
      centerTitle: false,
      titleSpacing: 0,
      title: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _openTicketsScreen(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Ld.navyLine),
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.r)),
            textStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          icon: const Icon(Icons.receipt_long_outlined, size: 20),
          label: Text(
            narrow ? (_l10n?.tickets ?? 'Tickets') : (_l10n?.openTickets ?? 'Open Tickets'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      actions: [
        // Scanner Icon
        IconButton(
          onPressed: () {
            _openScannerDialog();
          },
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: _l10n?.scanVoucher ?? 'Scan Voucher',
        ),
        // View toggle (Grid / List)
        IconButton(
          onPressed: () {
            setState(() => _isGridView = !_isGridView);
          },
          icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
          tooltip: _isGridView
              ? (_l10n?.switchToList ?? 'Switch to List')
              : (_l10n?.switchToGrid ?? 'Switch to Grid'),
        ),
        // Ticket / Sync Operations Menu
        _ticketOptionsButton(context),
        SizedBox(width: narrow ? 4 : 8),
      ],
    );
  }

  /// 52 px white square tool button (tablet toolbar).
  Widget _squareButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Ld.surface,
            foregroundColor: Ld.navy,
            padding: EdgeInsets.zero,
            minimumSize: const Size(52, 52),
            side: const BorderSide(color: Ld.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }

  // ── Ticket options (⋯) ────────────────────────────────────────────────────
  /// The ticket options menu: in the phone app bar, or [onRail] as a 44 px
  /// outlined button on the navy ticket rail.
  Widget _ticketOptionsButton(BuildContext context, {bool onRail = false}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
      tooltip: _l10n?.ticketOptions ?? 'Ticket Options',
      style: onRail
          ? IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Ld.r),
                side: const BorderSide(color: Ld.navyLine),
              ),
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rXl),
      ),
      elevation: 8,
      color: Ld.surface,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      position: PopupMenuPosition.under,
      onSelected: (value) => _handleTicketOption(context, value),
      itemBuilder: (BuildContext menuCtx) => _ticketOptionItems(),
    );
  }

  List<PopupMenuEntry<String>> _ticketOptionItems() {
    final bool hasItems = _cartItems.isNotEmpty;
    final bool hasTicket = _activeTicketId != null;
    final bool ticketSelected = hasItems || hasTicket;

    PopupMenuItem<String> option(
      String value,
      IconData icon,
      String label, {
      bool enabled = true,
      bool danger = false,
    }) {
      final Color fg = !enabled ? Ld.faint : (danger ? Ld.danger : Ld.ink);
      return PopupMenuItem<String>(
        value: value,
        enabled: enabled,
        height: 52,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger && enabled ? Ld.dangerWash : Ld.ground,
                borderRadius: BorderRadius.circular(Ld.rSm),
              ),
              child: Icon(icon, size: 20, color: !enabled ? Ld.faint : (danger ? Ld.danger : Ld.navy)),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
          ],
        ),
      );
    }

    return <PopupMenuEntry<String>>[
      // ── Which ticket ────────────────────────────────────────────────────
      if (ticketSelected)
        PopupMenuItem<String>(
          enabled: false,
          height: 48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  _ticketTitle ?? (_l10n?.currentTicket2 ?? 'Current Ticket'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ld.title(19),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '₭${money(_cartBreakdown().totalDue)}',
                style: Ld.price(14, color: Ld.muted, weight: FontWeight.w600),
              ),
            ],
          ),
        ),

      // ── Printer actions ─────────────────────────────────────────────────
      option('print', Icons.receipt_outlined, _l10n?.printBill ?? 'Print bill', enabled: hasItems),
      option('reprint', Icons.print_outlined, _l10n?.reprintOrderKitchen ?? 'Reprint order (kitchen)',
          enabled: hasTicket),
      const PopupMenuDivider(),

      // ── Transfer actions ────────────────────────────────────────────────
      option('split', Icons.call_split_rounded, _l10n?.splitTicketAction ?? 'Split ticket',
          enabled: hasItems && hasTicket),
      option('move', Icons.swap_horiz_rounded, _l10n?.moveTicketAction ?? 'Move ticket',
          enabled: hasTicket),
      // Saved (server) tickets only: offline tickets have negative ids.
      option('rename', Icons.drive_file_rename_outline_rounded, _l10n?.renameTicketAction ?? 'Rename ticket',
          enabled: hasTicket && _activeTicketId! > 0),
      const PopupMenuDivider(),

      // ── Rider delivery ──────────────────────────────────────────────────
      option('send_to_rider', Icons.delivery_dining_rounded, _l10n?.sendToRider ?? 'Send to rider',
          enabled: hasTicket && _activeTicketIsSelfOrder),
      const PopupMenuDivider(),

      // ── Always-enabled ──────────────────────────────────────────────────
      option('drawer', Icons.point_of_sale_outlined, _l10n?.openCashDrawer ?? 'Open cash drawer'),
      option('sync', Icons.sync_rounded, _l10n?.syncAction ?? 'Sync'),
      const PopupMenuDivider(),

      // ── Clear ticket (red, last) ────────────────────────────────────────
      option('clear', Icons.delete_outline_rounded, _l10n?.clearTicket ?? 'Clear ticket',
          enabled: ticketSelected, danger: true),
    ];
  }

  /// What a ticket option does (⋯ menu, and the drawer's quick actions).
  Future<void> _handleTicketOption(BuildContext context, String value) async {
    switch (value) {
      case 'clear':
        await _handleClearTicket(context);
        break;

      case 'print':
        if (_cartItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.noItemsToPrint ?? 'No items in the current ticket to print.',
              ),
            ),
          );
          break;
        }
        if (!printerService.isConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.noPrinterConfiguredSettings ?? 'No printer configured. Set up a printer in Settings first.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          break;
        }
        // Unsaved items: the kitchen has not got them yet, so save
        // first (kitchen order prints), then print the bill.
        if (_activeTicketId == null ||
            _cartItems.any((i) => !i.isSaved)) {
          final save = await _confirmSaveBeforeBill(context);
          if (save && context.mounted) {
            await _saveCurrentTicket(context, printBill: true);
          }
          break;
        }
        await _printBill(
          context,
          _snapshotBill(
            ticketName: _activeTicketLabel.isNotEmpty
                ? '$_activeTicketLabel - ${_activeTicketName ?? ''}'
                : _activeTicketName,
          ),
          queueNumber: _activeTicketQueueNumber,
        );
        break;

      case 'reprint':
        // Reprint ALL items in the current ticket to kitchen/bar printers
        if (_activeTicketId == null) {
          break;
        }
        if (_cartItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.noItemsToReprint ?? 'No items in the current ticket to reprint.',
              ),
            ),
          );
          break;
        }
        if (!printerService.isConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.noPrinterConfiguredSettings ?? 'No printer configured. Set up a printer in Settings first.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          break;
        }
        {
          // Reprint must send ALL lines (ignore category routing filters).
          final reprintCount = await _printOrderItemsToKitchen(
            _cartItems,
            respectCategoryFilters: false,
            queueNumber: _activeTicketQueueNumber,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  reprintCount > 0
                      ? _l10n?.orderReprinted('$reprintCount') ??
        '🖨️ Order reprinted to $reprintCount kitchen printer(s).'
                      : (_l10n?.noPrinterForReprint ??
                            'No available printer could print this reprint request.'),
                ),
                backgroundColor: reprintCount > 0
                    ? Colors.green
                    : Colors.orange,
              ),
            );
          }
        }
        break;
      case 'split':
        if (_cartItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.noItemsToSplit ?? 'No items in the current ticket to split.',
              ),
            ),
          );
          break;
        }
        if (_activeTicketId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.saveTicketBeforeSplit ?? 'Please save the ticket first before splitting.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          break;
        }
        final splitResult = await Navigator.push<SplitTicketResult>(
          context,
          MaterialPageRoute(
            builder: (_) => SplitTicketScreen(
              cartItems: List.from(_cartItems),
              ticketName: _activeTicketName ?? 'Ticket',
            ),
          ),
        );
        if (!context.mounted || splitResult == null) break;
        {
          setState(() => _isLoading = true);
          try {
            final messenger = ScaffoldMessenger.of(context);
            // Build line format matching _saveCurrentTicket
            List<Map<String, dynamic>> toLines(
              List<CartItem> items,
            ) => items.map(_orderLinePayload).toList();

            // Step 1: Replace ALL lines on the original ticket with ONLY the remaining items
            await _apiService.updateOrder(
              orderId: _activeTicketId!,
              tableId: _activeTicketTableId,
              customerId: _selectedCustomer?['id'],
              lines: toLines(splitResult.remainingItems),
              replaceAll: true,
            );

            // Step 2: Create a brand-new separate ticket with the moved items
            await _apiService.createOrder(
              userId: widget.cashierId,
              tableId: _activeTicketTableId,
              customerId: _selectedCustomer?['id'],
              name: splitResult.newTicketName,
              lines: toLines(splitResult.newItems),
            );

            // Step 3: Update local cart to show the remaining items
            // Mark them as saved since we just synced this state with the server
            for (var item in splitResult.remainingItems) {
              item.isSaved = true;
            }

            setState(() {
              _cartItems = splitResult.remainingItems;
              _isLoading = false;
            });

            if (!context.mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  _l10n?.ticketSplitCreated(splitResult.newTicketName) ??
        'Ticket split! "${splitResult.newTicketName}" created.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            setState(() => _isLoading = false);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_l10n?.splitError('$e') ?? 'Split error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;
      case 'sync':
        await _syncAllDataAndRefresh();
        break;
      case 'move':
        await _showMoveTicketDialog(context);
        break;
      case 'rename':
        await _showRenameTicketDialog(context);
        break;
      case 'drawer':
        if (!printerService.isConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.noPrinterConfigured ?? 'No printer configured. Set up a printer first.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          break;
        }
        final opened = await printerService.openCashDrawer();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                opened
                    ? (_l10n?.cashDrawerOpened ??
                          '🗃️ Cash drawer opened!')
                    : (_l10n?.failedToOpenDrawer ??
                          'Failed to open drawer. Check printer connection.'),
              ),
              backgroundColor: opened ? Colors.green : Colors.red,
            ),
          );
        }
        break;

      case 'send_to_rider':
        if (_activeTicketId == null) break;
        await _showRiderPickerDialog(context);
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n?.featureComingSoon ?? 'Feature coming soon!')),
        );
    }
  }

  // ── Side drawer ───────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final name = widget.cashierName.trim();
    final terminal = [
      if ((_cachedPosName ?? '').trim().isNotEmpty)
        (_cachedPosName ?? '').trim()
      else
        _l10n?.posTerminal ?? 'POS Terminal',
      if ((_cachedBranchName ?? '').trim().isNotEmpty)
        ', ${(_cachedBranchName ?? '').trim()}',
    ].join('');

    return Drawer(
      width: screenW * 0.86 > 360 ? 360 : screenW * 0.86,
      backgroundColor: Ld.surface,
      child: Column(
        children: [
          // ── Profile header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Ld.navy,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 28,
              24,
              22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Ld.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                        style: Ld.title(24, color: Ld.navy),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.cashierName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            widget.role == 'admin'
                                ? (_l10n?.administrator ?? 'Administrator')
                                : (_l10n?.roleCashier ?? 'Cashier'),
                            style: const TextStyle(
                              color: Ld.onNavyMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.point_of_sale_outlined,
                      color: Ld.onNavyMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        terminal,
                        style: const TextStyle(
                          color: Ld.onNavyMuted,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Menu Items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              children: [
                _drawerItem(
                  icon: Icons.storefront_outlined,
                  label: _l10n?.sales ?? 'Sales',
                  isActive: true,
                  onTap: () => Navigator.pop(context),
                ),
                _drawerItem(
                  icon: Icons.receipt_long_outlined,
                  label: _l10n?.receipts ?? 'Receipts',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReceiptHistoryScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  icon: Icons.fact_check_outlined,
                  label: _l10n?.selfOrdersReview ?? 'Self Orders Review',
                  trailing: _pendingSelfOrdersCount > 0
                      ? LdBadge('$_pendingSelfOrdersCount')
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelfOrdersReviewScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  icon: Icons.inventory_2_outlined,
                  label: _l10n?.itemsMenu ?? 'Items',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageItemsScreen(),
                      ),
                      // Products, toppings or categories may have changed:
                      // reload so the POS offers them right away.
                    ).then((_) {
                      if (mounted) _fetchOdooProducts(backgroundRefresh: true);
                    });
                  },
                ),
                _drawerItem(
                  icon: Icons.tune_rounded,
                  label: _l10n?.settings ?? 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PosSettingsScreen(),
                      ),
                    ).then((_) {
                      _loadPromotionPriceSetting();
                      _loadPosProfileLabels();
                    });
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Divider(),
                ),
                // Quick actions: the same as the ⋯ menu entries.
                _drawerItem(
                  icon: Icons.point_of_sale_outlined,
                  label: _l10n?.openCashDrawer ?? 'Open cash drawer',
                  quick: true,
                  onTap: () {
                    Navigator.pop(context);
                    _handleTicketOption(context, 'drawer');
                  },
                ),
                _drawerItem(
                  icon: Icons.sync_rounded,
                  label: _l10n?.syncAction ?? 'Sync',
                  quick: true,
                  onTap: () {
                    Navigator.pop(context);
                    _handleTicketOption(context, 'sync');
                  },
                ),
              ],
            ),
          ),

          // ── Lock / Switch User ─────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await _apiService.logout();
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Ld.navy,
                    side: const BorderSide(color: Ld.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded, size: 20),
                  label: Text(
                    _l10n?.lockSwitchUser ?? 'Lock / Switch User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tablet: catalog + navy ticket rail ────────────────────────────────────
  Widget _buildTabletBody(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final railWidth = (w * 0.3).clamp(320.0, 400.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: SafeArea(
        // The ticket rail pads itself for the system navigation bar.
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: SafeArea(
                top: false,
                child: _buildCatalog(context, tablet: true),
              ),
            ),
            SizedBox(
              width: railWidth,
              child: CartSidebar(
                cartItems: _cartItems,
                onUpdateQuantity: _updateQuantity,
                onEditKitchenNote: _editCartItemKitchenNote,
                // A saved ticket is deleted on the server (admin PIN);
                // only an unsaved cart is just cleared. The trash used to
                // clear the screen only, so the ticket came back.
                onClearCart: () => _handleClearTicket(context),
                onViewTickets: () => _openTicketsScreen(context),
                onSaveTicket: () {
                  _saveCurrentTicket(context);
                },
                onCharge: () {
                  _showChargeDialog(context);
                },
                selectedCustomer: _selectedCustomer,
                onAddCustomer: () => _showCustomerSelection(context),
                onClearCustomer: () =>
                    setState(() => _selectedCustomer = null),
                promoBanner: _freePromoBanner(context),
                taxConfig: _taxConfig,
                selectedDiscountOption: _selectedDiscountOption,
                discountManualValue: _pendingDiscountManualValue,
                ticketName: _ticketTitle,
                ticketSubtitle: _ticketSubtitle,
                optionsButton: _ticketOptionsButton(context, onRail: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error state of the catalog with a retry button.
  Widget _catalogError(VoidCallback onRetry) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Ld.danger,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Ld.danger),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(_l10n?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Search, categories and the products. [tablet]: toolbar row and, when
  /// wide enough, the category rail on the left.
  Widget _buildCatalog(BuildContext context, {required bool tablet}) {
    if (_categories.isEmpty && (_isLoading || _errorMessage != null)) {
      final state = _isLoading
          ? PosProductSkeleton(isGridView: _isGridView)
          : _catalogError(() {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _fetchOdooProducts();
            });
      if (!tablet) return state;
      return Column(
        children: [
          _tabletToolbar(context, showMenuButton: true),
          Expanded(child: state),
        ],
      );
    }

    return DefaultTabController(
      length: _categories.length,
      child: Builder(builder: (context) {
        final tabs = DefaultTabController.of(context);
        final showRail = tablet && MediaQuery.sizeOf(context).width >= 1100;
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tablet)
              _tabletToolbar(context, showMenuButton: !showRail)
            else
              _phoneSearchField(),
            if (!showRail)
              _CategoryChipsBar(
                controller: tabs,
                labels: [for (final c in _categories) _categoryLabel(c)],
                counts: [for (final c in _categories) _categoryCount(c)],
              ),
            if (tablet) _categoryHeading(tabs),
            // Products TabBarView (Grid/List): swipe still changes category.
            Expanded(child: _productsArea()),
          ],
        );
        if (!showRail) return column;
        return Row(
          children: [
            _categoryRail(context, tabs),
            Expanded(child: column),
          ],
        );
      }),
    );
  }

  Widget _phoneSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: _searchField(height: 48),
    );
  }

  /// The product search box (same controller and filter on every layout).
  Widget _searchField({required double height}) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 16, color: Ld.ink),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: _l10n?.searchProducts ?? 'Search products...',
          prefixIcon: const Icon(Icons.search_rounded, color: Ld.muted, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Ld.muted,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Ld.rMd),
            borderSide: const BorderSide(color: Ld.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Ld.rMd),
            borderSide: const BorderSide(color: Ld.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Ld.rMd),
            borderSide: const BorderSide(color: Ld.navy, width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  /// Tablet tools above the products: menu (when there is no category
  /// rail), search, Open Tickets, scanner and grid / list.
  Widget _tabletToolbar(BuildContext context, {required bool showMenuButton}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: LayoutBuilder(builder: (context, box) {
        final showLabel = box.maxWidth >= 620;
        return Row(
          children: [
            if (showMenuButton) ...[
              Builder(
                builder: (ctx) => Tooltip(
                  message: MaterialLocalizations.of(ctx).openAppDrawerTooltip,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(52, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
                      ),
                      child: const Icon(Icons.menu_rounded, size: 22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: _searchField(height: 52)),
            const SizedBox(width: 10),
            if (showLabel)
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _openTicketsScreen(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Ld.surface,
                    foregroundColor: Ld.navy,
                    side: const BorderSide(color: Ld.line),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
                    textStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 20),
                  label: Text(
                    _l10n?.openTickets ?? 'Open Tickets',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              _squareButton(
                icon: Icons.receipt_long_outlined,
                tooltip: _l10n?.openTickets ?? 'Open Tickets',
                onPressed: () => _openTicketsScreen(context),
              ),
            const SizedBox(width: 10),
            _squareButton(
              icon: Icons.qr_code_scanner_rounded,
              tooltip: _l10n?.scanVoucher ?? 'Scan Voucher',
              onPressed: _openScannerDialog,
            ),
            const SizedBox(width: 10),
            _squareButton(
              icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              tooltip: _isGridView
                  ? (_l10n?.switchToList ?? 'Switch to List')
                  : (_l10n?.switchToGrid ?? 'Switch to Grid'),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
          ],
        );
      }),
    );
  }

  /// Tablet: category name in the receipt font and how many items it has.
  Widget _categoryHeading(TabController tabs) {
    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        final i = tabs.index.clamp(0, _categories.length - 1);
        final c = _categories[i];
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  _categoryLabel(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ld.title(24),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _l10n?.itemsCount('${_categoryCount(c)}') ?? '${_categoryCount(c)} items',
                style: const TextStyle(fontSize: 14, color: Ld.muted),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Wide tablets: white category rail with the menu button and brand.
  Widget _categoryRail(BuildContext context, TabController tabs) {
    final branch = (_cachedBranchName ?? '').trim().isNotEmpty
        ? _cachedBranchName!.trim()
        : (_cachedPosName ?? '').trim();
    return Container(
      width: 188,
      decoration: const BoxDecoration(
        color: Ld.surface,
        border: Border(right: BorderSide(color: Ld.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 10, 14),
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => Tooltip(
                    message: MaterialLocalizations.of(ctx).openAppDrawerTooltip,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: FilledButton(
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.r)),
                        ),
                        child: const Icon(Icons.menu_rounded, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('LaDolce', maxLines: 1, style: Ld.title(18)),
                      if (branch.isNotEmpty)
                        Text(
                          branch,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Ld.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: tabs,
              builder: (context, _) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final selected = tabs.index == i;
                  return Material(
                    color: selected ? Ld.navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(Ld.r),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Ld.r),
                      onTap: () => tabs.animateTo(i),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _categoryLabel(c),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    height: 1.3,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                    color: selected ? Colors.white : Ld.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_categoryCount(c)}',
                                style: TextStyle(fontSize: 13, color: selected ? Ld.gold : Ld.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One page of products per category (swipe between them).
  Widget _productsArea() {
    if (_isLoading) return PosProductSkeleton(isGridView: _isGridView);
    if (_errorMessage != null) return _catalogError(_fetchOdooProducts);
    final quantities = _cartQuantities();
    return TabBarView(
      children: _categories.map((category) {
        // Filter products dynamically for each tab
        List<Product> tabProducts = _products;
        if (category.name != 'All Items') {
          tabProducts = tabProducts
              .where(
                (p) =>
                    p.category == category.name,
              )
              .toList();
        }

        // Apply search across the active tab's items
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery
              .toLowerCase();
          tabProducts = tabProducts
              .where(
                (p) =>
                    p.matchesQuery(query) ||
                    p.category
                        .toLowerCase()
                        .contains(query) ||
                    (p.defaultCode != null &&
                        p.defaultCode!
                            .toLowerCase()
                            .contains(query)),
              )
              .toList();
        }

        if (tabProducts.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 56,
                    color: Ld.faint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? _l10n?.noProductsMatching(_searchQuery) ??
                            'No products matching "$_searchQuery"'
                        : (_l10n?.noProductsInCategory ??
                            'No products in this category'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Ld.muted,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _isGridView
            ? ProductGrid(
                products: tabProducts,
                onProductTap: _addToCart,
                cartQuantities: quantities,
              )
            : ProductList(
                products: tabProducts,
                onProductTap: _addToCart,
                cartQuantities: quantities,
              );
      }).toList(),
    );
  }

  Widget _buildMobileCartBar(BuildContext context) {
    final tItems = _cartItems.fold(0, (sum, item) => sum + item.quantity);
    final payTotal = _cartBreakdown().totalDue;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + Ld.navInset(context),
      ),
      child: Material(
        color: Ld.navy,
        borderRadius: BorderRadius.circular(Ld.rLg),
        child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setSheetState) => FractionallySizedBox(
                heightFactor: 0.85,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Ld.navy,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle: swipe down closes the ticket.
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Ld.navyLine,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Expanded(
                  child: CartSidebar(
                    cartItems: _cartItems,
                    onUpdateQuantity: (item, newQty) {
                      _updateQuantity(item, newQty);
                      setSheetState(() {});
                      if (_cartItems.isEmpty) Navigator.pop(ctx);
                    },
                    onEditKitchenNote: (item) async {
                      await _editCartItemKitchenNote(item);
                      setSheetState(() {});
                    },
                    onClearCart: () {
                      Navigator.pop(ctx);
                      // Same as the ⋯ menu's Delete ticket: admin PIN for a
                      // saved ticket, plain clear for an unsaved cart.
                      _handleClearTicket(context);
                    },
                    onViewTickets: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push<ResumedTicket>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TicketsScreen(cachedProducts: _products),
                        ),
                      );
                      if (result != null) {
                        _applyResumedTicket(result);
                      }
                    },
                    onSaveTicket: () {
                      Navigator.pop(ctx);
                      _saveCurrentTicket(context);
                    },
                    onCharge: () {
                      Navigator.pop(ctx);
                      _showChargeDialog(context);
                    },
                    selectedCustomer: _selectedCustomer,
                    onAddCustomer: () async {
                      await _showCustomerSelection(context);
                      setSheetState(() {});
                    },
                    onClearCustomer: () {
                      setState(() => _selectedCustomer = null);
                      setSheetState(() {});
                    },
                    promoBanner: _freePromoBanner(context, onChanged: () => setSheetState(() {})),
                    taxConfig: _taxConfig,
                    selectedDiscountOption: _selectedDiscountOption,
                    discountManualValue: _pendingDiscountManualValue,
                    ticketName: _ticketTitle,
                    ticketSubtitle: _ticketSubtitle,
                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(Ld.rLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              // ── Left: label + item count ──────────────────────────
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_ticketTitle ?? (_l10n?.currentTicket2 ?? 'Current Ticket'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Ld.onNavyMuted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _l10n?.itemsCount('$tItems') ?? '$tItems Items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Right: total in gold, opens the ticket ────────────
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₭${money(payTotal)}',
                    style: Ld.price(22, color: Ld.gold),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28),
            ],
          ),
          ),
        ),
      ),
      ),
    );
  }

  bool _isCharging = false;
  bool _isSaving = false;

  // Set by the charge button for _processCheckout: split rows for the server
  // (null = single payment), and the payment lines + change for the receipt.
  List<Map<String, dynamic>>? _checkoutPayments;

  /// Running "Buy X get Y free" promotions (loaded with the products).
  List<FreePromotion> _freePromotions = [];

  /// A promotion with more free items than the cart earned (a paid item was
  /// removed after the free one was added). Save / charge refuse it.
  FreePromotion? get _overusedFreePromo {
    for (final promo in _freePromotions) {
      if (promo.availableFree(_cartItems) < 0) return promo;
    }
    // Free line whose promotion is no longer loaded (e.g. it just ended).
    return null;
  }

  bool _blockIfFreeOverused(BuildContext context) {
    final promo = _overusedFreePromo;
    if (promo == null) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n?.tooManyFreeItems(promo.name) ??
            'Too many free items for ${promo.name}. Remove one first.'),
        backgroundColor: Colors.red,
      ),
    );
    return true;
  }

  /// Cart banner: "Buy 2 Get 1 Coffee: 1 free item" + Add free, or a red
  /// warning when there are too many. Null when nothing to show.
  Widget? _freePromoBanner(BuildContext context, {VoidCallback? onChanged}) {
    final rows = <Widget>[];
    for (final promo in _freePromotions) {
      final available = promo.availableFree(_cartItems);
      if (available == 0) continue;
      final over = available < 0;
      rows.add(Container(
        margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: over ? Ld.dangerWash : Ld.goldWash,
          borderRadius: BorderRadius.circular(Ld.rSm),
          border: over ? Border.all(color: Ld.dangerLine) : null,
        ),
        child: Row(
          children: [
            Icon(
              over ? Icons.warning_amber_rounded : Icons.card_giftcard_rounded,
              size: 20,
              color: over ? Ld.danger : Ld.goldInk,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                over
                    ? (_l10n?.tooManyFreeItems(promo.name) ??
                        'Too many free items for ${promo.name}. Remove one first.')
                    : (_l10n?.freeItemsAvailable(promo.name, available) ??
                        '${promo.name}: $available free item(s)'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: over ? Ld.danger : Ld.goldWashInk,
                ),
              ),
            ),
            if (!over) ...[
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Ld.goldInk,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rSm)),
                  textStyle: const TextStyle(fontFamily: Ld.sans, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _pickFreeItem(context, promo, onChanged: onChanged),
                child: Text(_l10n?.addFreeItem ?? 'Add free'),
              ),
            ],
          ],
        ),
      ));
    }
    if (rows.isEmpty) return null;
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  /// Cashier picks which promotion item is the free one.
  Future<void> _pickFreeItem(BuildContext context, FreePromotion promo, {VoidCallback? onChanged}) async {
    final choices = _products.where((p) => promo.freeProductIds.contains(p.id)).toList();
    final picked = await showModalBottomSheet<Product>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                _l10n?.chooseFreeItem(promo.name) ?? 'Choose the free item (${promo.name})',
                style: Ld.title(19),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in choices)
                    ListTile(
                      minVerticalPadding: 12,
                      leading: const LdIconTile(
                        Icons.card_giftcard_rounded,
                        background: Ld.goldWash,
                        color: Ld.goldInk,
                      ),
                      title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('₭${money(p.effectivePrice)}',
                          style: const TextStyle(
                            fontFamily: Ld.serif,
                            color: Ld.muted,
                            decoration: TextDecoration.lineThrough,
                          )),
                      trailing: Text(_sentence(_l10n?.freeItemLabel ?? 'FREE'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Ld.success)),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                ],
              ),
            ),
            SizedBox(height: LaDolcePosUi.gestureBarBottomPad(ctx)),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.toppings.isNotEmpty) {
      // Choices are free too (whole line is free).
      _showToppingsSelection(picked, freePromo: promo, onAdded: onChanged);
    } else {
      _addDirectlyToCart(picked, [], freePromo: promo);
      onChanged?.call();
    }
  }
  List<Map<String, dynamic>> _checkoutReceiptPayments = [];
  bool _checkoutOpensDrawer = false;
  double _checkoutChange = 0;

  /// Split payment rows in the charge sheet: method + amount per row, an
  /// "Add payment" button and the remaining / change line.
  List<Widget> _splitPaymentWidgets(
    List<_SplitPaymentRow> rows,
    _SplitPaymentSummary split,
    double total,
    NumberFormat fmt,
    StateSetter setSheetState,
  ) {
    Widget methodPicker(int i) => DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: rows[i].method.id,
            isExpanded: true,
            style: const TextStyle(fontFamily: Ld.sans, fontSize: 16, fontWeight: FontWeight.w600, color: Ld.ink),
            items: [
              for (final m in _paymentMethods)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setSheetState(() {
              rows[i].method = _paymentMethods.firstWhere((m) => m.id == id);
            }),
          ),
        );

    Widget amountField(int i) => TextField(
          controller: rows[i].amount,
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          textAlign: TextAlign.right,
          style: Ld.price(22, color: Ld.ink),
          decoration: InputDecoration(
            prefixText: '₭ ',
            prefixStyle: Ld.price(17, color: Ld.muted, weight: FontWeight.w500),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (_) => setSheetState(() {}),
        );

    Widget removeButton(int i) => rows.length > 1
        ? IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, color: Ld.danger),
            onPressed: () => setSheetState(() => rows.removeAt(i)),
          )
        : const SizedBox(width: 8);

    return [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: Ld.card(radius: Ld.rLg),
            child: LayoutBuilder(builder: (context, box) {
              final icon = LdIconTile(
                rows[i].isCash ? Icons.payments_outlined : Icons.qr_code_2_rounded,
                size: 40,
              );
              // Narrow sheets: method on top, amount under it.
              if (box.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 10),
                        Expanded(child: methodPicker(i)),
                        removeButton(i),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: amountField(i),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: methodPicker(i)),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: amountField(i)),
                  removeButton(i),
                ],
              );
            }),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setSheetState(() {
            // Next method not used yet, pre-filled with what is still owed.
            final used = rows.map((r) => r.method.id).toSet();
            final next = _paymentMethods.firstWhere(
              (m) => !used.contains(m.id),
              orElse: () => _paymentMethods.first,
            );
            rows.add(_SplitPaymentRow(next, split.remaining > 0 ? split.remaining : 0));
          }),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Ld.r),
              side: const BorderSide(color: Ld.faint),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text(_l10n?.addPayment ?? 'Add payment'),
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: split.ok ? Ld.successWash : Ld.warningWash,
          borderRadius: BorderRadius.circular(Ld.r),
        ),
        child: Row(
          children: [
            Icon(
              split.ok ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
              size: 20,
              color: split.ok ? Ld.success : Ld.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                split.tooMuchNonCash
                    ? (_l10n?.splitOnlyCashOver ?? 'Only cash can be more than the total')
                    : split.remaining > 0
                        ? (_l10n?.remainingToPay ?? 'Remaining')
                        : (_l10n?.changeDue ?? 'Change Due:'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: split.ok ? Ld.success : Ld.warning,
                ),
              ),
            ),
            if (!split.tooMuchNonCash)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₭${fmt.format(split.remaining > 0 ? split.remaining : split.change)}',
                    style: Ld.price(18, color: split.ok ? Ld.success : Ld.warning),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Future<void> _showMoveTicketDialog(BuildContext context) async {
    List<OpenTicket> tickets = [];
    List<PosTable> tables = [];
    try {
      tickets = await _apiService.fetchOpenTickets();
      tables = await _apiService.fetchTables();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.cannotLoadOpenTickets('$e') ?? 'Cannot load open tickets: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.noOpenTicketToMoveFrom ?? 'No open ticket to move from.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final emptyTables = tables
        .where(
          (t) =>
              (t.status == 'available' || t.status == 'empty') &&
              !t.hasOpenOrder,
        )
        .toList();

    if (tickets.length < 2 && emptyTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.noDestinationAvailable ?? 'No destination available. Open another ticket or free a table.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int sourceTicketId = _activeTicketId ?? tickets.first.id;
    final canMoveToOpenTicket = tickets.any((t) => t.id != sourceTicketId);
    String destinationMode = canMoveToOpenTicket ? 'ticket' : 'table';
    int? destinationTicketId = canMoveToOpenTicket
        ? tickets.firstWhere((t) => t.id != sourceTicketId).id
        : null;
    int? destinationTableId = emptyTables.isNotEmpty
        ? emptyTables.first.id
        : null;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final sourceTicket = tickets.firstWhere(
            (t) => t.id == sourceTicketId,
          );
          final destinationOptions = tickets
              .where((t) => t.id != sourceTicketId)
              .toList();

          if (destinationMode == 'ticket' && destinationOptions.isEmpty) {
            destinationMode = 'table';
          }
          if (destinationMode == 'table' && emptyTables.isEmpty) {
            destinationMode = 'ticket';
          }

          if (destinationMode == 'ticket' && destinationOptions.isNotEmpty) {
            if (destinationTicketId == null ||
                !destinationOptions.any((t) => t.id == destinationTicketId)) {
              destinationTicketId = destinationOptions.first.id;
            }
          }
          if (destinationMode == 'table' && emptyTables.isNotEmpty) {
            if (destinationTableId == null ||
                !emptyTables.any((t) => t.id == destinationTableId)) {
              destinationTableId = emptyTables.first.id;
            }
          }

          return FractionallySizedBox(
            heightFactor: 0.92,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  20 + (LaDolcePosUi.gestureBarBottomPad(context) - 8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_l10n?.moveTicketTitle ?? 'Move Ticket',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_l10n?.selectSourceTicket ?? 'Select source ticket',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: sourceTicketId,
                      isExpanded: true,
                      items: tickets.map((t) {
                        final tableLabel = (t.tableName ?? '').trim().isNotEmpty
                            ? (t.tableName ?? '').trim()
                            : (t.tableId != null
                                  ? 'Table ${t.tableId}'
                                  : (_l10n?.noTable ?? 'No table'));
                        return DropdownMenuItem<int>(
                          value: t.id,
                          child: Text(
                            '$tableLabel / ${t.name}',
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              if (val == null) return;
                              setDialogState(() {
                                sourceTicketId = val;
                                final destinations = tickets
                                    .where((t) => t.id != sourceTicketId)
                                    .toList();
                                if (destinations.isNotEmpty) {
                                  destinationTicketId = destinations.first.id;
                                }
                                if (destinations.isEmpty &&
                                    emptyTables.isNotEmpty) {
                                  destinationMode = 'table';
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    Text(_l10n?.moveDestination ?? 'Move destination',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment<String>(
                          value: 'ticket',
                          label: Text(_l10n?.openTicketLabel ?? 'Open ticket'),
                        ),
                        ButtonSegment<String>(
                          value: 'table',
                          label: Text(_l10n?.emptyTable ?? 'Empty table'),
                        ),
                      ],
                      selected: <String>{destinationMode},
                      onSelectionChanged: isSubmitting
                          ? null
                          : (selection) {
                              final next = selection.first;
                              if (next == 'ticket' &&
                                  destinationOptions.isEmpty) {
                                return;
                              }
                              if (next == 'table' && emptyTables.isEmpty) {
                                return;
                              }
                              setDialogState(() => destinationMode = next);
                            },
                    ),
                    const SizedBox(height: 10),
                    if (destinationMode == 'ticket')
                      DropdownButtonFormField<int>(
                        value: destinationTicketId,
                        isExpanded: true,
                        items: destinationOptions.map((t) {
                          final tableLabel =
                              (t.tableName ?? '').trim().isNotEmpty
                              ? (t.tableName ?? '').trim()
                              : (t.tableId != null
                                    ? 'Table ${t.tableId}'
                                    : (_l10n?.noTable ?? 'No table'));
                          return DropdownMenuItem<int>(
                            value: t.id,
                            child: Text(
                              '$tableLabel / ${t.name}',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (val) => setDialogState(
                                () => destinationTicketId =
                                    val ?? destinationTicketId,
                              ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: destinationTableId,
                        isExpanded: true,
                        items: emptyTables.map((t) {
                          return DropdownMenuItem<int>(
                            value: t.id,
                            child: Text('${t.name} (empty)'),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (val) => setDialogState(
                                () => destinationTableId =
                                    val ?? destinationTableId,
                              ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        'Source total: ₭${money(sourceTicket.amountTotal)}\nItems: ${sourceTicket.lines.length}',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogCtx),
                            child: Text(_l10n?.cancel ?? 'Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(() => isSubmitting = true);
                                    final success = await _moveTicketItems(
                                      sourceTicketId: sourceTicketId,
                                      destinationTicketId:
                                          destinationMode == 'ticket'
                                          ? destinationTicketId
                                          : null,
                                      destinationTableId:
                                          destinationMode == 'table'
                                          ? destinationTableId
                                          : null,
                                    );
                                    if (!dialogCtx.mounted) return;
                                    setDialogState(() => isSubmitting = false);
                                    if (success) {
                                      Navigator.pop(dialogCtx);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandNavy,
                              foregroundColor: Colors.white,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_l10n?.moveNow ?? 'Move Now'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _moveTicketItems({
    required int sourceTicketId,
    int? destinationTicketId,
    int? destinationTableId,
  }) async {
    try {
      final tickets = await _apiService.fetchOpenTickets();
      final source = tickets.where((t) => t.id == sourceTicketId).firstOrNull;

      if (source == null) {
        throw Exception('Source ticket no longer exists.');
      }
      if (destinationTicketId == null && destinationTableId == null) {
        throw Exception('Please select a destination ticket or table.');
      }
      if (source.lines.isEmpty) {
        throw Exception('Source ticket has no items to move.');
      }

      final linesToMove = source.lines
          .map(
            (line) => {
              'product_id': line.productId,
              'qty': line.qty,
              'price_unit': line.priceUnit,
              'topping_ids': line.toppingIds,
            },
          )
          .toList();

      // 1) Move source lines into destination (existing ticket or new ticket on empty table)
      if (destinationTicketId != null) {
        final destination = tickets
            .where((t) => t.id == destinationTicketId)
            .firstOrNull;
        if (destination == null) {
          throw Exception('Destination ticket no longer exists.');
        }
        await _apiService.updateOrder(
          orderId: destinationTicketId,
          lines: linesToMove,
        );
      } else if (destinationTableId != null) {
        await _apiService.createOrder(
          userId: widget.cashierId,
          tableId: destinationTableId,
          customerId: _selectedCustomer?['id'],
          lines: linesToMove,
        );
      }

      // 2) Clear source ticket lines after successful append
      await _apiService.updateOrder(
        orderId: sourceTicketId,
        tableId: source.tableId,
        lines: const [],
        replaceAll: true,
      );

      // Refresh tables so the cleared source table becomes selectable immediately.
      try {
        final freshTables = await _apiService.fetchTables(forceRefresh: true);
        if (mounted) setState(() => _tables = freshTables);
      } catch (_) {}

      // If user currently has source ticket loaded in cart, reset local state
      if (_activeTicketId == sourceTicketId) {
        _clearCart();
      }

      if (mounted) {
        final movedTo = destinationTicketId != null
            ? 'ticket #$destinationTicketId'
            : 'table #$destinationTableId (new ticket)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Moved items from ticket #$sourceTicketId to $movedTo',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n?.moveTicketFailed('$e') ?? 'Move ticket failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _showRiderPickerDialog(BuildContext context) async {
    List<dynamic> riders = [];
    try {
      riders = await _apiService.fetchRiderList();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.cannotLoadRiders('$e') ?? 'Cannot load riders: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (riders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.noRidersAvailable ?? 'No riders available for this branch.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final rider = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_l10n?.selectRider ?? 'Select Rider',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _activeTicketPartnerName.isNotEmpty
                    ? _l10n?.orderForCustomer(_activeTicketPartnerName) ??
        'Order for: $_activeTicketPartnerName'
                    : _activeTicketDeliveryPlaceName.isNotEmpty
                    ? _l10n?.deliveryToPlace(_activeTicketDeliveryPlaceName) ??
        'Delivery to: $_activeTicketDeliveryPlaceName'
                    : (_l10n?.selfOrderDelivery ?? 'Self-order delivery'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ...riders.map((r) {
                final name =
                    r['name'] ?? (_l10n?.unnamed ?? 'Unnamed');
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1E3A8A),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'R',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(r['login'] ?? ''),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => Navigator.pop(ctx, r),
                );
              }),
            ],
          ),
        );
      },
    );

    if (rider == null || !context.mounted) return;

    final riderId = rider['id'];
    final riderName = rider['name'] ?? 'Rider';

    setState(() => _isLoading = true);
    try {
      await _apiService.assignRider(
        orderId: _activeTicketId!,
        riderId: riderId,
      );
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.orderSentToRider(riderName) ?? 'Order sent to $riderName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.failedToAssignRider('$e') ?? 'Failed to assign rider: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCustomerSelection(BuildContext context) async {
    final result = await showCustomerSelectionSheet(
      context: context,
      onSearchCustomers: (query, limit, offset) => _apiService
          .searchCustomersPaginated(query: query, limit: limit, offset: offset),
      onCreateCustomer: (name, phone) async {
        await _apiService.saveCustomer(name: name, phone: phone);
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCustomer = result;
      });

      final customerName =
          result['name']?.toString() ?? (_l10n?.unknown ?? 'Unknown');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.customerSelected(customerName) ?? 'Customer $customerName selected!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showChargeDialog(BuildContext context) {
    if (_cartItems.isEmpty) return;
    if (_blockIfFreeOverused(context)) return;

    final bd = _cartBreakdown();
    final total = bd.totalDue;
    final bool isTransferTicket = _activeTicketPaymentType == 'transfer';

    if (isTransferTicket && _activeTicketPaymentMethodId != null) {
      final fixedMethod = _paymentMethods
          .where((m) => m.id == _activeTicketPaymentMethodId)
          .firstOrNull;
      if (fixedMethod != null) _selectedPaymentMethod = fixedMethod;
    }

    if (_selectedPaymentMethod == null && _paymentMethods.isNotEmpty) {
      _selectedPaymentMethod = _paymentMethods.first;
    }

    final TextEditingController amountReceivedCtrl = TextEditingController(
      text: money(total),
    );
    final TextEditingController manualDiscountCtrl = TextEditingController(
      text: _pendingDiscountManualValue?.toStringAsFixed(0) ?? '',
    );

    // Whole kip with separators, like money() everywhere else.
    final fmt = NumberFormat('#,##0');

    // Split payment (e.g. BCEL 30,000 + Cash 7,000): one row per payment.
    var splitMode = false;
    final splitRows = <_SplitPaymentRow>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Wide enough for the two-pane sheet on tablets.
      constraints: const BoxConstraints(maxWidth: 1080),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bd = _cartBreakdown();
          final total = bd.totalDue;
          final isCash = _selectedPaymentMethod?.allowsChange ?? false;
          final amtReceived =
              double.tryParse(amountReceivedCtrl.text.replaceAll(',', '')) ??
              0.0;
          final changeAmount = amtReceived >= total ? amtReceived - total : 0.0;
          final split = _SplitPaymentSummary.of(splitRows, total);
          final canCharge = !splitMode || split.ok;

          final media = MediaQuery.sizeOf(context);
          // Tablets: amount on a navy panel at the left, payment at the right.
          final wide = media.width >= 760;
          // The bottom inset (keyboard + 3-button navigation bar) is painted
          // in the sheet colour, with room to spare above the bar.
          final bottomPad = LaDolcePosUi.modalBottomPadding(context) + 8;
          final changeLabel = (_l10n?.changeDue ?? 'Change Due:')
              .replaceAll(RegExp(r'\s*:\s*$'), '');

          void toggleSplit() => setSheetState(() {
                splitMode = !splitMode;
                if (splitMode && splitRows.isEmpty) {
                  splitRows.add(_SplitPaymentRow(
                    _selectedPaymentMethod ?? _paymentMethods.first,
                    total,
                  ));
                }
              });

          // ── Amount summary (on navy) ──────────────────────────────────
          Widget summaryRow(String label, double value, {bool big = false}) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: big ? 17 : 15,
                          color: big ? Colors.white : Ld.onNavyMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '₭${fmt.format(value)}',
                          style: Ld.price(big ? 26 : 16, color: Colors.white, weight: big ? FontWeight.w700 : FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              );

          final summary = <Widget>[
            if (splitMode) ...[
              summaryRow(_l10n?.amountReceived ?? 'Amount Received', split.paid),
              summaryRow(_l10n?.remainingToPay ?? 'Remaining', split.remaining),
              summaryRow(changeLabel, split.change, big: true),
            ] else if (isCash) ...[
              summaryRow(_l10n?.amountReceived ?? 'Amount Received', amtReceived),
              summaryRow(changeLabel, changeAmount, big: true),
            ],
          ];

          Widget closeButton() => SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Ld.r),
                      side: const BorderSide(color: Ld.navyLine),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 22),
                ),
              );

          Widget amountBlock({required double size}) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      closeButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _l10n?.charge ?? 'Charge',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ld.title(21, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 28 : 16),
                  Text(
                    _l10n?.totalAmount ?? 'Total Amount',
                    style: const TextStyle(fontSize: 15, color: Ld.onNavyMuted),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₭${fmt.format(total)}',
                      style: Ld.price(size, color: Ld.gold).copyWith(height: 1.15),
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    SizedBox(height: wide ? 18 : 10),
                    const Divider(color: Ld.navyLine, height: 1),
                    ...summary,
                  ],
                ],
              );

          // ── Payment content ───────────────────────────────────────────
          Widget sectionLabel(String text) => Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Ld.ink,
                ),
              );

          Widget segment(String label, bool selected, VoidCallback onTap) => Material(
                color: selected ? Ld.navy : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? Colors.white : Ld.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );

          // Quick cash: the exact total, then round notes above it.
          final quickCash = <double>[];
          if (total > 0) {
            for (final v in [
              total,
              (total / 10000).ceil() * 10000.0,
              (total / 50000).ceil() * 50000.0,
              (total / 100000).ceil() * 100000.0,
            ]) {
              if (v >= total && !quickCash.contains(v)) quickCash.add(v);
            }
          }

          final content = <Widget>[
            // Transfer lock notice
            if (isTransferTicket)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Ld.infoWash,
                  borderRadius: BorderRadius.circular(Ld.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 20, color: Ld.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activeTicketPaymentMethodName.isNotEmpty
                            ? _l10n?.transferTicketFixedTo(_activeTicketPaymentMethodName) ??
        'Transfer ticket: fixed to $_activeTicketPaymentMethodName.'
                            : (_l10n?.transferTicketFixed ??
                                  'Transfer ticket: payment method is fixed.'),
                        style: const TextStyle(
                          color: Ld.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Select Discount Dropdown ──────────────────────────────
            if (_discountConfig.enabled) ...[
              sectionLabel(_l10n?.selectDiscount ?? 'Select Discount'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: Ld.card(radius: Ld.r),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PosDiscountOption?>(
                    value: _selectedDiscountOption,
                    hint: Text(_l10n?.noDiscount ?? 'No Discount'),
                    isExpanded: true,
                    style: const TextStyle(fontFamily: Ld.sans, fontSize: 16, color: Ld.ink),
                    items: [
                      DropdownMenuItem<PosDiscountOption?>(
                        value: null,
                        child: Text(_l10n?.noDiscount ?? 'No Discount'),
                      ),
                      ..._discountConfig.options.map((opt) {
                        String valStr = '';
                        if (opt.value == null) {
                          valStr = opt.type == 'percentage'
                              ? (_l10n?.customPercent ?? '(Custom %)')
                              : (_l10n?.customAmount ?? '(Custom Amount)');
                        } else {
                          valStr = opt.type == 'percentage'
                              ? '(${opt.value!.toStringAsFixed(0)}%)'
                              : '(₭${money(opt.value!)})';
                        }
                        return DropdownMenuItem<PosDiscountOption?>(
                          value: opt,
                          child: Text('${opt.name} $valStr', maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (opt) {
                      setSheetState(() {
                        _selectedDiscountOption = opt;
                        if (opt == null || !opt.isManual) {
                          _pendingDiscountManualValue = null;
                          manualDiscountCtrl.clear();
                        }
                      });
                      setState(() {
                        _selectedDiscountOption = opt;
                        if (opt == null || !opt.isManual) {
                          _pendingDiscountManualValue = null;
                        }
                      });
                      _recomputeDiscount(
                        manualValue: _pendingDiscountManualValue,
                      );
                      final newTotal = _cartBreakdown().totalDue;
                      amountReceivedCtrl.text = money(newTotal);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedDiscountOption != null &&
                  _selectedDiscountOption!.isManual) ...[
                Text(
                  _selectedDiscountOption!.type == 'percentage'
                      ? (_l10n?.enterDiscountPercentage ?? 'Enter Discount Percentage')
                      : (_l10n?.enterDiscountAmount ?? 'Enter Discount Amount'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Ld.muted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: manualDiscountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Ld.ink,
                  ),
                  decoration: InputDecoration(
                    prefixText: _selectedDiscountOption!.type ==
                            'percentage'
                        ? '% '
                        : '₭ ',
                    prefixStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Ld.muted,
                    ),
                    hintText:
                        _selectedDiscountOption!.type ==
                            'percentage'
                        ? (_l10n?.egTen ?? 'e.g. 10')
                        : (_l10n?.egFiveThousand ?? 'e.g. 5000'),
                  ),
                  onChanged: (v) {
                    final val = double.tryParse(v);
                    setSheetState(() {
                      _pendingDiscountManualValue = val;
                    });
                    setState(() {
                      _pendingDiscountManualValue = val;
                    });
                    _recomputeDiscount(manualValue: val);
                    final newTotal =
                        _cartBreakdown().totalDue;
                    amountReceivedCtrl.text = money(newTotal);
                  },
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 8),
            ],

            // ── Payment Method Label (+ single / split switch) ────────
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  _l10n?.selectPaymentMethod ?? 'Select Payment Method',
                  style: wide
                      ? Ld.title(22)
                      : const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Ld.ink),
                ),
                // A transfer ticket's method is fixed: no split.
                if (!isTransferTicket && _paymentMethods.length > 1)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: Ld.card(radius: Ld.r),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: segment(
                            _l10n?.singlePayment ?? 'Single payment',
                            !splitMode,
                            () {
                              if (splitMode) toggleSplit();
                            },
                          ),
                        ),
                        Flexible(
                          child: segment(
                            _l10n?.splitPayment ?? 'Split payment',
                            splitMode,
                            () {
                              if (!splitMode) toggleSplit();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (splitMode)
              ..._splitPaymentWidgets(splitRows, split, total, fmt, setSheetState),

            // ── Payment Method Pills ──────────────────────────────────
            if (splitMode)
              const SizedBox.shrink()
            else if (_paymentMethods.isEmpty)
              Text(_l10n?.noPaymentMethods ?? 'No payment methods configured.',
                style: const TextStyle(color: Ld.muted),
              )
            else
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final locked =
                      isTransferTicket &&
                      _activeTicketPaymentMethodId != null;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisExtent: MediaQuery.textScalerOf(ctx).scale(76),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _paymentMethods.length,
                    itemBuilder: (context, i) {
                      final m = _paymentMethods[i];
                      final isSelected =
                          _selectedPaymentMethod?.id == m.id;
                      final isCashMethod = m.name
                          .toLowerCase()
                          .contains('cash');

                      return Material(
                        color: Ld.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Ld.rMd),
                          side: BorderSide(
                            color: isSelected ? Ld.navy : Ld.line,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: locked
                              ? null
                              : () => setSheetState(
                                  () => _selectedPaymentMethod = m,
                                ),
                          borderRadius: BorderRadius.circular(Ld.rMd),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: Row(
                              children: [
                                LdIconTile(
                                  isCashMethod
                                      ? Icons.payments_outlined
                                      : Icons.qr_code_2_rounded,
                                  size: 40,
                                  background: isSelected ? Ld.navy : Ld.ground,
                                  color: isSelected ? Colors.white : Ld.navy,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    m.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.3,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Ld.navy
                                          : Ld.ink,
                                    ),
                                  ),
                                ),
                                if (locked)
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: Ld.faint,
                                  )
                                else if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 20,
                                    color: Ld.navy,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

            const SizedBox(height: 20),

            // ── Cash Input ────────────────────────────────────────────
            if (isCash && !splitMode) ...[
              sectionLabel(_l10n?.amountReceived ?? 'Amount Received'),
              const SizedBox(height: 8),
              TextField(
                controller: amountReceivedCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                textAlign: TextAlign.right,
                style: Ld.price(26, color: Ld.ink),
                decoration: InputDecoration(
                  prefixText: '₭ ',
                  prefixStyle: Ld.price(19, color: Ld.muted, weight: FontWeight.w500),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: amountReceivedCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Ld.faint,
                            size: 20,
                          ),
                          onPressed: () {
                            amountReceivedCtrl.clear();
                            setSheetState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              if (quickCash.isNotEmpty) ...[
                const SizedBox(height: 10),
                LayoutBuilder(builder: (ctx, box) {
                  final cols = box.maxWidth >= 420 ? 4 : 2;
                  const gap = 10.0;
                  final w = (box.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final v in quickCash)
                        SizedBox(
                          width: w,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => setSheetState(() {
                              amountReceivedCtrl.text = money(v);
                            }),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Ld.surface,
                              foregroundColor: Ld.ink,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              side: BorderSide(
                                color: (amtReceived - v).abs() < 0.5 ? Ld.navy : Ld.line,
                                width: (amtReceived - v).abs() < 0.5 ? 2 : 1,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.r)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '₭${fmt.format(v)}',
                                style: Ld.price(17, color: Ld.ink, weight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 12),

              // Change Due row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: changeAmount > 0 ? Ld.successWash : Ld.surface,
                  borderRadius: BorderRadius.circular(Ld.r),
                  border: changeAmount > 0 ? null : Border.all(color: Ld.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_l10n?.changeDue ?? 'Change Due:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: changeAmount > 0 ? Ld.success : Ld.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '₭${fmt.format(changeAmount)}',
                          style: Ld.price(
                            20,
                            color: changeAmount > 0 ? Ld.success : Ld.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_isCharging)
              const Center(child: CircularProgressIndicator()),
          ];

          // ── Charge Button ─────────────────────────────────────────────
          final chargeButton = _isCharging
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: !canCharge
                        ? null
                        : () {
                            // What the receipt prints under TOTAL, and the
                            // split rows the server stores.
                            // Drawer: any method used that has "Open cash
                            // drawer" ticked, exact amount or not.
                            _checkoutOpensDrawer = splitMode
                                ? split.rows.any((r) => r.value > 0 && r.method.opensCashDrawer)
                                : (_selectedPaymentMethod?.opensCashDrawer ?? false);
                            if (splitMode) {
                              _checkoutPayments = split.serverPayments;
                              _checkoutReceiptPayments = split.receiptPayments;
                              _checkoutChange = split.change;
                              _selectedPaymentMethod = split.mainMethod;
                            } else {
                              _checkoutPayments = null;
                              final m = _selectedPaymentMethod;
                              _checkoutReceiptPayments = m == null
                                  ? []
                                  : [
                                      {
                                        'payment_method': m.name,
                                        'amount': isCash && amtReceived > total ? amtReceived : total,
                                      },
                                    ];
                              _checkoutChange = isCash ? changeAmount : 0.0;
                            }
                            _processCheckout(context, setSheetState, true, bd);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Ld.navy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Ld.line,
                      disabledForegroundColor: Ld.muted,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Ld.rLg),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _l10n?.charge ?? 'Charge',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '₭${fmt.format(total)}',
                              style: Ld.price(21, color: canCharge ? Ld.gold : Ld.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

          const sheetShape = BorderRadius.vertical(top: Radius.circular(24));

          if (wide) {
            final panelWidth = (media.width * 0.38).clamp(300.0, 460.0);
            return Container(
              constraints: BoxConstraints(maxHeight: media.height * 0.9),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Ld.ground, borderRadius: sheetShape),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left: the amount, large, on navy ───────────────────
                  Container(
                    width: panelWidth,
                    color: Ld.navy,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomPad),
                      child: amountBlock(size: panelWidth >= 420 ? 64 : 48),
                    ),
                  ),
                  // ── Right: how it is paid ──────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                            children: content,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(28, 8, 28, bottomPad),
                          child: chargeButton,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Phones: everything stacked, the navy amount card scrolls with
          // the rest so short screens and the keyboard always fit.
          return Container(
            constraints: BoxConstraints(maxHeight: media.height * 0.9),
            padding: EdgeInsets.only(bottom: bottomPad),
            decoration: BoxDecoration(color: Ld.ground, borderRadius: sheetShape),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Ld.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        decoration: BoxDecoration(
                          color: Ld.navy,
                          borderRadius: BorderRadius.circular(Ld.rXl),
                        ),
                        child: amountBlock(size: 44),
                      ),
                      const SizedBox(height: 18),
                      ...content,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: chargeButton,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _processCheckout(
    BuildContext context,
    StateSetter setDialogState,
    bool printReceipt,
    CartBreakdown bd,
  ) async {
    final ended = await _endedFreePromotion();
    if (ended != null) {
      // A dialog, not a snackbar: the charge sheet covers the snackbar.
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.card_giftcard_rounded, color: Colors.red, size: 40),
            content: Text(_l10n?.freePromoEnded(ended) ??
                '"$ended" has ended. Remove the free item before charging.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_l10n?.close ?? 'Close'),
              ),
            ],
          ),
        );
      }
      return;
    }
    final subtotalRowLabel = bd.taxActive && _taxConfig.inclusive
        ? (_l10n?.amountExclVat ?? 'Amount (excl. VAT):')
        : 'Subtotal:';
    final taxLab = (bd.taxActive && _taxConfig.showOnReceipt)
        ? 'VAT (${_taxConfig.percentLabel}%):'
        : null;

    // Only new (unsaved) lines need to be pushed — saved ones are already on server
    final newLines = _cartItems
        .where((item) => !item.isSaved)
        .map(_orderLinePayload)
        .toList();

    // All lines (for offline/new-order path)
    final allLines = _cartItems.map(_orderLinePayload).toList();

    final cashierId = widget.cashierId;

    // Lock down payment method if this is a saved transfer ticket.
    if (_activeTicketPaymentType == 'transfer' &&
        _activeTicketPaymentMethodId != null &&
        _selectedPaymentMethod?.id != _activeTicketPaymentMethodId) {
      final fixedMethod = _paymentMethods
          .where((m) => m.id == _activeTicketPaymentMethodId)
          .firstOrNull;
      if (fixedMethod != null) _selectedPaymentMethod = fixedMethod;
    }

    // Snapshot everything needed for background work before clearing cart/state.
    final snapshotCart = List<CartItem>.from(_cartItems);
    final snapshotPaymentMethod = _selectedPaymentMethod;
    final snapshotActiveTicketId = _activeTicketId;
    final snapshotActiveTicketTableId = _activeTicketTableId;
    final snapshotActiveTicketPaymentType = _activeTicketPaymentType;
    final snapshotActiveTicketQueueNumber = _activeTicketQueueNumber;
    final snapshotDiscountType = _appliedDiscountType;
    final snapshotDiscountValue = _appliedDiscountValue;
    // _clearCart() below nulls the customer before the background sync runs.
    final snapshotCustomerId = _selectedCustomer?['id'] as int?;
    final snapshotCustomerName = (_selectedCustomer?['name'] ?? '').toString();
    final snapshotCustomerPoints =
        int.tryParse((_selectedCustomer?['reward_points'] ?? '').toString());
    final snapshotPointsSpent =
        snapshotCart.fold<int>(0, (sum, item) => sum + item.totalPoints);
    final customerChanged =
        snapshotCustomerId != null && snapshotCustomerId != _activeTicketPartnerId;
    // Split payment rows (null = single method) and the receipt lines.
    final snapshotPayments = _checkoutPayments;
    final snapshotReceiptPayments = List<Map<String, dynamic>>.from(_checkoutReceiptPayments);
    final snapshotChange = _checkoutChange;
    _checkoutPayments = null;
    _checkoutReceiptPayments = [];
    _checkoutChange = 0;
    // Drawer opens when a method with "Open cash drawer" ticked was used
    // (any row of a split payment counts).
    final drawerMethodNames = {
      for (final m in _paymentMethods)
        if (m.opensCashDrawer) m.name,
    };
    final isCash = _checkoutOpensDrawer ||
        (snapshotPaymentMethod?.opensCashDrawer ?? false) ||
        snapshotReceiptPayments.any(
            (p) => drawerMethodNames.contains((p['payment_method'] ?? '').toString()));
    _checkoutOpensDrawer = false;

    // --- Optimistic UI: update local state and close dialog immediately ---

    // Clear open ticket from local cache right away.
    if (snapshotActiveTicketId != null) {
      await _apiService.clearLocalOpenTicket(
        snapshotActiveTicketId,
        tableId: snapshotActiveTicketTableId,
      );
    }

    // Mark table as available in in-memory list.
    if (snapshotActiveTicketTableId != null) {
      try {
        final idx = _tables.indexWhere(
          (t) => t.id == snapshotActiveTicketTableId,
        );
        if (idx >= 0) {
          final current = _tables[idx];
          setState(() {
            _tables[idx] = PosTable(
              id: current.id,
              name: current.name,
              capacity: current.capacity,
              status: current.status,
              hasOpenOrder: false,
            );
          });
        }
      } catch (_) {}
    }

    // Close the charge sheet and clear cart NOW — no waiting for server.
    _clearCart();
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.orderPaidSuccessfully ?? 'Order Paid Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // --- Background: print receipt from local snapshot, then sync to server ---
    Future(() async {
      // Print receipt from local cart snapshot (no server data needed).
      if (printReceipt && printerService.isConfigured) {
        Map<String, dynamic>? tpl;
        try {
          tpl = await _apiService.fetchBillTemplate(type: 'receipt');
        } catch (_) {}
        final headerText = (tpl?['header_text'] ?? '').toString();
        final footerText = (tpl?['footer_text'] ?? '').toString();
        // Points the server will add on payment (same rule as action_pay:
        // whole points of total / ratio), worked out here because the receipt
        // prints before the sync so it also works offline.
        int? pointsEarned;
        int? pointsBalance;
        var pointsLabel = 'Points';
        if (snapshotCustomerId != null) {
          final loyalty = await _apiService.fetchLoyaltyConfig();
          final ratio =
              double.tryParse((loyalty['points_ratio'] ?? '').toString()) ?? 100.0;
          pointsLabel = (loyalty['points_label'] ?? '').toString().trim();
          if (pointsLabel.isEmpty) pointsLabel = 'Points';
          pointsEarned = ratio > 0 ? (bd.totalDue / ratio).floor() : 0;
          if (snapshotCustomerPoints != null) {
            final balance = snapshotCustomerPoints + pointsEarned - snapshotPointsSpent;
            pointsBalance = balance < 0 ? 0 : balance;
          }
        }
        final receiptPrinters = printerService.profiles
            .where((p) => p.printReceiptsAndBills)
            .toList();
        var drawerOpened = false;
        for (final p in receiptPrinters) {
          final printed = await printerService.printReceiptToProfile(
            p,
            openDrawer: isCash && !drawerOpened,
            cartItems: snapshotCart,
            subtotal: bd.baseAmount,
            tax: bd.taxAmount,
            total: bd.totalDue,
            cashierName: widget.cashierName,
            subtotalRowLabel: subtotalRowLabel,
            taxRowLabel: taxLab,
            headerText: headerText,
            footerText: footerText,
            discountAmount: bd.discount.discountAmount,
            queueNumber: snapshotActiveTicketQueueNumber,
            logoBase64: tpl?['logo']?.toString(),
            customerName: snapshotCustomerName,
            pointsEarned: pointsEarned,
            pointsBalance: pointsBalance,
            pointsLabel: pointsLabel,
            payments: snapshotReceiptPayments,
            change: snapshotChange,
          );
          if (printed && isCash) drawerOpened = true;
        }
        if (isCash && !drawerOpened) {
          await printerService.openCashDrawer();
        }
      }

      // Sync to server (handles online success + offline queue internally).
      try {
        // The backend requires branch_id whenever partner_id is present, and
        // createOrder already sends the cashier's branch; match it here.
        final branchId = await _apiService.getCachedBranchId();
        if (snapshotActiveTicketId != null) {
          if (snapshotActiveTicketId < 0) {
            // Offline mock ticket — purge old tasks and queue a paid submit.
            await _apiService.purgeOfflineTasksForOrder(snapshotActiveTicketId);
            await _apiService.submitOrder(
              userId: cashierId,
              partnerId: snapshotCustomerId,
              branchId: branchId,
              tableId: snapshotActiveTicketTableId,
              paymentMethodId: snapshotPaymentMethod?.id,
              paymentType: snapshotActiveTicketPaymentType.isNotEmpty
                  ? snapshotActiveTicketPaymentType
                  : 'pay_at_store',
              isPaid: true,
              lines: allLines,
              discountType: snapshotDiscountType,
              discountValue: snapshotDiscountValue,
              payments: snapshotPayments,
            );
          } else {
            // A customer added at checkout must reach the order even when no
            // items were added, or the paid order (and its points) has no one.
            if (newLines.isNotEmpty || customerChanged) {
              await _apiService.updateOrder(
                orderId: snapshotActiveTicketId,
                customerId: snapshotCustomerId,
                lines: newLines,
                discountType: snapshotDiscountType,
                discountValue: snapshotDiscountValue,
              );
            }
            await _apiService.payOrder(
              orderId: snapshotActiveTicketId,
              paymentMethodId: snapshotPaymentMethod?.id,
              discountType: snapshotDiscountType,
              discountValue: snapshotDiscountValue,
              payments: snapshotPayments,
            );
          }
        } else {
          await _apiService.submitOrder(
            userId: cashierId,
            partnerId: snapshotCustomerId,
            branchId: branchId,
            isPaid: true,
            paymentMethodId: snapshotPaymentMethod?.id,
            lines: allLines,
            discountType: snapshotDiscountType,
            discountValue: snapshotDiscountValue,
            payments: snapshotPayments,
          );
        }
      } on ServerRejectedException catch (e) {
        // Refused for good (kept in Settings → Not saved by the server).
        if (mounted) {
          _showNotSavedDialog(
            _l10n?.saleNotSavedBody(e.message) ??
                'The server refused this sale, so it is NOT in Odoo:\n${e.message}\nThe receipt was printed. Please enter the sale again.',
          );
        }
      } catch (_) {
        // Server calls failed — offline queue already handles retry.
      }
    });
  }

  void _showNotSavedDialog(String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
        title: Text(_l10n?.notSavedTitle ?? 'Not saved by the server'),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n?.close ?? 'Close'),
          ),
        ],
      ),
    );
  }

  /// A free item whose promotion has ended is refused by the server after
  /// the receipt is printed. Ask the server first (online only); returns the
  /// ended promotion's name, or null when all is fine / offline.
  Future<String?> _endedFreePromotion() async {
    final freeNew = _cartItems.where((i) => i.isFreePromo && !i.isSaved).toList();
    if (freeNew.isEmpty) return null;
    final branchId = await _apiService.getCachedBranchId();
    final fresh = await _apiService.fetchFreePromotionsOnline(branchId: branchId);
    if (fresh == null) return null; // offline: the sync will tell
    if (mounted) setState(() => _freePromotions = fresh);
    for (final item in freeNew) {
      FreePromotion? promo;
      for (final p in fresh) {
        if (p.id == item.promotionId) promo = p;
      }
      if (promo == null || promo.availableFree(_cartItems) < 0) {
        return item.promotionName.isNotEmpty ? item.promotionName : (promo?.name ?? '');
      }
    }
    return null;
  }

  /// Everything the bill needs, copied before a save clears the cart.
  _BillSnapshot _snapshotBill({String? ticketName}) {
    final bd = _cartBreakdown();
    return _BillSnapshot(
      items: List<CartItem>.from(_cartItems),
      breakdown: bd,
      ticketName: ticketName,
    );
  }

  /// Prints the customer's bill (not paid yet) to the receipt printers.
  Future<bool> _printBill(
    BuildContext context,
    _BillSnapshot bill, {
    int? queueNumber,
  }) async {
    final bd = bill.breakdown;
    Map<String, dynamic>? tpl;
    try {
      tpl = await _apiService.fetchBillTemplate(type: 'bill');
    } catch (_) {}
    final headerText = (tpl?['header_text'] ?? '').toString();
    final footerText = (tpl?['footer_text'] ?? '').toString();
    final subLabel = bd.taxActive && _taxConfig.inclusive
        ? (_l10n?.amountExclVat ?? 'Amount (excl. VAT):')
        : 'Subtotal:';
    final taxLab = (bd.taxActive && _taxConfig.showOnReceipt)
        ? 'VAT (${_taxConfig.percentLabel}%):'
        : null;
    final ok = await printerService.printBill(
      cartItems: bill.items,
      subtotal: bd.baseAmount,
      tax: bd.taxAmount,
      total: bd.totalDue,
      cashierName: widget.cashierName,
      ticketName: bill.ticketName,
      subtotalRowLabel: subLabel,
      taxRowLabel: taxLab,
      headerText: headerText,
      footerText: footerText,
      discountAmount: bd.discount.discountAmount,
      queueNumber: queueNumber,
      logoBase64: tpl?['logo']?.toString(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (_l10n?.billPrinted ?? '🧾 Bill printed!')
                : (_l10n?.failedToPrintBill ??
                      'Failed to print bill. Check printer connection.'),
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
    return ok;
  }

  Future<bool> _confirmSaveBeforeBill(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n?.saveAndPrintBillTitle ?? 'Save ticket first?'),
        content: Text(
          _l10n?.saveAndPrintBillBody ??
              'This ticket is not saved yet. Save it to send the order to the kitchen, then the bill will print.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print_rounded),
            label: Text(_l10n?.saveAndPrintBill ?? 'Save & print bill'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Save current cart to existing ticket (update) or new ticket (table dialog).
  /// [printBill]: after the kitchen order, also print the bill (Print bill on
  /// an unsaved ticket).
  Future<void> _saveCurrentTicket(BuildContext context, {bool printBill = false}) async {
    if (_cartItems.isEmpty || _isSaving) return; // guard against double-tap
    if (_blockIfFreeOverused(context)) return;

    if (_activeTicketId != null) {
      // Only send the NEW (unsaved) items — saved items are already on the server
      final newLines = _cartItems
          .where((item) => !item.isSaved)
          .map(_orderLinePayload)
          .toList();

      // If there are no new items, nothing to update — just go back.
      // Unless the cashier picked a customer: this early return used to skip
      // the server entirely, so the customer vanished on reopening.
      if (newLines.isEmpty) {
        final customerId = _selectedCustomer?['id'] as int?;
        if (customerId != null && customerId != _activeTicketPartnerId) {
          setState(() => _isSaving = true);
          try {
            await _apiService.updateOrder(
              orderId: _activeTicketId!,
              tableId: _activeTicketTableId,
              customerId: customerId,
              customerName: _selectedCustomer?['name']?.toString(),
              lines: const [],
              discountType: _appliedDiscountType,
              discountValue: _appliedDiscountValue,
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
            return;
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        }
        if (printBill && context.mounted) {
          await _printBill(
            context,
            _snapshotBill(
              ticketName: _activeTicketLabel.isNotEmpty
                  ? '$_activeTicketLabel - ${_activeTicketName ?? ''}'
                  : _activeTicketName,
            ),
            queueNumber: _activeTicketQueueNumber,
          );
          return;
        }
        _clearCart();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.ticketSavedNoNewItems ?? 'Ticket saved (no new items added).'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }

      setState(() => _isSaving = true);
      BuildContext? dialogContext;

      // Items that are new AND not yet printed to the kitchen
      final unprintedNewItems = _cartItems
          .where((item) => !item.isSaved && !item.isPrinted)
          .toList();

      try {
        // Show spinner and capture its own context for reliable dismissal
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            dialogContext = ctx;
            return const Center(child: CircularProgressIndicator());
          },
        );

        await _apiService.updateOrder(
          orderId: _activeTicketId!,
          tableId: _activeTicketTableId,
          customerId: _selectedCustomer?['id'],
          customerName: _selectedCustomer?['name']?.toString(),
          lines: newLines,
          discountType: _appliedDiscountType,
          discountValue: _appliedDiscountValue,
        );

        // Print only the unprinted new items to kitchen/bar printers
        if (unprintedNewItems.isNotEmpty && printerService.isConfigured) {
          final printedCount = await _printOrderItemsToKitchen(
            unprintedNewItems,
            respectCategoryFilters: true,
            queueNumber: _activeTicketQueueNumber,
          );
          // Only mark as printed when at least one printer succeeded.
          if (printedCount > 0) {
            setState(() {
              for (final item in unprintedNewItems) {
                item.isPrinted = true;
              }
            });
          }
        }

        // Dismiss spinner using its own context
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.pop(dialogContext!);
        } else if (context.mounted) {
          Navigator.pop(context);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ticket ${_activeTicketName ?? ''} updated with ${newLines.length} new item(s)!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Keep full cart visible: mark new lines as saved instead of clearing.
        // Clearing made totals look like "only the latest" and forced re-selecting the ticket.
        setState(() {
          for (final item in _cartItems) {
            item.isSaved = true;
          }
        });

        // After the kitchen order, so a shared printer gets them one by one.
        if (printBill && context.mounted) {
          await _printBill(
            context,
            _snapshotBill(
              ticketName: _activeTicketLabel.isNotEmpty
                  ? '$_activeTicketLabel - ${_activeTicketName ?? ''}'
                  : _activeTicketName,
            ),
            queueNumber: _activeTicketQueueNumber,
          );
        }
      } catch (e) {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.pop(dialogContext!);
        } else if (context.mounted) {
          Navigator.pop(context);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    } else {
      // No active ticket — show table selection immediately
      // Force refresh table status BEFORE opening selector so OPEN badges are accurate.
      try {
        final freshTables = await _apiService.fetchTables(forceRefresh: true);
        if (mounted) setState(() => _tables = freshTables);
      } catch (_) {
        // Fall back to existing cached _tables if network refresh fails.
      }

      if (context.mounted) {
        _showTableSelectionDialog(context, printBill: printBill);
      }
    }
  }

  bool _isOpeningTicket = false;

  void _showTableSelectionDialog(BuildContext context, {bool printBill = false}) {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: !_isOpeningTicket,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final bool isMobile = screenWidth < 600;

        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: isMobile ? screenWidth * 0.95 : 700,
              constraints: BoxConstraints(maxHeight: isMobile ? 600 : 650),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium Header
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: isMobile ? 16 : 20,
                    ),
                    color: Ld.navy,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Ld.navyRaised,
                            borderRadius: BorderRadius.circular(Ld.r),
                            border: Border.all(color: Ld.navyLine),
                          ),
                          child: const Icon(
                            Icons.table_restaurant_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_l10n?.selectTable ?? 'Select Table',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ld.title(22, color: Colors.white),
                              ),
                              Text(_l10n?.chooseLocationNewTicket ?? 'Choose a location to open a new ticket',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Ld.onNavyMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            fixedSize: const Size(44, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Ld.r),
                              side: const BorderSide(color: Ld.navyLine),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  // Save under a name instead of a table (also works with no tables).
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 24,
                      isMobile ? 12 : 16,
                      isMobile ? 12 : 24,
                      0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isOpeningTicket
                            ? null
                            : () async {
                                final label = await _promptTicketName(
                                  context,
                                  title: _l10n?.customNameAction ?? 'Custom name',
                                  help: _l10n?.customNameHelp ??
                                      'Save this order under a name instead of a table.',
                                );
                                if (label == null || label.isEmpty || !context.mounted) {
                                  return;
                                }
                                await _processOpenTicket(context, setDialogState, label: label, printBill: printBill);
                              },
                        icon: const Icon(Icons.person_pin_rounded),
                        label: Text(_l10n?.customNameAction ?? 'Custom name'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Ld.navy,
                          side: const BorderSide(color: Ld.navy, width: 1.5),
                          minimumSize: const Size(64, 52),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Ld.rMd),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: Ld.sans,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _tables.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sync_problem,
                                  size: 48,
                                  color: Ld.faint,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No tables available.\nPlease sync catalog.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Ld.muted,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.all(isMobile ? 12 : 24),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: screenWidth > 800
                                      ? 4
                                      : (screenWidth > 500 ? 3 : 2),
                                  childAspectRatio: isMobile ? 1.0 : 0.9,
                                  crossAxisSpacing: isMobile ? 10 : 16,
                                  mainAxisSpacing: isMobile ? 10 : 16,
                                ),
                            itemCount: _tables.length,
                            itemBuilder: (context, index) {
                              final table = _tables[index];
                              final isAvailable =
                                  table.status == 'available' ||
                                  table.status == 'empty';
                              final hasOpenOrder = table.hasOpenOrder;

                              Color statusColor;
                              IconData statusIcon;

                              if (!isAvailable) {
                                statusColor = Ld.danger;
                                statusIcon = Icons.lock_outline;
                              } else if (hasOpenOrder) {
                                statusColor = Ld.warning;
                                statusIcon = Icons.receipt_long_outlined;
                              } else {
                                statusColor = Ld.success;
                                statusIcon = Icons.check_circle_outline;
                              }

                              final bool selectable =
                                  isAvailable &&
                                  !hasOpenOrder &&
                                  !_isOpeningTicket;

                              return InkWell(
                                onTap: selectable
                                    ? () => _processOpenTicket(
                                        context,
                                        setDialogState,
                                        table: table,
                                        printBill: printBill,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 16 : 20,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: selectable
                                        ? Ld.surface
                                        : Ld.ground,
                                    borderRadius: BorderRadius.circular(
                                      isMobile ? 16 : 20,
                                    ),
                                    border: Border.all(
                                      color: selectable
                                          ? Ld.line
                                          : statusColor.withOpacity(0.3),
                                      width: selectable ? 1 : 1.5,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(
                                          isMobile ? 8 : 12,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                isMobile ? 6 : 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                selectable
                                                    ? Icons.table_bar
                                                    : statusIcon,
                                                color: statusColor,
                                                size: isMobile ? 18 : 24,
                                              ),
                                            ),
                                            SizedBox(height: isMobile ? 4 : 12),
                                            Text(
                                              table.name,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: Ld.serif,
                                                fontSize: isMobile ? 15 : 17,
                                                fontWeight: FontWeight.w700,
                                                color: selectable
                                                    ? Ld.navy
                                                    : Ld.muted,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.people_outline,
                                                  size: isMobile ? 12 : 14,
                                                  color: Ld.faint,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${table.capacity}',
                                                  style: TextStyle(
                                                    fontSize: isMobile
                                                        ? 11
                                                        : 13,
                                                    color: Ld.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!selectable && !isAvailable)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.4,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    isMobile ? 16 : 20,
                                                  ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Footer Legend
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color: Ld.ground,
                      border: Border(top: BorderSide(color: Ld.line)),
                    ),
                    child: isMobile
                        ? Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _statusDot(
                                Ld.success,
                                _l10n?.tableAvailable ?? 'Available',
                              ),
                              _statusDot(
                                Ld.warning,
                                _l10n?.tableOpen ?? 'Open',
                              ),
                              _statusDot(
                                Ld.danger,
                                _l10n?.tableOccupied ?? 'Occupied',
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              _statusDot(
                                Ld.success,
                                _l10n?.tableAvailable ?? 'Available',
                              ),
                              const SizedBox(width: 24),
                              _statusDot(
                                Ld.warning,
                                _l10n?.openOrder ?? 'Open Order',
                              ),
                              const SizedBox(width: 24),
                              _statusDot(
                                Ld.danger,
                                _l10n?.tableOccupied ?? 'Occupied',
                              ),
                              const Spacer(),
                              if (_isOpeningTicket)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Ld.muted,
          ),
        ),
      ],
    );
  }

  /// Opens a new ticket at [table], or under the name [label] with no table.
  Future<void> _processOpenTicket(
    BuildContext context,
    StateSetter setDialogState, {
    PosTable? table,
    String? label,
    bool printBill = false,
  }) async {
    final lines = _cartItems.map(_orderLinePayload).toList();

    final cashierId = widget.cashierId;
    final place = table?.name ?? label ?? '';

    // --- Optimistic UI: update state immediately, no waiting ---

    // Mark table as open in local in-memory list right away.
    if (table != null) {
      try {
        final idx = _tables.indexWhere((t) => t.id == table.id);
        if (idx >= 0) {
          final current = _tables[idx];
          setState(() {
            _tables[idx] = PosTable(
              id: current.id,
              name: current.name,
              capacity: current.capacity,
              status: current.status,
              hasOpenOrder: true,
            );
          });
        }
      } catch (_) {}
    }

    // Capture items for kitchen print before cart is cleared.
    final itemsForKitchen = List<CartItem>.from(_cartItems);
    // The bill too (items, discount, VAT): the cart is cleared below.
    final bill = printBill ? _snapshotBill(ticketName: place) : null;
    // Same for the customer: _clearCart nulls it, and createOrder below used to
    // read it afterwards, so every new ticket was saved without its customer.
    final customerId = _selectedCustomer?['id'] as int?;
    final customerName = _selectedCustomer?['name']?.toString();

    // Close dialog and clear cart instantly — no waiting for server.
    _clearCart();
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.ticketOpenedAt(place) ?? 'Ticket opened at $place!'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Persist to server in background, then print kitchen with queue number.
    _apiService
        .createOrder(
          userId: cashierId,
          tableId: table?.id,
          ticketLabel: label,
          customerId: customerId,
          customerName: customerName,
          lines: lines,
        )
        .then((response) {
          final qn = (response['queue_number'] ?? 0).toInt();
          if (qn > 0) {
            _activeTicketQueueNumber = qn;
          }
          if (printerService.isConfigured) {
            _printOrderItemsToKitchen(
                  itemsForKitchen,
                  respectCategoryFilters: true,
                  queueNumber: qn,
                )
                .then((count) {
                  if (count > 0) {
                    for (final item in itemsForKitchen) {
                      item.isPrinted = true;
                    }
                  }
                })
                .catchError((_) {})
                // Bill after the kitchen order, with the same queue number.
                .whenComplete(() {
                  if (bill != null && mounted) {
                    _printBill(this.context, bill, queueNumber: qn);
                  }
                });
          }
        })
        .catchError((Object e) {
          if (e is ServerRejectedException) {
            // Refused (e.g. promotion ended): nothing was saved, nothing
            // printed. Give the items back unless another order is open.
            if (!mounted) return;
            setState(() {
              if (_cartItems.isEmpty && _activeTicketId == null) {
                _cartItems = List<CartItem>.from(itemsForKitchen);
              }
              if (table != null) {
                final idx = _tables.indexWhere((t) => t.id == table.id);
                if (idx >= 0) {
                  final current = _tables[idx];
                  _tables[idx] = PosTable(
                    id: current.id,
                    name: current.name,
                    capacity: current.capacity,
                    status: current.status,
                    hasOpenOrder: false,
                  );
                }
              }
            });
            _showNotSavedDialog(
              _l10n?.ticketNotSavedBody(e.message) ??
                  'The server refused this ticket:\n${e.message}\nThe items are back in the cart.',
            );
            return;
          }
          // Offline fallback: print without queue number
          if (printerService.isConfigured) {
            _printOrderItemsToKitchen(
                  itemsForKitchen,
                  respectCategoryFilters: true,
                )
                .then((count) {
                  if (count > 0) {
                    for (final item in itemsForKitchen) {
                      item.isPrinted = true;
                    }
                  }
                })
                .catchError((_) {})
                .whenComplete(() {
                  if (bill != null && mounted) {
                    _printBill(this.context, bill);
                  }
                });
          }
        });
    // No finally needed — _isOpeningTicket is no longer set because we never
    // show the spinner; the dialog is already dismissed above.
  }

  void _openScannerDialog() {
    final codeController = TextEditingController();
    final MobileScannerController scannerController = MobileScannerController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isClaiming = false;
        bool isScanning = false;
        Map<String, dynamic>? claimedData;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (claimedData != null) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(_l10n?.rewardClaimed ?? 'Reward Claimed!', style: Ld.title(21, color: Ld.success)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Ld.success, size: 64),
                    const SizedBox(height: 16),
                    Text('Customer: ${claimedData!['customer_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _l10n?.voucherProduct(bilingualName(claimedData!)) ??
                          'Product: ${bilingualName(claimedData!)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(_l10n?.giveItemToCustomer ?? 'Please give this item to the customer.'),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(_l10n?.done ?? 'Done'),
                  )
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(_l10n?.claimRewardVoucher ?? 'Claim Reward Voucher', style: Ld.title(21)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isScanning)
                    SizedBox(
                      height: 250,
                      width: 250,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: MobileScanner(
                              controller: scannerController,
                              onDetect: (capture) {
                                final List<Barcode> barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                  final code = barcodes.first.rawValue!;
                                  setDialogState(() {
                                    codeController.text = code;
                                    isScanning = false;
                                  });
                                }
                              },
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              onPressed: () {
                                setDialogState(() => isScanning = false);
                              },
                            ),
                          )
                        ],
                      ),
                    )
                  else ...[
                    const Text('Enter or scan the customer\'s reward voucher code:'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: _l10n?.voucherCode ?? 'Voucher Code',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, color: Ld.navy),
                              onPressed: () {
                                setDialogState(() {
                                  isScanning = true;
                                  errorText = null;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => codeController.clear(),
                            ),
                          ],
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (val) async {
                        if (val.trim().isEmpty) return;
                        setDialogState(() {
                          isClaiming = true;
                          errorText = null;
                        });
                        try {
                          final res = await _apiService.claimVoucher(val.trim());
                          setDialogState(() {
                            claimedData = res;
                            isClaiming = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            errorText = e.toString().replaceAll('Exception:', '').trim();
                            isClaiming = false;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isClaiming ? null : () => Navigator.pop(ctx),
                  child: Text(_l10n?.cancel ?? 'Cancel', style: TextStyle(color: Ld.muted)),
                ),
                if (!isScanning)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Ld.navy, foregroundColor: Colors.white),
                    onPressed: isClaiming ? null : () async {
                      if (codeController.text.trim().isEmpty) return;
                      setDialogState(() {
                        isClaiming = true;
                        errorText = null;
                      });
                      try {
                        final res = await _apiService.claimVoucher(codeController.text.trim());
                        setDialogState(() {
                          claimedData = res;
                          isClaiming = false;
                        });
                      } catch (e) {
                        setDialogState(() {
                          errorText = e.toString().replaceAll('Exception:', '').trim();
                          isClaiming = false;
                        });
                      }
                    },
                    child: isClaiming ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_l10n?.claim ?? 'Claim'),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) {
      scannerController.dispose();
    });
  }
}



/// One row of a split payment in the charge sheet.
class _SplitPaymentRow {
  PaymentMethod method;
  final TextEditingController amount;

  _SplitPaymentRow(this.method, double value)
      : amount = TextEditingController(text: value > 0 ? money(value) : '');

  double get value => parseMoney(amount.text);

  bool get isCash => method.allowsChange;
}

/// Totals of a split payment. Only cash may go over the total (that is the
/// change); card / transfer rows must not exceed it.
class _SplitPaymentSummary {
  final double paid;
  final double remaining;
  final double change;
  final bool tooMuchNonCash;
  final List<_SplitPaymentRow> rows;
  final double total;

  _SplitPaymentSummary._(this.rows, this.total, this.paid, this.remaining, this.change, this.tooMuchNonCash);

  factory _SplitPaymentSummary.of(List<_SplitPaymentRow> rows, double total) {
    final nonCash = rows.where((r) => !r.isCash).fold<double>(0, (s, r) => s + r.value);
    final paid = rows.fold<double>(0, (s, r) => s + r.value);
    final remaining = total - paid;
    return _SplitPaymentSummary._(
      rows,
      total,
      paid,
      remaining > 0.5 ? remaining : 0,
      paid - total > 0.5 ? paid - total : 0,
      nonCash > total + 0.5,
    );
  }

  bool get ok => rows.isNotEmpty && remaining == 0 && !tooMuchNonCash;

  /// What the server stores: card/transfer as typed, cash only the part that
  /// pays the bill (the rest went back as change). Same method rows merged.
  List<Map<String, dynamic>> get serverPayments {
    final byMethod = <int, double>{};
    final names = <int, String>{};
    final nonCash = rows.where((r) => !r.isCash).fold<double>(0, (s, r) => s + r.value);
    var cashLeft = total - nonCash;
    for (final r in rows) {
      var amount = r.value;
      if (r.isCash) {
        amount = amount < cashLeft ? amount : cashLeft;
        cashLeft -= amount;
      }
      if (amount <= 0) continue;
      byMethod[r.method.id] = (byMethod[r.method.id] ?? 0) + amount;
      names[r.method.id] = r.method.name;
    }
    return [
      for (final e in byMethod.entries)
        {'payment_method_id': e.key, 'payment_method': names[e.key], 'amount': e.value},
    ];
  }

  /// For the receipt: what each method actually handed over (cash before change).
  List<Map<String, dynamic>> get receiptPayments => [
        for (final r in rows)
          if (r.value > 0) {'payment_method': r.method.name, 'amount': r.value},
      ];

  /// The method with the largest share becomes the order's main method.
  PaymentMethod get mainMethod {
    final pays = serverPayments;
    if (pays.isEmpty) return rows.first.method;
    pays.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return rows.firstWhere((r) => r.method.id == pays.first['payment_method_id']).method;
  }
}

/// A bill to print later: the cart is cleared when a new ticket is saved.
class _BillSnapshot {
  final List<CartItem> items;
  final CartBreakdown breakdown;
  final String? ticketName;

  const _BillSnapshot({
    required this.items,
    required this.breakdown,
    this.ticketName,
  });
}

/// "SAVE TICKET" -> "Save ticket": some English labels are stored in capitals;
/// the design uses sentence case. Lao (no case) is returned unchanged.
String _sentence(String s) {
  if (s != s.toUpperCase() || !RegExp(r'[A-Z]').hasMatch(s)) return s;
  final lower = s.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

/// Category chips that scroll sideways (phones and narrow tablets). Follows
/// [controller], so swiping the products still changes the category and the
/// chosen chip scrolls into view.
class _CategoryChipsBar extends StatefulWidget {
  final TabController controller;
  final List<String> labels;
  final List<int> counts;

  const _CategoryChipsBar({
    required this.controller,
    required this.labels,
    required this.counts,
  });

  @override
  State<_CategoryChipsBar> createState() => _CategoryChipsBarState();
}

class _CategoryChipsBarState extends State<_CategoryChipsBar> {
  final List<GlobalKey> _keys = [];
  int _shown = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTab);
  }

  @override
  void didUpdateWidget(_CategoryChipsBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTab);
      widget.controller.addListener(_onTab);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (!mounted) return;
    final i = widget.controller.index;
    if (i == _shown) return;
    setState(() => _shown = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || i >= _keys.length) return;
      final ctx = _keys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 200));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    while (_keys.length < widget.labels.length) {
      _keys.add(GlobalKey());
    }
    final selected = widget.controller.index;
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: widget.labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => KeyedSubtree(
          key: _keys[i],
          child: Center(
            child: LdChoiceChip(
              label: widget.labels[i],
              selected: i == selected,
              count: i < widget.counts.length ? '${widget.counts[i]}' : null,
              onTap: () => widget.controller.animateTo(i),
            ),
          ),
        ),
      ),
    );
  }
}
