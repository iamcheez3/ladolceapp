import 'package:flutter/material.dart';
import 'dart:async';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/table.dart';
import '../models/payment_method.dart';
import '../models/ticket.dart';
import '../widgets/product_grid.dart';
import '../widgets/product_list.dart';
import '../widgets/cart_sidebar.dart';
import '../screens/tickets_screen.dart';
import '../screens/receipt_history_screen.dart';
import '../screens/manage_items_screen.dart';
import '../screens/login_screen.dart';
import '../screens/split_ticket_screen.dart';
import '../screens/self_orders_review_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/bill_template_settings_screen.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../models/topping.dart';
import '../models/combo.dart';
import '../theme/ladolce_pos_ui.dart';
import 'package:intl/intl.dart';
import '../models/pos_tax_config.dart';
import '../utils/pos_tax.dart';

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
  static const Color _brandNavy = LaDolcePosUi.navy;
  static const Color _brandNavy2 = LaDolcePosUi.navy2;
  static const Color _brandSurface = LaDolcePosUi.surface;

  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  String? _cachedPosName;
  String? _cachedBranchName;
  PosTaxConfig _taxConfig = PosTaxConfig.disabled;
  int _pendingSelfOrdersCount = 0;
  Timer? _pendingSelfOrdersTimer;
  bool _pendingSelfOrdersFetching = false;

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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF1FB) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isActive ? _brandNavy : Colors.black54),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _brandNavy : Colors.black87,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              trailing,
            ],
          ],
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
      setState(() => _pendingSelfOrdersCount = nextCount);

      if (notifyOnIncrease && nextCount > prevCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New self order waiting review ($nextCount)'),
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
  String _activeTicketPaymentType = '';
  int? _activeTicketPaymentMethodId;
  String _activeTicketPaymentMethodName = '';
  Map<String, dynamic>? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    printerService.initialize();
    _loadPosProfileLabels();
    _fetchOdooProducts();

    // Self-order alert/badge: poll backend so POS is alerted even without FCM.
    _refreshPendingSelfOrders(notifyOnIncrease: false);
    _pendingSelfOrdersTimer =
        Timer.periodic(const Duration(seconds: 12), (_) => _refreshPendingSelfOrders());
  }

  Future<void> _loadPosProfileLabels() async {
    try {
      final posName = await _apiService.getCachedPosName();
      final branchName = await _apiService.getCachedBranchName();
      final tax = await _apiService.getPosTaxConfig();
      if (!mounted) return;
      setState(() {
        _cachedPosName = posName;
        _cachedBranchName = branchName;
        _taxConfig = tax;
      });
    } catch (_) {}
  }

  PosTaxBreakdown _cartTaxBreakdown() {
    final linesSum =
        _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    return computePosTaxBreakdown(linesSum, _taxConfig);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pendingSelfOrdersTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOdooProducts({bool backgroundRefresh = false}) async {
    // ── Step 1: Load from cache instantly if available ────────────────────────
    if (!backgroundRefresh) {
      final cachedProducts = await _apiService.getCachedProducts();
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
          _categories = [Category(id: 'All', name: 'All Items'), ...uniqueCategories.map((name) => Category(id: name, name: name))]
            ;
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
              content: Text('✅ Synced $syncedCount offline orders to server.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });

      final products = await _apiService.fetchProducts(limit: 100);
      final rawCombos = await _apiService.fetchCombos();
      final combos = rawCombos
          .map((c) => Product.fromCombo(Combo.fromJson(c)))
          .toList();

      // Inject combos so they appear in POS
      products.addAll(combos);

      final tables = await _apiService.fetchTables();
      final methods = await _apiService.fetchPaymentMethods();

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
          _categories = [Category(id: 'All', name: 'All Items'), ...uniqueCategories.map((name) => Category(id: name, name: name))]
            ;
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
          content: Text(
            '✅ Synced all data.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
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

  void _addDirectlyToCart(Product product, List<Topping> selectedToppings) {
    setState(() {
      // Check if there's already a NEW (unsaved) item with EXACTLY the same toppings
      final existingNewIndex = _cartItems.indexWhere((item) {
        if (item.product.id != product.id || item.isSaved) return false;

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
          ),
        );
      }
    });
  }

  void _showToppingsSelection(Product product) {
    List<Topping> selectedToppings = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + LaDolcePosUi.modalBottomPadding(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Toppings for ${product.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: product.toppings.length,
                      itemBuilder: (context, index) {
                        final topping = product.toppings[index];
                        final isSelected = selectedToppings.contains(topping);
                        return CheckboxListTile(
                          title: Text(topping.name),
                          subtitle: topping.extraPrice > 0
                              ? Text(
                                  '+₭${topping.extraPrice.toStringAsFixed(2)}',
                                )
                              : const Text('Free'),
                          value: isSelected,
                          activeColor: _brandNavy,
                          onChanged: (bool? value) {
                            setSheetState(() {
                              if (value == true) {
                                selectedToppings.add(topping);
                              } else {
                                selectedToppings.remove(topping);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _addDirectlyToCart(
                              product,
                              [],
                            ); // Skip toppings completely
                          },
                          child: const Text('Add Without Toppings'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandNavy,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _addDirectlyToCart(product, selectedToppings);
                          },
                          child: const Text('Add To Order'),
                        ),
                      ),
                    ],
                  ),
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
      _activeTicketPaymentType = '';
      _activeTicketPaymentMethodId = null;
      _activeTicketPaymentMethodName = '';
      _selectedCustomer = null;
    });
  }

  /// Per-unit line price for API payloads (base + topping extras).
  /// Matches [CartItem.totalPrice] / qty so offline cached totals are consistent.
  double _lineUnitPrice(CartItem item) {
    if (item.priceUnitFromOrder != null) {
      return item.priceUnitFromOrder!;
    }
    double unit = item.product.price;
    for (final t in item.selectedToppings) {
      unit += t.extraPrice;
    }
    return unit;
  }

  Future<void> _handleClearTicket(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_activeTicketId == null) {
      _clearCart();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ticket cleared.'),
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
        const SnackBar(
          content: Text('Ticket removed by Admin PIN.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cannot clear ticket: $e'),
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
                  color: Colors.white.withOpacity(0.12),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                    ),
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
            title: const Text(
              'Admin PIN Required',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter PIN to clear selected ticket',
                    style: TextStyle(color: Colors.white70),
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
                              ? Colors.white
                              : Colors.white.withOpacity(0.25),
                          border: Border.all(
                            color: hasError
                                ? Colors.redAccent
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasError)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'PIN is required',
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
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
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: _brandSurface,
      appBar: AppBar(
        backgroundColor: _brandNavy,
        centerTitle: true,
        title: InkWell(
          onTap: () async {
            final result = await Navigator.push<ResumedTicket>(
              context,
              MaterialPageRoute(
                builder: (_) => TicketsScreen(cachedProducts: _products),
              ),
            );
            if (result != null) {
              setState(() {
                _cartItems = result.cartItems;
                _activeTicketId = result.orderId;
                _activeTicketName = result.orderName;
                _activeTicketTableId = result.tableId;
                _activeTicketPaymentType = result.paymentType;
                _activeTicketPaymentMethodId = result.paymentMethodId;
                _activeTicketPaymentMethodName = result.paymentMethodName;
              });
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_outlined, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Open Tickets',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // View toggle (Grid / List)
          IconButton(
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
          ),
          const SizedBox(width: 8),

          // Ticket / Sync Operations Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'Ticket Options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 8,
            color: Colors.white,
            onSelected: (value) async {
              switch (value) {
                case 'clear':
                  await _handleClearTicket(context);
                  break;

                case 'print':
                  if (_cartItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No items in the current ticket to print.',
                        ),
                      ),
                    );
                    break;
                  }
                  if (!printerService.isConfigured) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No printer configured. Set up a printer in Settings first.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    break;
                  }
                  {
                    final bd = _cartTaxBreakdown();
                    Map<String, dynamic>? tpl;
                    try {
                      tpl = await _apiService.fetchBillTemplate(type: 'bill');
                    } catch (_) {}
                    final headerText = (tpl?['header_text'] ?? '').toString();
                    final footerText = (tpl?['footer_text'] ?? '').toString();
                    final subLabel = bd.taxActive && _taxConfig.inclusive
                        ? 'Amount (excl. VAT):'
                        : 'Subtotal:';
                    final taxLab = (bd.taxActive && _taxConfig.showOnReceipt)
                        ? 'VAT (${_taxConfig.percentLabel}%):'
                        : null;
                    final ok = await printerService.printBill(
                      cartItems: _cartItems,
                      subtotal: bd.baseAmount,
                      tax: bd.taxAmount,
                      total: bd.totalDue,
                      cashierName: widget.cashierName,
                      ticketName: _activeTicketName,
                      subtotalRowLabel: subLabel,
                      taxRowLabel: taxLab,
                      headerText: headerText,
                      footerText: footerText,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? '🧾 Bill printed!'
                                : 'Failed to print bill. Check printer connection.',
                          ),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  }
                  break;

                case 'reprint':
                  // Reprint ALL items in the current ticket to kitchen/bar printers
                  if (_activeTicketId == null) {
                    break;
                  }
                  if (_cartItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No items in the current ticket to reprint.',
                        ),
                      ),
                    );
                    break;
                  }
                  if (!printerService.isConfigured) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No printer configured. Set up a printer in Settings first.',
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
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            reprintCount > 0
                                ? '🖨️ Order reprinted to $reprintCount kitchen printer(s).'
                                : 'No available printer could print this reprint request.',
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
                      const SnackBar(
                        content: Text(
                          'No items in the current ticket to split.',
                        ),
                      ),
                    );
                    break;
                  }
                  if (_activeTicketId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please save the ticket first before splitting.',
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
                      ) => items
                          .map(
                            (item) => {
                              'product_id': item.product.id,
                              'qty': item.quantity,
                              'price_unit': _lineUnitPrice(item),
                              'topping_ids': item.selectedToppings
                                  .map((t) => t.id)
                                  .toList(),
                            },
                          )
                          .toList();

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
                          content: Text('Split error: $e'),
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
                case 'drawer':
                  if (!printerService.isConfigured) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No printer configured. Set up a printer first.',
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
                              ? '🗃️ Cash drawer opened!'
                              : 'Failed to open drawer. Check printer connection.',
                        ),
                        backgroundColor: opened ? Colors.green : Colors.red,
                      ),
                    );
                  }
                  break;

                default:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feature coming soon!')),
                  );
              }
            },
            itemBuilder: (BuildContext menuCtx) {
              final bool hasItems = _cartItems.isNotEmpty;
              final bool hasTicket = _activeTicketId != null;
              final bool ticketSelected = hasItems || hasTicket;

              Widget disablableTile(
                IconData icon,
                String label, {
                required bool enabled,
              }) {
                final Color? col = enabled ? null : Colors.grey.shade400;
                return ListTile(
                  dense: true,
                  leading: Icon(icon, color: col),
                  title: Text(label, style: TextStyle(color: col)),
                );
              }

              return <PopupMenuEntry<String>>[
                // ── Ticket actions ──────────────────────────────────────
                PopupMenuItem<String>(
                  value: 'clear',
                  enabled: ticketSelected,
                  child: disablableTile(
                    Icons.delete_outline_rounded,
                    'Clear ticket',
                    enabled: ticketSelected,
                  ),
                ),
                const PopupMenuDivider(),

                // ── Printer actions ─────────────────────────────────────
                PopupMenuItem<String>(
                  value: 'print',
                  enabled: hasItems,
                  child: disablableTile(
                    Icons.receipt_outlined,
                    'Print bill',
                    enabled: hasItems,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'reprint',
                  enabled: hasTicket,
                  child: disablableTile(
                    Icons.print_outlined,
                    'Reprint order (kitchen)',
                    enabled: hasTicket,
                  ),
                ),
                const PopupMenuDivider(),

                // ── Transfer actions ────────────────────────────────────
                PopupMenuItem<String>(
                  value: 'split',
                  enabled: hasItems && hasTicket,
                  child: disablableTile(
                    Icons.call_split_rounded,
                    'Split ticket',
                    enabled: hasItems && hasTicket,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'move',
                  enabled: hasTicket,
                  child: disablableTile(
                    Icons.open_in_new_rounded,
                    'Move ticket',
                    enabled: hasTicket,
                  ),
                ),
                const PopupMenuDivider(),

                // ── Always-enabled ──────────────────────────────────────
                const PopupMenuItem<String>(
                  value: 'drawer',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.lock_open_outlined),
                    title: Text('Open cash drawer'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'sync',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.sync_rounded),
                    title: Text('Sync'),
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_brandNavy, _brandNavy2],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Initial avatar
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.20),
                      child: Text(
                        widget.cashierName.isNotEmpty
                            ? widget.cashierName[0].toLowerCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: widget.cashierName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: widget.role == 'admin' ? ' (Admin)' : ' (Cashier)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((_cachedPosName ?? '').trim().isNotEmpty)
                          (_cachedPosName ?? '').trim()
                        else
                          'POS Terminal',
                        if ((_cachedBranchName ?? '').trim().isNotEmpty)
                          ' • ${(_cachedBranchName ?? '').trim()}',
                      ].join(''),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // ── Menu Items ───────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  children: [
                    _drawerItem(
                      icon: Icons.storefront_outlined,
                      label: 'Sales',
                      isActive: true,
                      onTap: () => Navigator.pop(context),
                    ),
                    _drawerItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Receipts',
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
                      label: 'Self Orders Review',
                      trailing: _pendingSelfOrdersCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$_pendingSelfOrdersCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            )
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
                      label: 'Items',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageItemsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _drawerItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        _showSettingsSheet(context);
                      },
                    ),
                  ],
                ),
              ),

              // ── Lock / Switch User ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await _apiService.logout();
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: _brandNavy,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lock / Switch User',
                            style: TextStyle(
                              color: _brandNavy,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            // Products Section
            Expanded(
              flex: 5,
              child: _categories.isEmpty && _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _categories.isEmpty && _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: $_errorMessage',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _fetchOdooProducts();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : DefaultTabController(
                      length: _categories.length,
                      child: Column(
                        children: [
                          // Permanent Search Bar
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            margin: const EdgeInsets.only(top: 8),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search products…',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 15,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.grey,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    // borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    // borderSide: BorderSide(color: _brandNavy, width: 1.5),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() => _searchQuery = value);
                                },
                              ),
                            ),
                          ),

                          // Swipeable Categories TabBar
                          Container(
                            color: Colors.white,
                            child: TabBar(
                              isScrollable: true,
                              indicatorColor: _brandNavy,
                              labelColor: _brandNavy,
                              unselectedLabelColor: Colors.grey[500],
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w400,
                              ),
                              tabs: _categories
                                  .map((c) => Tab(text: c.name))
                                  .toList(),
                            ),
                          ),
                          const Divider(height: 1),

                          // Products TabBarView (Grid/List)
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _errorMessage != null
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Error: $_errorMessage',
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _fetchOdooProducts,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                : TabBarView(
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
                                                  p.name.toLowerCase().contains(
                                                    query,
                                                  ) ||
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
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.search_off,
                                                size: 64,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                _searchQuery.isNotEmpty
                                                    ? 'No products matching "$_searchQuery"'
                                                    : 'No products in this category',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return _isGridView
                                          ? ProductGrid(
                                              products: tabProducts,
                                              onProductTap: _addToCart,
                                            )
                                          : ProductList(
                                              products: tabProducts,
                                              onProductTap: _addToCart,
                                            );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Cart Section (Sidebar)
            if (isDesktop) const VerticalDivider(width: 1),
            if (isDesktop)
              Expanded(
                flex: 3,
                child: CartSidebar(
                  cartItems: _cartItems,
                  onUpdateQuantity: _updateQuantity,
                  onClearCart: _clearCart,
                  onViewTickets: () async {
                    final result = await Navigator.push<ResumedTicket>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TicketsScreen(cachedProducts: _products),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _cartItems = result.cartItems;
                        _activeTicketId = result.orderId;
                        _activeTicketName = result.orderName;
                        _activeTicketTableId = result.tableId;
                        _activeTicketPaymentType = result.paymentType;
                        _activeTicketPaymentMethodId = result.paymentMethodId;
                        _activeTicketPaymentMethodName =
                            result.paymentMethodName;
                      });
                    }
                  },
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
                  taxConfig: _taxConfig,
                ),
              ),
          ],
        ),
      ),
      // Mobile Cart floating button or bottom sheet could go here if not desktop
      bottomNavigationBar: !isDesktop && _cartItems.isNotEmpty
          ? _buildMobileCartBar(context)
          : null,
    );
  }

  Widget _buildMobileCartBar(BuildContext context) {
    final tItems = _cartItems.fold(0, (sum, item) => sum + item.quantity);
    final payTotal = _cartTaxBreakdown().totalDue;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + LaDolcePosUi.gestureBarBottomPad(context),
      ),
      child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => StatefulBuilder(
                builder: (innerCtx, setSheetState) => FractionallySizedBox(
                  heightFactor: 0.8,
                  child: CartSidebar(
                    cartItems: _cartItems,
                    onUpdateQuantity: (item, newQty) {
                      _updateQuantity(item, newQty);
                      setSheetState(() {});
                      if (_cartItems.isEmpty) Navigator.pop(ctx);
                    },
                    onClearCart: () {
                      _clearCart();
                      Navigator.pop(ctx);
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
                        setState(() {
                          _cartItems = result.cartItems;
                          _activeTicketId = result.orderId;
                          _activeTicketName = result.orderName;
                          _activeTicketTableId = result.tableId;
                          _activeTicketPaymentType = result.paymentType;
                          _activeTicketPaymentMethodId = result.paymentMethodId;
                          _activeTicketPaymentMethodName =
                              result.paymentMethodName;
                        });
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
                    onAddCustomer: () {
                      Navigator.pop(ctx);
                      _showCustomerSelection(context);
                    },
                    onClearCustomer: () {
                      setState(() => _selectedCustomer = null);
                      setSheetState(() {});
                    },
                    taxConfig: _taxConfig,
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _brandNavy,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              children: [
                // ── Left: label + amount ──────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT TICKET',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: '$tItems Items  ',
                              style: const TextStyle(fontSize: 12),
                            ),
                            TextSpan(
                              text:
                                  'K${NumberFormat('#,##0.00').format(payTotal)}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Right: button ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Ticket &\nCharge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  bool _isCharging = false;
  bool _isSaving = false;

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
          content: Text('Cannot load open tickets: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No open ticket to move from.'),
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
        const SnackBar(
          content: Text(
            'No destination available. Open another ticket or free a table.',
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
                          const Expanded(
                            child: Text(
                              'Move Ticket',
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
                      const Text(
                        'Select source ticket',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: sourceTicketId,
                        isExpanded: true,
                        items: tickets.map((t) {
                          final tableLabel = (t.tableName ?? '').trim().isNotEmpty
                              ? (t.tableName ?? '').trim()
                              : (t.tableId != null ? 'Table ${t.tableId}' : 'No table');
                          return DropdownMenuItem<int>(
                            value: t.id,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tableLabel,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${t.name} • ${t.lines.length} items',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
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
                      const Text(
                        'Move destination',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'ticket',
                            label: Text('Open ticket'),
                          ),
                          ButtonSegment<String>(
                            value: 'table',
                            label: Text('Empty table'),
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
                          initialValue: destinationTicketId,
                          isExpanded: true,
                          items: destinationOptions.map((t) {
                            final tableLabel = (t.tableName ?? '').trim().isNotEmpty
                                ? (t.tableName ?? '').trim()
                                : (t.tableId != null ? 'Table ${t.tableId}' : 'No table');
                            return DropdownMenuItem<int>(
                              value: t.id,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tableLabel,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${t.name} • ${t.lines.length} items',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
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
                          'Source total: ₭${sourceTicket.amountTotal.toStringAsFixed(2)}\nItems: ${sourceTicket.lines.length}',
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
                              child: const Text('Cancel'),
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
                                      setDialogState(
                                        () => isSubmitting = false,
                                      );
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
                                  : const Text('Move Now'),
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
            content: Text('Move ticket failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  void _showCustomerSelection(BuildContext context) async {
    // Show loading state while fetching customers before opening modal (or inside)
    final rootContext = context; // capture valid context unconditionally

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        List<dynamic> allCustomers = [];
        bool isLoading = true;

        // Helper to load
        void loadData(StateSetter setSheetState) async {
          try {
            final data = await _apiService.fetchCustomers();
            setSheetState(() {
              allCustomers = data;
              isLoading = false;
            });
          } catch (e) {
            setSheetState(() => isLoading = false);
          }
        }

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (isLoading && allCustomers.isEmpty) {
              loadData(setSheetState);
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final filteredCustomers = allCustomers.where((c) {
              final name = (c['name']?.toString() ?? '').toLowerCase();
              final phone = (c['phone']?.toString() ?? '').toLowerCase();
              final q = searchQuery.toLowerCase();
              return name.contains(q) || phone.contains(q);
            }).toList();

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: LaDolcePosUi.modalBottomPadding(context),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Customer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('New'),
                          onPressed: () {
                            _showCreateCustomerDialog(ctx, () {
                              setSheetState(() => isLoading = true);
                              loadData(setSheetState);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? const Center(child: Text('No customers found.'))
                          : ListView.separated(
                              itemCount: filteredCustomers.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, index) {
                                final c = filteredCustomers[index];
                                final String cName = c['name'] is String
                                    ? c['name']
                                    : (c['name']?.toString() ?? '');
                                final String cPhone = c['phone'] is String
                                    ? c['phone']
                                    : '';
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(
                                    cName.isNotEmpty ? cName : 'Unknown',
                                  ),
                                  subtitle: cPhone.isNotEmpty
                                      ? Text(cPhone)
                                      : null,
                                  onTap: () {
                                    // Capture messenger before popping to fix deactivated widget ancestor exception
                                    final messenger = ScaffoldMessenger.of(
                                      rootContext,
                                    );
                                    setState(() {
                                      _selectedCustomer = c;
                                    });
                                    Navigator.pop(ctx);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Customer $cName selected!',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateCustomerDialog(
    BuildContext sheetCtx,
    VoidCallback onCustomerCreated,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(ctx);
              try {
                await _apiService.saveCustomer(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                navigator.pop(); // Close dialog
                onCustomerCreated(); // Trigger the callback
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChargeDialog(BuildContext context) {
    if (_cartItems.isEmpty) return;

    final bd = _cartTaxBreakdown();
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
      text: total.toStringAsFixed(0),
    );

    final fmt = NumberFormat('#,##0.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isCash =
              _selectedPaymentMethod?.name.toLowerCase().contains('cash') ??
              false;
          final amtReceived =
              double.tryParse(amountReceivedCtrl.text.replaceAll(',', '')) ??
              0.0;
          final changeAmount = amtReceived >= total ? amtReceived - total : 0.0;

          return Padding(
            padding: EdgeInsets.only(
              bottom: LaDolcePosUi.modalBottomPadding(context),
            ),
            child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // X button (left)
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Charge',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Total Card ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: _brandNavy,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'K${fmt.format(total)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Scrollable content ────────────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      children: [
                        // Transfer lock notice
                        if (isTransferTicket)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              _activeTicketPaymentMethodName.isNotEmpty
                                  ? 'Transfer ticket: fixed to $_activeTicketPaymentMethodName.'
                                  : 'Transfer ticket: payment method is fixed.',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        // ── Payment Method Label ──────────────────────────
                        const Text(
                          'Select Payment Method',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Payment Method Pills ──────────────────────────
                        if (_paymentMethods.isEmpty)
                          const Text(
                            'No payment methods configured.',
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          LayoutBuilder(
                            builder: (ctx, constraints) {
                              final locked = isTransferTicket &&
                                  _activeTicketPaymentMethodId != null;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 240,
                                  mainAxisExtent: 88,
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

                                  return InkWell(
                                    onTap: locked
                                        ? null
                                        : () => setSheetState(
                                              () => _selectedPaymentMethod = m,
                                            ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? _brandNavy
                                              : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCashMethod
                                                ? Icons.point_of_sale_rounded
                                                : Icons.credit_card_rounded,
                                            color: isSelected
                                                ? _brandNavy
                                                : Colors.black38,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              m.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? _brandNavy
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ),
                                          if (locked)
                                            const Icon(
                                              Icons.lock_outline_rounded,
                                              size: 16,
                                              color: Colors.black26,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        // ── Cash Input ────────────────────────────────────
                        if (isCash) ...[
                          const Text(
                            'Amount Received',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: Text(
                                    'K ',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: amountReceivedCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 4,
                                      ),
                                    ),
                                    onChanged: (_) => setSheetState(() {}),
                                  ),
                                ),
                                if (amountReceivedCtrl.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel_rounded,
                                      color: Colors.black26,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      amountReceivedCtrl.clear();
                                      setSheetState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Change Due row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Change Due:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  'K${fmt.format(changeAmount)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: changeAmount > 0
                                        ? Colors.green.shade700
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (_isCharging)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),

                  // ── Charge Button ─────────────────────────────────────────
                  if (!_isCharging)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: ElevatedButton(
                        onPressed: () => _processCheckout(
                          context,
                          setSheetState,
                          true,
                          bd,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'CHARGE K${fmt.format(total)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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
    );
  }

  Future<void> _processCheckout(
    BuildContext context,
    StateSetter setDialogState,
    bool printReceipt,
    PosTaxBreakdown bd,
  ) async {
    final subtotalRowLabel = bd.taxActive && _taxConfig.inclusive
        ? 'Amount (excl. VAT):'
        : 'Subtotal:';
    final taxLab = (bd.taxActive && _taxConfig.showOnReceipt)
        ? 'VAT (${_taxConfig.percentLabel}%):'
        : null;
    setDialogState(() => _isCharging = true);

    // Only new (unsaved) lines need to be pushed — saved ones are already on server
    final newLines = _cartItems
        .where((item) => !item.isSaved)
        .map(
          (item) => {
            'product_id': item.product.id,
            'qty': item.quantity,
            'price_unit': _lineUnitPrice(item),
            'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
          },
        )
        .toList();

    // All lines (for offline/new-order path)
    final allLines = _cartItems
        .map(
          (item) => {
            'product_id': item.product.id,
            'qty': item.quantity,
            'price_unit': _lineUnitPrice(item),
            'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
          },
        )
        .toList();

    try {
      final cashierId = widget.cashierId;
      if (_activeTicketPaymentType == 'transfer' &&
          _activeTicketPaymentMethodId != null &&
          _selectedPaymentMethod?.id != _activeTicketPaymentMethodId) {
        final fixedMethod = _paymentMethods
            .where((m) => m.id == _activeTicketPaymentMethodId)
            .firstOrNull;
        if (fixedMethod != null) {
          _selectedPaymentMethod = fixedMethod;
        }
      }

      Map<String, dynamic> result;

      if (_activeTicketId != null) {
        // If this is an OFFLINE mock ticket (negative id), do NOT attempt /pay with the mock id.
        // Instead, move it into Receipt History as "waiting to sync" by queuing a paid submit.
        if (_activeTicketId! < 0) {
          // Remove old queued tasks for this mock ticket (create/update/pay), then queue a single paid submit.
          await _apiService.purgeOfflineTasksForOrder(_activeTicketId!);

          result = await _apiService.submitOrder(
            userId: cashierId,
            partnerId: _selectedCustomer?['id'],
            tableId: _activeTicketTableId,
            paymentMethodId: _selectedPaymentMethod?.id,
            paymentType: _activeTicketPaymentType.isNotEmpty
                ? _activeTicketPaymentType
                : 'pay_at_store',
            isPaid: true,
            lines: allLines,
          );

          // Ticket is now considered "charged" locally; clear the OPEN state immediately.
          await _apiService.clearLocalOpenTicket(
            _activeTicketId!,
            tableId: _activeTicketTableId,
          );

          // Also update in-memory tables list so the selector immediately shows the table as available.
          if (_activeTicketTableId != null) {
            final idx = _tables.indexWhere((t) => t.id == _activeTicketTableId);
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
        } else {
        // Only update if there are new lines to add
        if (newLines.isNotEmpty) {
          await _apiService.updateOrder(
            orderId: _activeTicketId!,
            customerId: _selectedCustomer?['id'],
            lines: newLines,
          );
        }

        // Now mark the same order as paid (no duplicate!)
        result = await _apiService.payOrder(
          orderId: _activeTicketId!,
          paymentMethodId: _selectedPaymentMethod?.id,
        );
        }
      } else {
        // No active ticket — create a new order and pay immediately
        result = await _apiService.submitOrder(
          userId: cashierId,
          partnerId: _selectedCustomer?['id'],
          isPaid: true,
          paymentMethodId: _selectedPaymentMethod?.id,
          lines: allLines,
        );
      }

      final bool isOffline = result['offline'] == true;

      if (context.mounted) {
        if (isOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚡ Network unavailable. Order saved offline and will auto-sync later!',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${result['order_reference']} Paid Successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (printReceipt && printerService.isConfigured) {
        Map<String, dynamic>? tpl;
        try {
          tpl = await _apiService.fetchBillTemplate(type: 'receipt');
        } catch (_) {}
        final headerText = (tpl?['header_text'] ?? '').toString();
        final footerText = (tpl?['footer_text'] ?? '').toString();
        // Receipt/bill printers only — order tickets were already sent on save.
        // Printers with printReceiptsAndBills=true get the customer receipt.
        // Order printers (printOrders=true) are intentionally skipped here to
        // avoid double-printing items the kitchen already received on save.
        final receiptPrinters = printerService.profiles
            .where((p) => p.printReceiptsAndBills)
            .toList();
        bool anyOk =
            receiptPrinters.isEmpty; // consider success if no receipt printer
        for (final p in receiptPrinters) {
          final ok = await printerService.printReceiptToProfile(
            p,
            cartItems: _cartItems,
            subtotal: bd.baseAmount,
            tax: bd.taxAmount,
            total: bd.totalDue,
            cashierName: widget.cashierName,
            subtotalRowLabel: subtotalRowLabel,
            taxRowLabel: taxLab,
            headerText: headerText,
            footerText: footerText,
          );
          if (ok) anyOk = true;
        }
        if (context.mounted && !anyOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printer error'),
              backgroundColor: Colors.red,
            ),
          );
        }
        final isCash =
            _selectedPaymentMethod?.name.toLowerCase().contains('cash') ??
            false;
        if (isCash) {
          await printerService.openCashDrawer();
        }
      }
      // Auto-open cash drawer on cash payments

      _clearCart();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setDialogState(() => _isCharging = false);
    }
  }

  /// Save current cart to existing ticket (update) or new ticket (table dialog)
  Future<void> _saveCurrentTicket(BuildContext context) async {
    if (_cartItems.isEmpty || _isSaving) return; // guard against double-tap

    if (_activeTicketId != null) {
      // Only send the NEW (unsaved) items — saved items are already on the server
      final newLines = _cartItems
          .where((item) => !item.isSaved)
          .map(
            (item) => {
              'product_id': item.product.id,
              'qty': item.quantity,
              'price_unit': _lineUnitPrice(item),
              'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
            },
          )
          .toList();

      // If there are no new items, nothing to update — just go back
      if (newLines.isEmpty) {
        _clearCart();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket saved (no new items added).'),
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
          lines: newLines,
        );

        // Print only the unprinted new items to kitchen/bar printers
        if (unprintedNewItems.isNotEmpty && printerService.isConfigured) {
          final printedCount = await _printOrderItemsToKitchen(
            unprintedNewItems,
            respectCategoryFilters: true,
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
        _showTableSelectionDialog(context);
      }
    }
  }

  bool _isOpeningTicket = false;

  void _showTableSelectionDialog(BuildContext context) {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: !_isOpeningTicket,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Open Ticket / Select Table'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _tables.isEmpty
                ? const Center(
                    child: Text('No tables available.\nPlease sync catalog.'),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          childAspectRatio: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _tables.length,
                    itemBuilder: (context, index) {
                      final table = _tables[index];
                      final isAvailable =
                          table.status == 'available' ||
                          table.status == 'empty';
                      final hasOpenOrder = table.hasOpenOrder;

                      // Three visual states:
                      // Green  = available, no order
                      // Orange = has an open draft order (tap to add to it)
                      // Red    = occupied / unavailable (non-tappable)
                      final Color cardColor;
                      final Color borderColor;
                      final Color iconColor;
                      final IconData tableIcon;
                      final String? badgeLabel;

                      if (!isAvailable) {
                        cardColor = Colors.red[50]!;
                        borderColor = Colors.red[400]!;
                        iconColor = Colors.red[700]!;
                        tableIcon = Icons.block;
                        badgeLabel = null;
                      } else if (hasOpenOrder) {
                        cardColor = Colors.orange[50]!;
                        borderColor = Colors.orange[400]!;
                        iconColor = Colors.orange[800]!;
                        tableIcon = Icons.receipt_long;
                        badgeLabel = 'OPEN';
                      } else {
                        cardColor = Colors.green[50]!;
                        borderColor = Colors.green[400]!;
                        iconColor = Colors.green[700]!;
                        tableIcon = Icons.table_bar;
                        badgeLabel = null;
                      }

                      return InkWell(
                        // IMPORTANT: Tables with an OPEN ticket are intentionally NOT selectable
                        // from this dialog. Combining tickets is handled only via "Move ticket".
                        onTap: (!isAvailable || hasOpenOrder || _isOpeningTicket)
                            ? null
                            : () => _processOpenTicket(
                                  context,
                                  setDialogState,
                                  table,
                                ),
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          color: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderColor, width: 2),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(tableIcon, color: iconColor, size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      table.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        Text(
                                          '${table.capacity}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Badge for open order
                              if (badgeLabel != null)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
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
          actions: [
            if (_isOpeningTicket)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: CircularProgressIndicator(),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _processOpenTicket(
    BuildContext context,
    StateSetter setDialogState,
    PosTable table,
  ) async {
    setDialogState(() => _isOpeningTicket = true);

    final lines = _cartItems
        .map(
          (item) => {
            'product_id': item.product.id,
            'qty': item.quantity,
            'price_unit': _lineUnitPrice(item),
            if (item.selectedToppings.isNotEmpty)
              'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
          },
        )
        .toList();

    try {
      final cashierId = (widget as dynamic).cashierId ?? 1;

      // IMPORTANT: This flow only creates a NEW draft ticket for an EMPTY table.
      // For combining / moving into other OPEN tickets, use "Move ticket".
      final result = await _apiService.createOrder(
        userId: cashierId,
        tableId: table.id,
        customerId: _selectedCustomer?['id'],
        lines: lines,
      );

      final int? orderId =
          (result['order_id'] is int) ? result['order_id'] as int : null;
      final bool isOffline = (orderId != null && orderId < 0) ||
          (result['order_reference']?.toString().startsWith('OFFLINE') == true);

      if (context.mounted) {
        if (isOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚡ Network unavailable. Ticket for ${table.name} saved offline!',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ticket opened at ${table.name}!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Update local table state immediately so the selector shows OPEN next time
      // even before the next network refresh.
      try {
        final idx = _tables.indexWhere((t) => t.id == table.id);
        if (idx >= 0) {
          final current = _tables[idx];
          _tables[idx] = PosTable(
            id: current.id,
            name: current.name,
            capacity: current.capacity,
            status: current.status,
            hasOpenOrder: true,
          );
        }
      } catch (_) {
        // no-op
      }

      // Print to kitchen/bar printers and mark items as printed only on success
      if (printerService.isConfigured) {
        final printedCount = await _printOrderItemsToKitchen(
          _cartItems,
          respectCategoryFilters: true,
        );
        if (printedCount > 0) {
          // Mark all items as printed so charge / subsequent saves don't re-print
          for (final item in _cartItems) {
            item.isPrinted = true;
          }
        }
      }

      _clearCart();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setDialogState(() => _isOpeningTicket = false);
    }
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'App Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.print, color: _brandNavy),
              title: const Text('Printer Configuration'),
              subtitle: Text(
                printerService.profiles.isNotEmpty
                    ? '${printerService.profiles.length} printer(s) configured'
                    : (printerService.isConfigured
                          ? 'Connected: ${printerService.printerIp}'
                          : 'Not configured'),
                style: TextStyle(
                  color: printerService.isConfigured
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: _brandNavy),
              title: const Text('Bill Templates'),
              subtitle: const Text('Select bill/receipt/refund templates for this branch'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BillTemplateSettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync, color: _brandNavy),
              title: const Text('Sync All Data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                await _syncAllDataAndRefresh();
              },
            ),
            SizedBox(
              height: 8 + LaDolcePosUi.gestureBarBottomPad(context),
            ),
          ],
        ),
      ),
    );
  }
}
