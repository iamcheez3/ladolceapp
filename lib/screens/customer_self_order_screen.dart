import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:path_provider/path_provider.dart';
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
  State<CustomerSelfOrderScreen> createState() =>
      _CustomerSelfOrderScreenState();
}

class _CustomerSelfOrderScreenState extends State<CustomerSelfOrderScreen> {
  final ApiService _apiService = ApiService();
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

  String _selectedCategory = 'All Items';
  String? _catalogError;
  int _selectedTabIndex = 0;

  List<Product> _products = [];
  List<Category> _categories = [Category(id: 'All', name: 'All Items')];
  final List<CartItem> _cartItems = [];

  List<Map<String, dynamic>> _transferBanks = [];
  int _selectedBankIndex = 0;
  
  bool get _isCartEmpty => _cartItems.isEmpty;
  int get _cartCount {
    if (_cartItems.isEmpty) return 0;
    return _cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  double get _cartTotal {
    if (_cartItems.isEmpty) return 0.0;
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

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
  List<String> _bannerImageDataUrls = [];
  List<String> _adImageDataUrls = [];
  bool _hasShownAdPopup = false;
  String? _profileImagePath;

  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _customerName = widget.customerName;
    _cartItems.clear();
    _loadCatalog();
    _loadProfile();
    _loadHistory();
    _loadSelfOrderConfig();
    _loadProfileImage();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _profileImagePrefsKey =>
      'customer_profile_image_path_${widget.partnerId ?? widget.userId}';
  String get _adSuppressDatePrefsKey =>
      'customer_popup_ad_suppress_date_${widget.partnerId ?? widget.userId}';

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_profileImagePrefsKey);
    if (!mounted) return;
    setState(
      () => _profileImagePath = (path != null && path.isNotEmpty) ? path : null,
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (picked == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileImagePrefsKey, picked.path);
      if (!mounted) return;
      setState(() => _profileImagePath = picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot pick image: $e'),
          backgroundColor: Colors.red,
        ),
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
      final combos = rawCombos
          .map((c) => Product.fromCombo(Combo.fromJson(c)))
          .toList();
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
        _rewardPoints =
            int.tryParse((matched?['reward_points'] ?? 0).toString()) ?? 0;
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
        serverHistory = await _apiService.fetchCustomerOrders(
          widget.partnerId!,
        );
      } else {
        serverHistory = await _apiService.fetchReceiptHistory();
      }
      final localHistory = await _getLocalSelfOrderHistory();

      final List<Map<String, dynamic>> normalizedServer = serverHistory.map((
        item,
      ) {
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
              final c = (item['customer'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              final mine = _customerName.trim().toLowerCase();
              if (mine.isEmpty) return true;
              return c == mine;
            }).toList();

      // Prefer server records over local placeholders when they refer to same order.
      final byKey = <String, Map<String, dynamic>>{};
      for (final item in localHistory) {
        final idKey = item['id']?.toString() ?? '';
        final nameKey = (item['name'] ?? '').toString();
        final key = idKey.isNotEmpty && idKey != '0'
            ? 'id:$idKey'
            : 'name:$nameKey';
        byKey[key] = Map<String, dynamic>.from(item);
      }
      for (final item in filteredServer) {
        final idKey = item['id']?.toString() ?? '';
        final nameKey = (item['name'] ?? '').toString();
        final key = idKey.isNotEmpty && idKey != '0'
            ? 'id:$idKey'
            : 'name:$nameKey';
        final existing = byKey[key];
        final merged = Map<String, dynamic>.from(item);
        // Keep local proof path as fallback if server proof URL is still empty.
        if (existing != null) {
          final existingProofPath =
              (existing['proof_image_path'] ?? '').toString().trim();
          final mergedProofUrl =
              (merged['transfer_proof_url'] ?? '').toString().trim();
          if (existingProofPath.isNotEmpty && mergedProofUrl.isEmpty) {
            merged['proof_image_path'] = existingProofPath;
          }
        }
        byKey[key] = merged;
      }

      final all = byKey.values.toList();
      all.sort((a, b) {
        final aDate =
            DateTime.tryParse((a['date_order'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse((b['date_order'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
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
        final rawBanks = (config['banks'] as List?) ?? const [];
        _transferBanks = rawBanks
            .whereType<Map>()
            .map((b) => Map<String, dynamic>.from(b))
            .toList();

        // ── select default bank ──
        if (_transferBanks.isNotEmpty) {
          final defaultIdx = _transferBanks.indexWhere((b) => b['is_default'] == true);
          _selectedBankIndex = defaultIdx >= 0 ? defaultIdx : 0;
          _syncSelectedBank();
        } else {
          // fallback to legacy single-bank fields
          _qrImageDataUrl = (config['qr_image_data_url'] ?? '').toString();
          _bankName = (config['bank_name'] ?? '').toString();
          _accountName = (config['account_name'] ?? '').toString();
          _accountNumber = (config['account_number'] ?? '').toString();
          
        }
        final rawBanners = (config['banners'] as List?) ?? const [];
        final rawAds = (config['ads'] as List?) ?? const [];
        _bannerImageDataUrls = rawBanners
            .map(
              (e) => (e is Map ? e['image_data_url'] : null)?.toString() ?? '',
            )
            .where((e) => e.startsWith('data:image'))
            .toList();
        _adImageDataUrls = rawAds
            .map(
              (e) => (e is Map ? e['image_data_url'] : null)?.toString() ?? '',
            )
            .where((e) => e.startsWith('data:image'))
            .toList();
        if (_bannerImageDataUrls.isEmpty) {
          final legacyBanner = (config['banner_image_data_url'] ?? '')
              .toString();
          if (legacyBanner.startsWith('data:image')) {
            _bannerImageDataUrls = [legacyBanner];
          }
        }
        if (_adImageDataUrls.isEmpty &&
            (config['ad_enabled'] ?? true) == true) {
          final legacyAd = (config['ad_image_data_url'] ?? '').toString();
          if (legacyAd.startsWith('data:image')) {
            _adImageDataUrls = [legacyAd];
          }
        }
        _isLoadingSelfOrderConfig = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showAdPopupIfAvailable(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSelfOrderConfig = false);
    }
  }

  void _syncSelectedBank() {
  if (_transferBanks.isEmpty) return;
  final b = _transferBanks[_selectedBankIndex];
  _qrImageDataUrl = (b['qr_image_data_url'] ?? '').toString();
  _bankName = (b['bank_name'] ?? '').toString();
  _accountName = (b['account_name'] ?? '').toString();
  _accountNumber = (b['account_number'] ?? '').toString();
}

  Uint8List? _bytesFromDataUrl(String dataUrl) {
    if (dataUrl.isEmpty || !dataUrl.startsWith('data:image')) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAdPopupIfAvailable() async {
    if (!mounted || _hasShownAdPopup || _adImageDataUrls.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final suppressedDate = prefs.getString(_adSuppressDatePrefsKey) ?? '';
    final now = DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (suppressedDate == todayKey) {
      _hasShownAdPopup = true;
      return;
    }

    _hasShownAdPopup = true;
    final adPageController = PageController();
    final dontShowToday = ValueNotifier<bool>(false);
    final shouldSuppressToday = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dialogWidth = constraints.maxWidth.clamp(0.0, 420.0);
              return SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 420,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: PageView.builder(
                          controller: adPageController,
                          itemCount: _adImageDataUrls.length,
                          itemBuilder: (context, index) {
                            final bytes = _bytesFromDataUrl(_adImageDataUrls[index]);
                            if (bytes == null) {
                              return Container(color: Colors.white);
                            }
                            return Image.memory(bytes, fit: BoxFit.cover);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<bool>(
                      valueListenable: dontShowToday,
                      builder: (context, checked, _) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.96),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: checked,
                                onChanged: (value) =>
                                    dontShowToday.value = value ?? false,
                                activeColor: _brandNavy,
                              ),
                              const Expanded(
                                child: Text(
                                  "Don't show again today",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(28),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () => Navigator.of(context).pop(dontShowToday.value),
                        child: const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.close, color: Colors.white, size: 34),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    adPageController.dispose();
    dontShowToday.dispose();
    if ((shouldSuppressToday ?? false) && mounted) {
      await prefs.setString(_adSuppressDatePrefsKey, todayKey);
    }
  }

  Uint8List? _qrBytesFromDataUrl() {
    if (_qrImageDataUrl.isEmpty || !_qrImageDataUrl.startsWith('data:image'))
      return null;
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
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR image configured yet'), backgroundColor: Colors.orange),
        );
        return;
      }

      // ── permissions ──────────────────────────────────────────
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
        // Android 13+ doesn't need storage permission for saving images
        final sdkInt = await _getAndroidSdkInt();
        if (sdkInt < 33) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission is required to save QR')),
            );
            return;
          }
        }
      }

      // ── save via temp file → GallerySaver ────────────────────
      final tempDir = await getTemporaryDirectory();
      final filename = 'la_dolce_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes, flush: true);

      // Verify file was written correctly
      final written = await tempFile.readAsBytes();
      debugPrint('Written file size: ${written.length}, header: ${written[0]} ${written[1]} ${written[2]} ${written[3]}');

      final result = await ImageGallerySaverPlus.saveFile(
        tempFile.path,
        name: 'la_dolce_qr_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      debugPrint('Gallery save result: $result');

      // cleanup
      try { await tempFile.delete(); } catch (_) {}

      if (!mounted) return;

      // ── check result more robustly ────────────────────────────
      final isSuccess = result is Map &&
          ((result['isSuccess'] == true) ||
          (result['filePath'] != null && (result['filePath'] as String).isNotEmpty));

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR saved to gallery ✓'), backgroundColor: Colors.green),
        );
      } else {
        // Fallback: save to Downloads folder directly
        await _saveQrToDownloads(bytes);
      }
    } catch (e) {
      debugPrint('_downloadQrCode error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download QR: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── fallback: save directly to Downloads ─────────────────────
  Future<void> _saveQrToDownloads(Uint8List bytes) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) throw Exception('Cannot find save directory');

      final filename = 'la_dolce_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('Saved to: ${file.path}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isAndroid
                ? 'QR saved to Downloads/$filename'
                : 'QR saved to Documents/$filename',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('_saveQrToDownloads error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── helper: get Android SDK version ──────────────────────────
  Future<int> _getAndroidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      // Read from system property
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 30;
    } catch (_) {
      return 30; // assume Android 11 as safe default
    }
  }
    // append new item


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
    await prefs.setStringList(
      'customer_self_order_history',
      items.take(100).toList(),
    );
  }

  List<Product> get _filteredProducts {
    var result = _products;

    if (_selectedCategory != 'All Items') {
      result = result.where((p) => p.category == _selectedCategory).toList();
    }

    return result;
  }

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
      return selectedIds.containsAll(itemIds) &&
          itemIds.containsAll(selectedIds);
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
            final bool canConfirm =
            paymentChoice != 'transfer' || proofImage != null;
            return FractionallySizedBox(
              heightFactor: 0.90,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Payment Method',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RadioListTile<String>(
                      value: 'pay_at_store',
                      groupValue: paymentChoice,
                      onChanged: (val) =>
                          setSheetState(() => paymentChoice = val!),
                      title: const Text('Pay at the store'),
                      subtitle: const Text('Order now, pay when you arrive'),
                    ),
                    RadioListTile<String>(
                      value: 'transfer',
                      groupValue: paymentChoice,
                      onChanged: (val) =>
                          setSheetState(() => paymentChoice = val!),
                      title: const Text('Bank transfer'),
                      subtitle: const Text(
                        'Upload transfer proof after payment',
                      ),
                    ),
                    if (paymentChoice == 'transfer') ...[
                      const SizedBox(height: 10),
                      if (_transferBanks.length > 1) ...[
                        const Text(
                          'Select Bank',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedBankIndex,
                              isExpanded: true,
                              items: List.generate(_transferBanks.length, (i) {
                                final b = _transferBanks[i];
                                return DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    '${b['label'] ?? b['bank_name']} — ${b['account_name']}',
                                  ),
                                );
                              }),
                              onChanged: (idx) {
                                if (idx == null) return;
                                setSheetState(() {
                                  _selectedBankIndex = idx;
                                  _syncSelectedBank();
                                  proofImage = null; // reset proof on bank change
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                                    ? Image.memory(
                                        _qrBytesFromDataUrl()!,
                                        fit: BoxFit.contain,
                                      )
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
                            final picked = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                            );
                            if (picked != null) {
                              setSheetState(() => proofImage = picked);
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            proofImage == null
                                ? 'Upload Transfer Proof'
                                : 'Proof Selected',
                          ),
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
                        onPressed: (_isPlacingOrder || !canConfirm)
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _placeOrder(
                                  paymentChoice: paymentChoice,
                                  proofImagePath: proofImage?.path,
                                  transferBankId: _transferBanks.isNotEmpty
                                    ? _transferBanks[_selectedBankIndex]['id'] as int?
                                    : null,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Confirm Order (₭${_cartTotal.toStringAsFixed(2)})',
                        ),
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
    int? transferBankId,
  }) async {
    if (_cartItems.isEmpty || _isPlacingOrder) return;

    setState(() => _isPlacingOrder = true);
    try {
      final lines = _cartItems
          .map(
            (item) => {
              'product_id': item.product.id,
              'qty': item.quantity,
              'price_unit': item.product.price,
              'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
            },
          )
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
      if (paymentChoice == 'transfer' &&
          proofImagePath != null &&
          proofImagePath.isNotEmpty &&
          orderId > 0) {
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
        'payment_method': paymentChoice == 'transfer'
            ? 'Transfer'
            : 'Pay At Store',
        'state': paymentChoice == 'transfer'
            ? 'waiting transfer verification'
            : 'waiting payment at store',
        'customer': _customerName,
        'proof_image_path': proofImagePath,
        'transfer_proof_url': uploadedProofUrl,
        'lines': lines.map((e) {
          final p = _products.where((x) => x.id == e['product_id']).firstOrNull;
          final qty = (e['qty'] ?? 0);
          final price = (e['price_unit'] ?? 0.0);
          final subtotal =
              (qty is num ? qty.toDouble() : 0.0) *
              (price is num ? price.toDouble() : 0.0);
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
        _selectedTabIndex =
            2; // History tab (Home=0, Cart=1, History=2, Profile=3)
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
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: Colors.red,
        ),
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
        _rewardPoints =
            int.tryParse(
              (saved['reward_points'] ?? _rewardPoints).toString(),
            ) ??
            _rewardPoints;
      });

      await _loadHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot save profile: $e'),
          backgroundColor: Colors.red,
        ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _brandNavy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bank transfer details',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _brandNavy,
                  ),
                ),
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
                      Text(
                        'Account name: ${_accountName.isEmpty ? '-' : _accountName}',
                      ),
                      Text('Bank: ${_bankName.isEmpty ? '-' : _bankName}'),
                      Text(
                        'Account no: ${_accountNumber.isEmpty ? '-' : _accountNumber}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'QR code',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _brandNavy,
                  ),
                ),
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
                                ? Image.memory(
                                    _qrBytesFromDataUrl()!,
                                    fit: BoxFit.contain,
                                  )
                                : const Center(
                                    child: Text('QR not configured'),
                                  )),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
            padding: EdgeInsets.only(
              top: 24,
              left: 20,
              right: 20,
              bottom: 20 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Text(
                            'Edit profile',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _brandNavy,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 24,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Input fields
                      _buildProfileInputField(
                        label: 'FULL NAME',
                        value: name,
                        icon: Icons.person_outline,
                        onChanged: (val) => setSheetState(() => name = val),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInputField(
                        label: 'PHONE',
                        value: phone,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        onChanged: (val) => setSheetState(() => phone = val),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInputField(
                        label: 'EMAIL',
                        value: email,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (val) => setSheetState(() => email = val),
                      ),
                      const SizedBox(height: 28),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSavingProfile
                              ? null
                              : () async {
                                  _customerName = name;
                                  _customerPhone = phone;
                                  _customerEmail = email;
                                  Navigator.pop(context);
                                  await _saveProfile();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSavingProfile
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInputField({
    required String label,
    required String value,
    required IconData icon,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(icon, size: 20, color: Colors.grey[500]),
                ),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: value),
                    keyboardType: keyboardType,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      hintText: label,
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 15,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _brandNavy,
                ),
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _brandNavy,
                fontWeight: FontWeight.w800,
              ),
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Close button
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product name
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Category
                          Text(
                            product.category,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Product image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 280,
                              color: const Color(0xFFF5F5F5),
                              child: _buildProductImage(product),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Price
                          Row(
                            children: [
                              Text(
                                '₭${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: _brandNavy,
                                ),
                              ),
                              const Spacer(),
                              // Quantity selector
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        if (qty > 1) {
                                          setSheetState(() => qty--);
                                        }
                                      },
                                      icon: const Icon(Icons.remove, size: 18),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setSheetState(() => qty++);
                                      },
                                      icon: const Icon(Icons.add, size: 18),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Toppings section
                          if (product.toppings.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Add toppings? (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: product.toppings.map((topping) {
                                final selected = selectedToppings.any(
                                  (t) => t.id == topping.id,
                                );
                                return FilterChip(
                                  selected: selected,
                                  label: Text(
                                    topping.extraPrice > 0
                                        ? '${topping.name} (+₭${topping.extraPrice.toStringAsFixed(0)})'
                                        : topping.name,
                                  ),
                                  onSelected: (value) {
                                    setSheetState(() {
                                      if (value) {
                                        selectedToppings.add(topping);
                                      } else {
                                        selectedToppings.removeWhere(
                                          (t) => t.id == topping.id,
                                        );
                                      }
                                    });
                                  },
                                  backgroundColor: Colors.grey[100],
                                  selectedColor: _brandNavy.withOpacity(0.15),
                                  checkmarkColor: _brandNavy,
                                );
                              }).toList(),
                            ),
                          ],
                          // Total price
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _brandNavy.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '₭${((product.price + selectedToppings.fold(0.0, (sum, t) => sum + t.extraPrice)) * qty).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _brandNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Add to cart button - Always visible at bottom
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      top: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          _addToCart(
                            product,
                            quantity: qty,
                            selectedToppings: selectedToppings,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$qty ${product.name} added to cart',
                              ),
                              backgroundColor: _brandNavy,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(milliseconds: 1500),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Add to Cart - ₭${((product.price + selectedToppings.fold(0.0, (sum, t) => sum + t.extraPrice)) * qty).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isWide = width >= 900;
    final isSmall = width < 360;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _brandNavy,
        elevation: 0,
        scrolledUnderElevation: 1,
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
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Points: $_rewardPoints',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmall ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: (_isLoadingCatalog || _isLoadingProfile)
                ? null
                : () async {
                    await Future.wait([_loadCatalog(), _loadProfile()]);
                  },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.white)),
          Positioned.fill(
            child: SafeArea(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildHomeTab(isWide: isWide, isSmall: isSmall),
                  _buildCartTab(isSmall: isSmall),
                  _buildHistoryTab(isSmall: isSmall),
                  _buildProfileTab(isWide: isWide, isSmall: isSmall),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _selectedTabIndex == 0 && _cartCount > 0
          ? _buildStickyCartBar()
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedTabIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: _brandNavy.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: _cartCount > 0
                ? Badge(
                    label: Text('$_cartCount'),
                    backgroundColor: Colors.red,
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: _selectedTabIndex == 1 ? _brandNavy : Colors.grey,
                    ),
                  )
                : Icon(
                    Icons.shopping_bag_outlined,
                    color: _selectedTabIndex == 1 ? _brandNavy : Colors.grey,
                  ),
            selectedIcon: _cartCount > 0
                ? Badge(
                    label: Text('$_cartCount'),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.shopping_bag, color: _brandNavy),
                  )
                : const Icon(Icons.shopping_bag, color: _brandNavy),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
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

  Widget _buildHomeTab({required bool isWide, required bool isSmall}) {
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
            padding: EdgeInsets.fromLTRB(
              isSmall ? 8 : 12,
              12,
              isSmall ? 8 : 12,
              isWide ? 12 : (_isCartEmpty ? 12 : 92),
            ),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : (isSmall ? 1 : 2),
              childAspectRatio: isWide ? 0.8 : (isSmall ? 0.75 : 0.68),
              crossAxisSpacing: isSmall ? 8 : 10,
              mainAxisSpacing: isSmall ? 8 : 10,
            ),
            itemBuilder: (context, index) => _buildProductCard(
              items[index],
              isWide: isWide,
              isSmall: isSmall,
            ),
          );

    if (!isWide) {
      return _buildMobileHomeSliver(isSmall: isSmall, items: items);
    }

    return Column(
      children: [
        // ← Banner added for wide/tablet layout
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildBannerCarousel(isSmall: isSmall),
        ),
        _buildCategoryChipsBar(isSmall: isSmall),
        Expanded(
          child: Row(
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
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHomeSliver({
    required bool isSmall,
    required List<Product> items,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isSmall ? 12 : 16,
              12,
              isSmall ? 12 : 16,
              12,
            ),
            child: _buildBannerCarousel(isSmall: isSmall),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _CategoryHeaderDelegate(
            height: 52,
            child: Container(
              color: _brandSurface,
              alignment: Alignment.center,
              child: _buildCategoryChipsBar(isSmall: isSmall),
            ),
          ),
        ),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No items found')),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isSmall ? 8 : 12,
              12,
              isSmall ? 8 : 12,
              _isCartEmpty ? 12 : 92,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isSmall ? 1 : 2,
                childAspectRatio: isSmall ? 0.75 : 0.68,
                crossAxisSpacing: isSmall ? 8 : 10,
                mainAxisSpacing: isSmall ? 8 : 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCard(
                  items[index],
                  isWide: false,
                  isSmall: isSmall,
                ),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerCarousel({bool isSmall = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: isSmall ? 112 : 132,
        decoration: BoxDecoration(
          color: _brandNavy.withOpacity(0.06),
          border: Border.all(color: _brandDivider),
          borderRadius: BorderRadius.circular(16),
        ),
        child: (_bannerImageDataUrls.isEmpty)
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_brandNavy, _brandNavy2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(14),
                child: const Text(
                  'Fresh picks for you today',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              )
            : PageView.builder(
                itemCount: _bannerImageDataUrls.length,
                itemBuilder: (context, index) {
                  final bytes = _bytesFromDataUrl(_bannerImageDataUrls[index]);
                  if (bytes == null) return const SizedBox.shrink();
                  return Image.memory(bytes, fit: BoxFit.cover);
                },
              ),
      ),
    );
  }

  Widget _buildCategoryChipsBar({bool isSmall = false}) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category.name == _selectedCategory;
          return ChoiceChip(
            label: Text(category.name),
            selected: selected,
            onSelected: (_) =>
                setState(() => _selectedCategory = category.name),
            selectedColor: _brandNavy,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _brandNavy : const Color(0xFFE0E0E0),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected ? _brandNavy : const Color(0xFFE0E0E0),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(
    Product product, {
    required bool isWide,
    required bool isSmall,
  }) {
    return InkWell(
      onTap: () =>
          isWide ? _setPreviewProduct(product) : _openProductDetail(product),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: _buildProductImage(product),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: isSmall ? 28 : 30,
                      height: isSmall ? 28 : 30,
                      decoration: BoxDecoration(
                        color: _brandNavy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: isSmall ? 16 : 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmall ? 10 : 12,
                  10,
                  isSmall ? 10 : 12,
                  isSmall ? 10 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        fontSize: isSmall ? 13 : 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmall ? 10 : 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₭${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _brandNavy,
                            fontSize: isSmall ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  // Fix the sticky cart bar to show correctly when empty
  Widget _buildStickyCartBar() {
    final isEmpty = _cartItems.isEmpty;
    final itemCount = _cartCount;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: InkWell(
          onTap: isEmpty ? null : () => setState(() => _selectedTabIndex = 1),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isEmpty ? 0.0 : 1.0, // Hide when empty
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _brandNavy,
                boxShadow: [
                  BoxShadow(
                    color: _brandNavy.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$itemCount item${itemCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₭${_cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _brandNavy,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFFE5B8)),
                  ),
                  child: const Text(
                    'LaDolce',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _brandGold,
                    ),
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
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _brandNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _previewToppings.isEmpty
                    ? 'No Toppings'
                    : _previewToppings.map((t) => t.name).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: _brandNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: product.toppings.isEmpty
                      ? null
                      : () => _openToppingsPickerForPreview(product),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandNavy,
                    side: const BorderSide(color: _brandDivider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    product.toppings.isEmpty
                        ? 'No toppings for this item'
                        : 'Select Toppings',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _addToCart(
                      product,
                      quantity: _previewQty,
                      selectedToppings: _previewToppings,
                    );
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: _brandDivider),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Cart total',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₭${_cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _brandNavy,
                    ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _brandNavy,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Optional',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: product.toppings.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: _brandDivider),
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
                            title: Text(
                              topping.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _brandNavy,
                              ),
                            ),
                            subtitle: Text(
                              topping.extraPrice > 0
                                  ? '+₭${topping.extraPrice.toStringAsFixed(2)}'
                                  : 'Free',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
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
                          setState(
                            () => _previewToppings = List<Topping>.from(temp),
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
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

  Widget _buildCartTab({bool isSmall = false}) {
    if (_cartItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shopping bag icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _brandNavy.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: _brandNavy,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              // "Your cart is empty" text
              const Text(
                'Your cart is empty',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // "Add items from Home" text
              Text(
                'Add items from Home',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // When cart has items, show the cart items list
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 70,
                        height: 70,
                        child: _buildProductImage(item.product),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (item.selectedToppings.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.selectedToppings
                                  .map((t) => t.name)
                                  .join(', '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '₭${item.product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _brandNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _updateQuantity(item, item.quantity - 1),
                                icon: const Icon(Icons.remove, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _updateQuantity(item, item.quantity + 1),
                                icon: const Icon(Icons.add, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    Text(
                      '₭${_cartTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _brandNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPlacingOrder ? null : _showCheckoutOptions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandNavy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isPlacingOrder
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Checkout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab({bool isSmall = false}) {
    if (_isLoadingHistory) {
      return Center(
        child: SizedBox(
          width: isSmall ? 20 : 24, // ← Example usage
          height: isSmall ? 20 : 24,
          child: const CircularProgressIndicator(),
        ),
      );
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
    if (rawState == 'waiting_transfer_review')
      return 'Waiting transfer verification';
    if (rawState == 'draft' &&
        paymentMethod.toLowerCase().contains('transfer')) {
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: ₭${double.tryParse((item['amount_total'] ?? 0).toString())?.toStringAsFixed(2) ?? '0.00'}',
                ),
                Text('Payment: ${item['payment_method'] ?? 'Unknown'}'),
                Text(
                  'Status: ${_friendlyStatus((item['state'] ?? '').toString(), (item['payment_method'] ?? '').toString())}',
                ),
                const SizedBox(height: 12),
                if (hasLocalProof || hasServerProof) ...[
                  const Text(
                    'Transfer Proof',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasLocalProof
                        ? Image.file(
                            File(proofPath),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          )
                        : FutureBuilder<List<dynamic>>(
                            future: Future.wait<dynamic>([
                              _apiService.resolveMediaUrlAsync(proofUrl),
                              _apiService.buildImageHeaders(),
                            ]),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              }
                              final resolvedUrl = (snapshot.data![0] as String?) ?? '';
                              final headers =
                                  (snapshot.data![1] as Map<String, String>?) ?? const {};
                              if (resolvedUrl.isEmpty) return const SizedBox.shrink();
                              return Image.network(
                                resolvedUrl,
                                headers: headers,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              );
                            },
                          ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Order Items',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: lines.isEmpty
                      ? const Center(child: Text('No item details available'))
                      : ListView.separated(
                          itemCount: lines.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final line = lines[index] as Map<dynamic, dynamic>;
                            final qty =
                                double.tryParse(
                                  (line['qty'] ?? 0).toString(),
                                ) ??
                                0;
                            final subtotal =
                                double.tryParse(
                                  (line['subtotal'] ?? 0).toString(),
                                ) ??
                                0;
                            return ListTile(
                              title: Text(
                                (line['product_name'] ?? 'Item').toString(),
                              ),
                              subtitle: Text(
                                'Qty: ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}',
                              ),
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

  Widget _buildProfileTab({bool isWide = false, bool isSmall = false}) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 760;
        final customerMemoryImage = _customerMemoryImage();
        final headerHeight = isCompactHeight ? 172.0 : 188.0;
        final profileShiftY = isCompactHeight ? -52.0 : -62.0;
        final avatarOuterRadius = isSmall
            ? 60.0
            : (isCompactHeight ? 78.0 : 93.0);
        final avatarInnerRadius = isSmall
            ? 54.0
            : (isCompactHeight ? 72.0 : 86.0);
        final initialsFontSize = isSmall
            ? 24.0
            : (isCompactHeight ? 32.0 : 38.0);
        final statusDotSize = isSmall ? 16.0 : (isCompactHeight ? 20.0 : 24.0);
        final cameraButtonSize = isSmall
            ? 32.0
            : (isCompactHeight ? 40.0 : 46.0);
        final cameraIconSize = isSmall ? 16.0 : (isCompactHeight ? 20.0 : 22.0);
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
                          child: const CustomPaint(
                            painter: _LuxuryPatternPainter(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, profileShiftY),
                  child: LayoutBuilder(
                    builder: (context, childConstraints) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: childConstraints.maxWidth,
                            maxWidth: childConstraints.maxWidth,
                            minHeight: childConstraints.maxHeight < 518
                                ? 518
                                : childConstraints.maxHeight,
                            maxHeight: childConstraints.maxHeight < 518
                                ? 518
                                : childConstraints.maxHeight,
                          ),
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
                                        backgroundColor: const Color(
                                          0xFFF2F5FF,
                                        ),
                                        backgroundImage:
                                            (_profileImagePath != null &&
                                                File(
                                                  _profileImagePath!,
                                                ).existsSync())
                                            ? FileImage(
                                                File(_profileImagePath!),
                                              )
                                            : (customerMemoryImage != null)
                                            ? customerMemoryImage
                                            : null,
                                        child:
                                            (_profileImagePath == null ||
                                                    !File(
                                                      _profileImagePath!,
                                                    ).existsSync()) &&
                                                (_customerImageBase64 == null ||
                                                    _customerImageBase64!
                                                        .isEmpty)
                                            ? Text(
                                                _customerName.isEmpty
                                                    ? 'C'
                                                    : _customerName
                                                          .substring(0, 1)
                                                          .toUpperCase(),
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
                                    left: isSmall ? 10 : 14,
                                    bottom: isSmall ? 10 : 14,
                                    child: Container(
                                      width: statusDotSize,
                                      height: statusDotSize,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: isSmall ? 6 : 10,
                                    bottom: isSmall ? 6 : 10,
                                    child: InkWell(
                                      onTap: _pickProfileImage,
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        width: cameraButtonSize,
                                        height: cameraButtonSize,
                                        decoration: BoxDecoration(
                                          color: _brandNavy,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: cameraIconSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _customerName.isEmpty
                                    ? 'Customer'
                                    : _customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isSmall ? 16 : 18,
                                  fontWeight: FontWeight.w900,
                                  color: _brandNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _customerEmail.isEmpty ? ' ' : _customerEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmall ? 12 : 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F5FF),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFDCE5FF),
                                  ),
                                ),
                                child: Text(
                                  'Reward points: $_rewardPoints',
                                  style: TextStyle(
                                    color: _brandNavy,
                                    fontWeight: FontWeight.w800,
                                    fontSize: isSmall ? 12 : 14,
                                  ),
                                ),
                              ),
                              SizedBox(height: detailsTopGap),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmall ? 12 : 16,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _brandDivider),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x12000000),
                                        blurRadius: 14,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      isSmall ? 12 : 14,
                                      12,
                                      isSmall ? 12 : 14,
                                      10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _detailRow(
                                          'Full name',
                                          _customerName.isEmpty
                                              ? '-'
                                              : _customerName,
                                        ),
                                        _detailRow(
                                          'Phone',
                                          _customerPhone.isEmpty
                                              ? '-'
                                              : _customerPhone,
                                        ),
                                        _detailRow(
                                          'Email',
                                          _customerEmail.isEmpty
                                              ? '-'
                                              : _customerEmail,
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isSavingProfile
                                                ? null
                                                : _openEditProfileSheet,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _brandNavy,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical: isSmall ? 10 : 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text(
                                              'Edit profile',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  isSmall ? 12 : 16,
                                  12,
                                  isSmall ? 12 : 16,
                                  logoutBottomPadding,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoggingOut ? null : _logout,
                                    icon: const Icon(Icons.logout),
                                    label: _isLoggingOut
                                        ? const Text('Logging out...')
                                        : const Text('Logout'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(
                                        vertical: isSmall ? 10 : 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
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
          ..cubicTo(
            center.dx - r * 0.35,
            center.dy - r * 0.65,
            center.dx + r * 0.35,
            center.dy - r * 0.65,
            center.dx + r * 0.9,
            center.dy,
          )
          ..cubicTo(
            center.dx + r * 0.35,
            center.dy + r * 0.65,
            center.dx - r * 0.35,
            center.dy + r * 0.65,
            center.dx - r * 0.9,
            center.dy,
          );
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
    p.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.55,
      size.height - 44,
    );
    p.quadraticBezierTo(
      size.width * 0.85,
      size.height - 92,
      size.width,
      size.height - 54,
    );
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _CategoryHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
