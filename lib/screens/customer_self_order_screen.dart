import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/combo.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class CustomerSelfOrderScreen extends StatefulWidget {
  final String customerName;
  final int userId;
  final int? partnerId;

  const CustomerSelfOrderScreen({
    Key? key,
    required this.customerName,
    required this.userId,
    this.partnerId,
  }) : super(key: key);

  @override
  State<CustomerSelfOrderScreen> createState() => _CustomerSelfOrderScreenState();
}

class _CustomerSelfOrderScreenState extends State<CustomerSelfOrderScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Brand palette (based on bear logo)
  static const _brandNavy = Color(0xFF0D1565);
  static const _brandNavy2 = Color(0xFF142B8C);
  static const _brandSurface = Colors.white;
  static const _brandCard = Colors.white;
  static const _brandDivider = Color(0xFFE6E8F2);
  static const _brandAccent = Color(0xFF3B82F6);
  static const _brandGold = Color(0xFFC6A15B);

  bool _isLoadingCatalog = true;
  bool _isLoadingProfile = true;
  bool _isLoadingHistory = true;
  bool _isPlacingOrder = false;
  bool _isSavingProfile = false;
  bool _isLoggingOut = false;
  bool _isLoadingSelfOrderConfig = true;

  String _searchQuery = '';
  String _selectedCategory = 'All Items';
  String? _catalogError;
  int _selectedTabIndex = 0;

  List<Product> _products = [];
  List<Category> _categories = [Category(id: 'All', name: 'All Items')];
  final List<CartItem> _cartItems = [];

  Product? _previewProduct;
  int _previewQty = 1;
  List<Topping> _previewToppings = [];

  int? _customerId;
  String _customerName = '';
  String _customerPhone = '';
  String _customerEmail = '';
  int _rewardPoints = 0;
  String? _customerImageBase64;
  String _qrImageDataUrl = '';
  String _bankName = '';
  String _accountName = '';
  String _accountNumber = '';
  String? _profileImagePath;

  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _customerName = widget.customerName;
    _loadCatalog();
    _loadProfile();
    _loadHistory();
    _loadSelfOrderConfig();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _profileImagePrefsKey => 'customer_profile_image_path_${widget.partnerId ?? widget.userId}';

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_profileImagePrefsKey);
    if (!mounted) return;
    setState(() => _profileImagePath = (path != null && path.isNotEmpty) ? path : null);
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileImagePrefsKey, picked.path);
      if (!mounted) return;
      setState(() => _profileImagePath = picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot pick image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  MemoryImage? _customerMemoryImage() {
    final raw = _customerImageBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoadingCatalog = true;
      _catalogError = null;
    });

    try {
      final products = await _apiService.fetchProducts(limit: 200);
      final rawCombos = await _apiService.fetchCombos();
      final combos = rawCombos.map((c) => Product.fromCombo(Combo.fromJson(c))).toList();
      products.addAll(combos);

      final categorySet = products.map((p) => p.category).toSet();
      final categories = [Category(id: 'All', name: 'All Items')]
        ..addAll(categorySet.map((name) => Category(id: name, name: name)));

      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = categories;
        _isLoadingCatalog = false;
        _previewProduct ??= products.isNotEmpty ? products.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogError = e.toString();
        _isLoadingCatalog = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final customers = await _apiService.fetchCustomers();
      Map<String, dynamic>? matched;

      if (widget.partnerId != null) {
        for (final c in customers) {
          if (c is Map<String, dynamic> && c['id'] == widget.partnerId) {
            matched = c;
            break;
          }
        }
      }

      matched ??= {
        'id': widget.partnerId,
        'name': widget.customerName,
        'phone': '',
        'email': '',
        'reward_points': 0,
      };

      if (!mounted) return;
      setState(() {
        _customerId = matched?['id'] as int?;
        _customerName = (matched?['name'] ?? widget.customerName).toString();
        _customerPhone = (matched?['phone'] ?? '').toString();
        _customerEmail = (matched?['email'] ?? '').toString();
        _rewardPoints = int.tryParse((matched?['reward_points'] ?? 0).toString()) ?? 0;
        _customerImageBase64 = matched?['image_base64']?.toString();
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final List<Map<String, dynamic>> serverHistory;
      if (widget.partnerId != null) {
        serverHistory = await _apiService.fetchCustomerOrders(widget.partnerId!);
      } else {
        serverHistory = await _apiService.fetchReceiptHistory();
      }
      final localHistory = await _getLocalSelfOrderHistory();

      final List<Map<String, dynamic>> normalizedServer = serverHistory.map((item) {
        return {
          'source': 'server',
          'id': item['id'],
          'name': item['name'] ?? 'Order',
          'amount_total': item['amount_total'] ?? 0,
          'date_order': item['date_order'],
          'payment_method': item['payment_method'] ?? 'Unknown',
          'state': item['state'] ?? 'paid',
          'customer': item['customer'] ?? '',
          'transfer_proof_url': item['transfer_proof_url'],
          'lines': item['lines'] ?? const [],
        };
      }).toList();

      // If partner_id is specified, server already scoped orders by that customer.
      final filteredServer = widget.partnerId != null
          ? normalizedServer
          : normalizedServer.where((item) {
              final c = (item['customer'] ?? '').toString().trim().toLowerCase();
              final mine = _customerName.trim().toLowerCase();
              if (mine.isEmpty) return true;
              return c == mine;
            }).toList();

      // Prefer server records over local placeholders when they refer to same order.
      final byKey = <String, Map<String, dynamic>>{};
      for (final item in localHistory) {
        final idKey = item['id']?.toString() ?? '';
        final nameKey = (item['name'] ?? '').toString();
        final key = idKey.isNotEmpty && idKey != '0' ? 'id:$idKey' : 'name:$nameKey';
        byKey[key] = Map<String, dynamic>.from(item);
      }
      for (final item in filteredServer) {
        final idKey = item['id']?.toString() ?? '';
        final nameKey = (item['name'] ?? '').toString();
        final key = idKey.isNotEmpty && idKey != '0' ? 'id:$idKey' : 'name:$nameKey';
        byKey[key] = Map<String, dynamic>.from(item);
      }

      final all = byKey.values.toList();
      all.sort((a, b) {
        final aDate = DateTime.tryParse((a['date_order'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse((b['date_order'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _historyItems = all;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadSelfOrderConfig() async {
    setState(() => _isLoadingSelfOrderConfig = true);
    try {
      final config = await _apiService.fetchSelfOrderConfig();
      if (!mounted) return;
      setState(() {
        _qrImageDataUrl = (config['qr_image_data_url'] ?? '').toString();
        _bankName = (config['bank_name'] ?? '').toString();
        _accountName = (config['account_name'] ?? '').toString();
        _accountNumber = (config['account_number'] ?? '').toString();
        _isLoadingSelfOrderConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSelfOrderConfig = false);
    }
  }

  Uint8List? _qrBytesFromDataUrl() {
    if (_qrImageDataUrl.isEmpty || !_qrImageDataUrl.startsWith('data:image')) return null;
    final comma = _qrImageDataUrl.indexOf(',');
    if (comma < 0) return null;
    final b64 = _qrImageDataUrl.substring(comma + 1);
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadQrCode() async {
    try {
      final Uint8List? bytes = _qrBytesFromDataUrl();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR image configured yet'), backgroundColor: Colors.orange),
        );
        return;
      }

      if (Platform.isIOS) {
        final status = await Permission.photosAddOnly.request();
        if (!status.isGranted && !status.isLimited) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo permission is required to save QR')),
          );
          return;
        }
      } else if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        if (!status.isGranted && !status.isLimited) {
          final storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission is required to save QR')),
            );
            return;
          }
        }
      }

      final filename = 'la_dolce_qr_${DateTime.now().millisecondsSinceEpoch}';
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: filename,
      );
      final success = (result['isSuccess'] == true) || (result['filePath'] != null);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR saved to gallery'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save QR: ${result['errorMessage'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download QR: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getLocalSelfOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList('customer_self_order_history') ?? [];
    return items
        .map((e) => jsonDecode(e))
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _appendLocalHistory(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList('customer_self_order_history') ?? [];
    items.insert(0, jsonEncode(entry));
    await prefs.setStringList('customer_self_order_history', items.take(100).toList());
  }

  List<Product> get _filteredProducts {
    var result = _products;

    if (_selectedCategory != 'All Items') {
      result = result.where((p) => p.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) || p.category.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  int get _cartCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get _cartTotal => _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  double _previewTotal(Product product, int qty, List<Topping> toppings) {
    final extra = toppings.fold<double>(0.0, (sum, t) => sum + t.extraPrice);
    return (product.price + extra) * qty;
  }

  void _setPreviewProduct(Product product) {
    setState(() {
      _previewProduct = product;
      _previewQty = 1;
      _previewToppings = [];
    });
  }

  void _addToCart(
    Product product, {
    int quantity = 1,
    List<Topping> selectedToppings = const [],
  }) {
    final selectedIds = selectedToppings.map((t) => t.id).toSet();
    final index = _cartItems.indexWhere((item) {
      if (item.product.id != product.id) return false;
      if (item.selectedToppings.length != selectedToppings.length) return false;
      final itemIds = item.selectedToppings.map((t) => t.id).toSet();
      return selectedIds.containsAll(itemIds) && itemIds.containsAll(selectedIds);
    });
    setState(() {
      if (index >= 0) {
        _cartItems[index].quantity += quantity;
      } else {
        _cartItems.add(
          CartItem(
            product: product,
            quantity: quantity,
            selectedToppings: selectedToppings,
          ),
        );
      }
    });
  }

  void _updateQuantity(CartItem item, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cartItems.remove(item);
      } else {
        item.quantity = quantity;
      }
    });
  }

  void _showCheckoutOptions() {
    if (_cartItems.isEmpty || _isPlacingOrder) return;

    String paymentChoice = 'pay_at_store';
    XFile? proofImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.90,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Payment Method',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    RadioListTile<String>(
                      value: 'pay_at_store',
                      groupValue: paymentChoice,
                      onChanged: (val) => setSheetState(() => paymentChoice = val!),
                      title: const Text('Pay at the store'),
                      subtitle: const Text('Order now, pay when you arrive'),
                    ),
                    RadioListTile<String>(
                      value: 'transfer',
                      groupValue: paymentChoice,
                      onChanged: (val) => setSheetState(() => paymentChoice = val!),
                      title: const Text('Bank transfer'),
                      subtitle: const Text('Upload transfer proof after payment'),
                    ),
                    if (paymentChoice == 'transfer') ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _isLoadingSelfOrderConfig
                              ? const Center(child: CircularProgressIndicator())
                              : (_qrBytesFromDataUrl() != null
                                  ? Image.memory(_qrBytesFromDataUrl()!, fit: BoxFit.contain)
                                  : const Center(
                                      child: Text(
                                        'QR not configured in Odoo Settings',
                                        textAlign: TextAlign.center,
                                      ),
                                    )),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Account: ${_accountName.isEmpty ? 'La Dolce' : _accountName}'
                          '\nBank: ${_bankName.isEmpty ? '-' : _bankName}'
                          '\nNo: ${_accountNumber.isEmpty ? '-' : _accountNumber}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _downloadQrCode,
                          icon: const Icon(Icons.download),
                          label: const Text('Download QR'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                            if (picked != null) {
                              setSheetState(() => proofImage = picked);
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: Text(proofImage == null ? 'Upload Transfer Proof' : 'Proof Selected'),
                        ),
                      ),
                      if (proofImage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Text(
                            'Transfer proof selected. It will be uploaded when you confirm order.',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPlacingOrder
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _placeOrder(
                                  paymentChoice: paymentChoice,
                                  proofImagePath: proofImage?.path,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Confirm Order (₭${_cartTotal.toStringAsFixed(2)})'),
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

  Future<void> _placeOrder({
    required String paymentChoice,
    String? proofImagePath,
  }) async {
    if (_cartItems.isEmpty || _isPlacingOrder) return;

    setState(() => _isPlacingOrder = true);
    try {
      final lines = _cartItems
          .map((item) => {
                'product_id': item.product.id,
                'qty': item.quantity,
                'price_unit': item.product.price,
                'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
              })
          .toList();

      final result = await _apiService.submitOrder(
        userId: widget.userId,
        partnerId: widget.partnerId,
        paymentType: paymentChoice,
        isPaid: false,
        lines: lines,
      );

      String? uploadedProofUrl;
      final orderId = int.tryParse((result['order_id'] ?? 0).toString()) ?? 0;
      if (paymentChoice == 'transfer' && proofImagePath != null && proofImagePath.isNotEmpty && orderId > 0) {
        try {
          final uploadResult = await _apiService.uploadTransferProof(
            orderId: orderId,
            imagePath: proofImagePath,
            partnerId: widget.partnerId,
          );
          uploadedProofUrl = uploadResult['transfer_proof_url']?.toString();
        } catch (_) {
          // Keep order created even if proof upload fails.
        }
      }

      final nowIso = DateTime.now().toIso8601String();
      final localEntry = {
        'source': 'local',
        'id': result['order_id'] ?? 0,
        'name': result['order_reference'] ?? 'Order',
        'amount_total': _cartTotal,
        'date_order': nowIso,
        'payment_method': paymentChoice == 'transfer' ? 'Transfer' : 'Pay At Store',
        'state': paymentChoice == 'transfer' ? 'waiting transfer verification' : 'waiting payment at store',
        'customer': _customerName,
        'proof_image_path': proofImagePath,
        'transfer_proof_url': uploadedProofUrl,
        'lines': lines.map((e) {
          final p = _products.where((x) => x.id == e['product_id']).firstOrNull;
          final qty = (e['qty'] ?? 0);
          final price = (e['price_unit'] ?? 0.0);
          final subtotal = (qty is num ? qty.toDouble() : 0.0) * (price is num ? price.toDouble() : 0.0);
          return {
            'product_name': p?.name ?? 'Item',
            'qty': qty,
            'price_unit': price,
            'subtotal': subtotal,
          };
        }).toList(),
      };
      await _appendLocalHistory(localEntry);

      if (!mounted) return;
      setState(() {
        _cartItems.clear();
        _selectedTabIndex = 2; // History tab (Home=0, Cart=1, History=2, Profile=3)
      });
      await _loadHistory();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentChoice == 'transfer'
                ? (uploadedProofUrl != null
                    ? 'Order created. Transfer proof uploaded.'
                    : 'Order created. Transfer proof saved locally.')
                : 'Order created. Please pay at the store.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile || _customerName.trim().isEmpty) return;
    setState(() => _isSavingProfile = true);
    try {
      final saved = await _apiService.saveCustomer(
        id: _customerId,
        name: _customerName.trim(),
        phone: _customerPhone.trim(),
        email: _customerEmail.trim().isEmpty ? null : _customerEmail.trim(),
      );

      if (!mounted) return;
      setState(() {
        _customerId = saved['id'] as int?;
        _customerName = (saved['name'] ?? _customerName).toString();
        _customerPhone = (saved['phone'] ?? _customerPhone).toString();
        _customerEmail = (saved['email'] ?? _customerEmail).toString();
        _rewardPoints = int.tryParse((saved['reward_points'] ?? _rewardPoints).toString()) ?? _rewardPoints;
      });

      await _loadHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot save profile: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    await _apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openPaymentInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Payment / QR',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _brandNavy),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Bank transfer details', style: TextStyle(fontWeight: FontWeight.w800, color: _brandNavy)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _brandDivider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account name: ${_accountName.isEmpty ? '-' : _accountName}'),
                      Text('Bank: ${_bankName.isEmpty ? '-' : _bankName}'),
                      Text('Account no: ${_accountNumber.isEmpty ? '-' : _accountNumber}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('QR code', style: TextStyle(fontWeight: FontWeight.w800, color: _brandNavy)),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _brandDivider),
                      ),
                      child: _isLoadingSelfOrderConfig
                          ? const Center(child: CircularProgressIndicator())
                          : (_qrBytesFromDataUrl() != null
                              ? Image.memory(_qrBytesFromDataUrl()!, fit: BoxFit.contain)
                              : const Center(child: Text('QR not configured'))),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _downloadQrCode,
                    icon: const Icon(Icons.download),
                    label: const Text('Download QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandNavy,
                      side: const BorderSide(color: _brandDivider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditProfileSheet() {
    String name = _customerName;
    String phone = _customerPhone;
    String email = _customerEmail;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Material(
                color: const Color(0xFFF6F7FB),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Edit profile',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _brandNavy),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _profileField(
                        label: 'Full name',
                        initialValue: name,
                        onChanged: (v) => setSheetState(() => name = v),
                      ),
                      const SizedBox(height: 12),
                      _profileField(
                        label: 'Phone',
                        initialValue: phone,
                        keyboardType: TextInputType.phone,
                        onChanged: (v) => setSheetState(() => phone = v),
                      ),
                      const SizedBox(height: 12),
                      _profileField(
                        label: 'Email',
                        initialValue: email,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) => setSheetState(() => email = v),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSavingProfile
                              ? null
                              : () async {
                                  _customerName = name;
                                  _customerPhone = phone;
                                  _customerEmail = email;
                                  Navigator.pop(ctx);
                                  await _saveProfile();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isSavingProfile
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _profileField({
    required String label,
    required String initialValue,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF2F4FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DAE6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandAccent, width: 1.4),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _profileRow({
    required IconData icon,
    required String title,
    String? badgeText,
    IconData trailing = Icons.chevron_right,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCE5FF)),
              ),
              child: Icon(icon, color: _brandNavy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _brandNavy)),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badgeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
            ],
            Icon(trailing, color: const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _brandNavy, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _openProductDetail(Product product) {
    int qty = 1;
    List<Topping> selectedToppings = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.84,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildProductImage(product),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(product.category, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('₭${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _brandNavy)),
                    if (product.toppings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Add toppings? (Optional)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.toppings.map((topping) {
                          final selected = selectedToppings.any((t) => t.id == topping.id);
                          return FilterChip(
                            selected: selected,
                            label: Text(
                              topping.extraPrice > 0
                                  ? '${topping.name} (+₭${topping.extraPrice.toStringAsFixed(2)})'
                                  : '${topping.name} (Free)',
                            ),
                            onSelected: (value) {
                              setSheetState(() {
                                if (value) {
                                  selectedToppings.add(topping);
                                } else {
                                  selectedToppings.removeWhere((t) => t.id == topping.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setSheetState(() => qty = qty > 1 ? qty - 1 : 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        IconButton(
                          onPressed: () => setSheetState(() => qty++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 180,
                          child: ElevatedButton(
                            onPressed: () {
                              _addToCart(
                                product,
                                quantity: qty,
                                selectedToppings: selectedToppings,
                              );
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandNavy,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              'Add ₭${((product.price + selectedToppings.fold(0.0, (sum, t) => sum + t.extraPrice)) * qty).toStringAsFixed(2)}',
                            ),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: _brandSurface,
      appBar: AppBar(
        backgroundColor: _brandNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'LaDolce',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoadingCatalog ? null : _loadCatalog,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Navy base + faded luxury pattern (no asset needed)
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_brandNavy, _brandNavy2],
                ),
              ),
              child: const CustomPaint(
                painter: _LuxuryPatternPainter(),
              ),
            ),
          ),
          // Foreground surface
          Positioned.fill(
            top: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _brandSurface,
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
                      ],
                    ),
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _buildHomeTab(isWide: isWide),
                        _buildCartTab(),
                        _buildHistoryTab(),
                        _buildProfileTab(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _selectedTabIndex == 0 ? _buildStickyCartBar() : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) => setState(() => _selectedTabIndex = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              child: const Icon(Icons.shopping_bag),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history_toggle_off),
            label: 'History',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab({required bool isWide}) {
    if (_isLoadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_catalogError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 46),
            const SizedBox(height: 12),
            Text(_catalogError ?? 'Error loading products'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadCatalog, child: const Text('Retry')),
          ],
        ),
      );
    }

    final items = _filteredProducts;
    final grid = items.isEmpty
        ? const Center(child: Text('No items found'))
        : GridView.builder(
            padding: EdgeInsets.fromLTRB(12, 12, 12, isWide ? 12 : 92),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : 2,
              // Slightly smaller cards to let patterned background breathe.
              childAspectRatio: isWide ? 1.02 : 0.90,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) => _buildProductCard(items[index], isWide: isWide),
          );

    return Column(
      children: [
        _buildTopControls(),
        Expanded(
          child: isWide
              ? Row(
                  children: [
                    Expanded(child: grid),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 360,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                        child: _buildCurrentCartPanel(),
                      ),
                    ),
                  ],
                )
              : grid,
        ),
      ],
    );
  }

  Widget _buildTopControls() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brandCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _brandDivider),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [_brandNavy, _brandNavy2]),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Order ahead, pick up fast.',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _brandNavy),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFDCE5FF)),
                  ),
                  child: Text(
                    'Points: $_rewardPoints',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _brandNavy),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search desserts, drinks...',
              prefixIcon: const Icon(Icons.search, color: _brandNavy),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: _brandCard,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _brandDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _brandAccent, width: 1.4),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final selected = category.name == _selectedCategory;
              return ChoiceChip(
                label: Text(category.name),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = category.name),
                selectedColor: _brandNavy,
                backgroundColor: _brandCard,
                shape: StadiumBorder(side: BorderSide(color: selected ? _brandNavy : _brandDivider)),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _brandNavy,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, {required bool isWide}) {
    return InkWell(
      onTap: () => isWide ? _setPreviewProduct(product) : _openProductDetail(product),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _brandCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _brandDivider),
          boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildProductImage(product),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _brandNavy, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₭${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _brandNavy,
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F5FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCE5FF)),
                        ),
                        child: const Icon(Icons.add, color: _brandNavy, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imageBase64 != null && product.imageBase64!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(product.imageBase64!),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _fallbackImage(),
        );
      } catch (_) {
        // fall through to network/fallback
      }
    }
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Container(
      color: const Color(0xFFF2F5FF),
      alignment: Alignment.center,
      child: const Icon(Icons.cake_outlined, color: _brandNavy, size: 38),
    );
  }

  Widget _buildStickyCartBar() {
    final disabled = _cartCount == 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: InkWell(
          onTap: disabled ? null : () => setState(() => _selectedTabIndex = 1),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: disabled ? 0.65 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [_brandNavy2, _brandNavy]),
                boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'View Cart',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  Text(
                    '$_cartCount items',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 18, color: Colors.white24),
                  const SizedBox(width: 10),
                  Text(
                    '₭${_cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentCartPanel() {
    final product = _previewProduct;
    return Container(
      decoration: BoxDecoration(
        color: _brandCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandDivider),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Current Cart',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _brandNavy),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFFE5B8)),
                  ),
                  child: const Text(
                    'LaDolce',
                    style: TextStyle(fontWeight: FontWeight.w900, color: _brandGold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (product == null)
              const Expanded(
                child: Center(
                  child: Text(
                    'Tap an item to preview\nthen add to cart.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: _buildProductImage(product),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _brandNavy),
              ),
              const SizedBox(height: 4),
              Text(
                _previewToppings.isEmpty ? 'No Toppings' : _previewToppings.map((t) => t.name).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _QtyStepper(
                    qty: _previewQty,
                    onChanged: (newQty) => setState(() => _previewQty = newQty),
                    color: _brandNavy,
                  ),
                  const Spacer(),
                  Text(
                    '₭${_previewTotal(product, _previewQty, _previewToppings).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _brandNavy),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: product.toppings.isEmpty ? null : () => _openToppingsPickerForPreview(product),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandNavy,
                    side: const BorderSide(color: _brandDivider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(product.toppings.isEmpty ? 'No toppings for this item' : 'Select Toppings'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _addToCart(product, quantity: _previewQty, selectedToppings: _previewToppings);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} added to cart'),
                        backgroundColor: _brandNavy,
                        duration: const Duration(milliseconds: 900),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: _brandDivider),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Cart total', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    '₭${_cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _brandNavy),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openToppingsPickerForPreview(Product product) {
    if (product.toppings.isEmpty) return;
    final temp = List<Topping>.from(_previewToppings);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.72,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Toppings for ${product.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _brandNavy),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Optional',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: product.toppings.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: _brandDivider),
                        itemBuilder: (context, index) {
                          final topping = product.toppings[index];
                          final selected = temp.any((t) => t.id == topping.id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  temp.add(topping);
                                } else {
                                  temp.removeWhere((t) => t.id == topping.id);
                                }
                              });
                            },
                            activeColor: _brandNavy,
                            title: Text(topping.name, style: const TextStyle(fontWeight: FontWeight.w800, color: _brandNavy)),
                            subtitle: Text(
                              topping.extraPrice > 0 ? '+₭${topping.extraPrice.toStringAsFixed(2)}' : 'Free',
                              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _previewToppings = List<Topping>.from(temp));
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _buildCartTab() {
    if (_cartItems.isEmpty) {
      return const Center(
        child: Text(
          'Your cart is empty.\nAdd items from Home.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _cartItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return ListTile(
                title: Text(item.product.name),
                subtitle: Text(
                  item.selectedToppings.isEmpty
                      ? '₭${item.product.price.toStringAsFixed(2)} each'
                      : '₭${item.product.price.toStringAsFixed(2)} each\nToppings: ${item.selectedToppings.map((t) => t.name).join(', ')}',
                ),
                isThreeLine: item.selectedToppings.isNotEmpty,
                trailing: SizedBox(
                  width: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _updateQuantity(item, item.quantity - 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: () => _updateQuantity(item, item.quantity + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _brandCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _brandDivider),
            boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    '₭${_cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPlacingOrder ? null : _showCheckoutOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Checkout (₭${_cartTotal.toStringAsFixed(2)})'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyItems.isEmpty) {
      return const Center(
        child: Text(
          'No order history yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _historyItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          final date = DateTime.tryParse((item['date_order'] ?? '').toString());
          final proofPath = item['proof_image_path']?.toString();
          final proofUrl = item['transfer_proof_url']?.toString();
          final hasProof = proofPath != null && proofPath.isNotEmpty;
          final hasProofUrl = proofUrl != null && proofUrl.isNotEmpty;
          final statusText = _friendlyStatus(
            (item['state'] ?? '').toString(),
            (item['payment_method'] ?? '').toString(),
          );

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openHistoryDetail(item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['name']?.toString() ?? 'Order',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Text(
                          '₭${double.tryParse((item['amount_total'] ?? 0).toString())?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Payment: ${item['payment_method'] ?? 'Unknown'}'),
                    Text('Status: $statusText'),
                    if (date != null) Text('Date: ${date.toLocal()}'),
                    if (hasProof || hasProofUrl)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Tap to view order details and proof image',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
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

  String _friendlyStatus(String rawState, String paymentMethod) {
    if (rawState == 'waiting_transfer_review') return 'Waiting transfer verification';
    if (rawState == 'draft' && paymentMethod.toLowerCase().contains('transfer')) {
      return 'Transfer verified, preparing order';
    }
    if (rawState == 'draft') return 'Order confirmed';
    if (rawState == 'paid') return 'Paid';
    if (rawState == 'cancelled') return 'Cancelled';
    return rawState.isEmpty ? '-' : rawState;
  }

  void _openHistoryDetail(Map<String, dynamic> item) {
    final proofPath = item['proof_image_path']?.toString() ?? '';
    final proofUrl = item['transfer_proof_url']?.toString() ?? '';
    final hasLocalProof = proofPath.isNotEmpty;
    final hasServerProof = proofUrl.isNotEmpty;
    final lines = ((item['lines'] as List?) ?? const []).cast<dynamic>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? 'Order',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Amount: ₭${double.tryParse((item['amount_total'] ?? 0).toString())?.toStringAsFixed(2) ?? '0.00'}'),
                Text('Payment: ${item['payment_method'] ?? 'Unknown'}'),
                Text('Status: ${_friendlyStatus((item['state'] ?? '').toString(), (item['payment_method'] ?? '').toString())}'),
                const SizedBox(height: 12),
                if (hasLocalProof || hasServerProof) ...[
                  const Text('Transfer Proof', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasLocalProof
                        ? Image.file(
                            File(proofPath),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          )
                        : FutureBuilder<Map<String, String>>(
                            future: _apiService.buildImageHeaders(),
                            builder: (context, snapshot) => Image.network(
                              _apiService.resolveMediaUrl(proofUrl),
                              headers: snapshot.data ?? const {},
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('Order Items', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Expanded(
                  child: lines.isEmpty
                      ? const Center(child: Text('No item details available'))
                      : ListView.separated(
                          itemCount: lines.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final line = lines[index] as Map<dynamic, dynamic>;
                            final qty = double.tryParse((line['qty'] ?? 0).toString()) ?? 0;
                            final subtotal = double.tryParse((line['subtotal'] ?? 0).toString()) ?? 0;
                            return ListTile(
                              title: Text((line['product_name'] ?? 'Item').toString()),
                              subtitle: Text('Qty: ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}'),
                              trailing: Text('₭${subtotal.toStringAsFixed(2)}'),
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
  }

  Widget _buildProfileTab() {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 760;
        final customerMemoryImage = _customerMemoryImage();
        final headerHeight = isCompactHeight ? 172.0 : 188.0;
        final profileShiftY = isCompactHeight ? -52.0 : -62.0;
        final avatarOuterRadius = isCompactHeight ? 78.0 : 93.0;
        final avatarInnerRadius = isCompactHeight ? 72.0 : 86.0;
        final initialsFontSize = isCompactHeight ? 32.0 : 38.0;
        final statusDotSize = isCompactHeight ? 20.0 : 24.0;
        final cameraButtonSize = isCompactHeight ? 40.0 : 46.0;
        final cameraIconSize = isCompactHeight ? 20.0 : 22.0;
        final detailsTopGap = isCompactHeight ? 4.0 : 8.0;
        final logoutBottomPadding = isCompactHeight ? 12.0 : 18.0;

        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: _BottomCurveClipper(),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_brandNavy, _brandNavy2],
                            ),
                          ),
                          child: const CustomPaint(painter: _LuxuryPatternPainter()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, profileShiftY),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: _pickProfileImage,
                            child: CircleAvatar(
                              radius: avatarOuterRadius,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: avatarInnerRadius,
                                backgroundColor: const Color(0xFFF2F5FF),
                                backgroundImage: (_profileImagePath != null && File(_profileImagePath!).existsSync())
                                    ? FileImage(File(_profileImagePath!))
                                    : (customerMemoryImage != null)
                                        ? customerMemoryImage
                                        : null,
                                child: (_profileImagePath == null || !File(_profileImagePath!).existsSync()) &&
                                        (_customerImageBase64 == null || _customerImageBase64!.isEmpty)
                                    ? Text(
                                        _customerName.isEmpty ? 'C' : _customerName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: initialsFontSize,
                                          fontWeight: FontWeight.w900,
                                          color: _brandNavy,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            bottom: 14,
                            child: Container(
                              width: statusDotSize,
                              height: statusDotSize,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: InkWell(
                              onTap: _pickProfileImage,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: cameraButtonSize,
                                height: cameraButtonSize,
                                decoration: BoxDecoration(
                                  color: _brandNavy,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(Icons.camera_alt, color: Colors.white, size: cameraIconSize),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _customerName.isEmpty ? 'Customer' : _customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _brandNavy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _customerEmail.isEmpty ? ' ' : _customerEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F5FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFDCE5FF)),
                        ),
                        child: Text(
                          'Reward points: $_rewardPoints',
                          style: const TextStyle(color: _brandNavy, fontWeight: FontWeight.w800),
                        ),
                      ),
                      SizedBox(height: detailsTopGap),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _brandDivider),
                            boxShadow: const [
                              BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6)),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _detailRow('Full name', _customerName.isEmpty ? '-' : _customerName),
                                _detailRow('Phone', _customerPhone.isEmpty ? '-' : _customerPhone),
                                _detailRow('Email', _customerEmail.isEmpty ? '-' : _customerEmail),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSavingProfile ? null : _openEditProfileSheet,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandNavy,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, logoutBottomPadding),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoggingOut ? null : _logout,
                            icon: const Icon(Icons.logout),
                            label: _isLoggingOut ? const Text('Logging out...') : const Text('Logout'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final Color color;

  const _QtyStepper({
    required this.qty,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: qty <= 1 ? null : () => onChanged(qty - 1),
            icon: Icon(Icons.remove, color: color),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$qty',
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(qty + 1),
            icon: Icon(Icons.add, color: color),
          ),
        ],
      ),
    );
  }
}

class _LuxuryPatternPainter extends CustomPainter {
  const _LuxuryPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle, low-cost repeating flourish pattern.
    // Keep opacity very low so content stays readable.
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fill = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.fill;

    final stepX = size.width / 3.2;
    final stepY = size.height / 4.2;

    for (double y = -stepY; y < size.height + stepY; y += stepY) {
      for (double x = -stepX; x < size.width + stepX; x += stepX) {
        final center = Offset(x + stepX / 2, y + stepY / 2);
        final r = (stepX < stepY ? stepX : stepY) * 0.26;

        // Outer soft medallion
        canvas.drawCircle(center, r * 1.25, fill);
        canvas.drawCircle(center, r * 1.25, paint);

        // Four small petals
        _petal(canvas, center.translate(0, -r * 0.9), r * 0.55, paint);
        _petal(canvas, center.translate(r * 0.9, 0), r * 0.55, paint);
        _petal(canvas, center.translate(0, r * 0.9), r * 0.55, paint);
        _petal(canvas, center.translate(-r * 0.9, 0), r * 0.55, paint);

        // Inner flourish curves
        final path = Path()
          ..moveTo(center.dx - r * 0.9, center.dy)
          ..cubicTo(center.dx - r * 0.35, center.dy - r * 0.65, center.dx + r * 0.35, center.dy - r * 0.65,
              center.dx + r * 0.9, center.dy)
          ..cubicTo(center.dx + r * 0.35, center.dy + r * 0.65, center.dx - r * 0.35, center.dy + r * 0.65,
              center.dx - r * 0.9, center.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  void _petal(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height - 64);
    p.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.55, size.height - 44);
    p.quadraticBezierTo(size.width * 0.85, size.height - 92, size.width, size.height - 54);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
