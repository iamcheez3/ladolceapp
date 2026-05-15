import 'dart:convert';
import 'dart:io';
import 'customer_support_screen.dart';
import 'ranking_screen.dart';
import '../services/push_notifications_service.dart';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import 'customer_order_detail_screen.dart';
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
    super.key,
    required this.customerName,
    required this.userId,
    this.partnerId,
  });

  @override
  State<CustomerSelfOrderScreen> createState() =>
      _CustomerSelfOrderScreenState();
}

class _CustomerSelfOrderScreenState extends State<CustomerSelfOrderScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, String> _productNotes = {};
  final Map<String, Uint8List> _decodedImageCache = {};

  // Brand palette (based on bear logo)
  static const _brandNavy = Color(0xFF0D1565);
  static const _brandNavy2 = Color(0xFF142B8C);
  static const _brandSurface = Colors.white;
  static const _brandCard = Colors.white;
  static const _brandDivider = Color(0xFFE6E8F2);
  static const _brandGold = Color(0xFFC6A15B);
  static const _navInactive = Color(0xFF94A3B8);
  static const _historyCardBg = Color(0xFFF8F9FC);
  static const _textPrimaryDark = Color(0xFF0B1B3D);
  static const _labelGray = Color(0xFF64748B);

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
  List<Product> _recommendedProducts = [];
  List<Product> _popularProducts = [];
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
  String _customerDob = '';
  int _rewardPoints = 0;
  int _rewardRank = 0;
  String? _customerImageBase64;
  String _qrImageDataUrl = '';
  String _bankName = '';
  String _accountName = '';
  String _accountNumber = '';
  List<String> _bannerImageDataUrls = [];
  List<String> _adImageDataUrls = [];
  String _supportFacebookUrl = '';
  String _supportWhatsappNumber = '';
  String _supportWhatsappLink = '';
  bool _pushNotificationsEnabled = true;
  bool _hasShownAdPopup = false;
  String? _profileImagePath;
  bool _isUploadingProfileImage = false;

  List<Map<String, dynamic>> _historyItems = [];

  // Branch selection (customer self-order)
  bool _isLoadingBranches = true;
  List<Map<String, dynamic>> _branches = const [];
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _customerName = widget.customerName;
    _cartItems.clear();
    _validateSingleDeviceSession();
    _loadBranches();
    _loadCatalog();
    _loadProfile();
    _loadHistory();
    _loadSelfOrderConfig();
    _loadProfileImage();
    _loadNotificationPref();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoadingBranches = true);
    try {
      final cachedId = await _apiService.getCachedCustomerBranchId();
      final cachedName = await _apiService.getCachedCustomerBranchName();
      final branches = await _apiService.fetchBranchesPublic();
      if (!mounted) return;

      int? selectedId = cachedId;
      String selectedName = (cachedName ?? '').trim();

      if (selectedId != null) {
        final match = branches.where((b) {
          final id = (b['id'] is int) ? b['id'] as int : int.tryParse('${b['id']}') ?? 0;
          return id == selectedId;
        }).toList();
        if (match.isNotEmpty) {
          selectedName = (match.first['name'] ?? '').toString();
        } else {
          selectedId = null;
        }
      }
      if (selectedId == null && branches.isNotEmpty) {
        selectedId = (branches.first['id'] is int)
            ? branches.first['id'] as int
            : int.tryParse('${branches.first['id']}');
        selectedName = (branches.first['name'] ?? '').toString();
      }

      setState(() {
        _branches = branches;
        _selectedBranchId = selectedId;
        _isLoadingBranches = false;
      });
      if (selectedId != null && selectedId > 0) {
        await _apiService.setCachedCustomerBranch(
          branchId: selectedId,
          branchName: selectedName,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _branches = const [];
        _selectedBranchId = null;
        _isLoadingBranches = false;
      });
    }
  }

  Future<void> _loadNotificationPref() async {
    final v = await PushNotificationsService.isCustomerPushEnabled();
    if (!mounted) return;
    setState(() => _pushNotificationsEnabled = v);
  }

  Future<void> _validateSingleDeviceSession() async {
    // If user logged in from another device, backend will invalidate this session.
    try {
      final ok = await _apiService.validateCustomerSession();
      if (!ok) {
        await _apiService.logout();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(
              infoMessage: 'Session expired. Please login again.',
            ),
          ),
        );
      }
    } catch (_) {
      // ignore: don't block UI if offline; session will be validated on next online call
    }
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

      // Auto-save avatar to backend (best-effort).
      try {
        if (_isUploadingProfileImage) return;
        setState(() => _isUploadingProfileImage = true);
        final bytes = await File(picked.path).readAsBytes();
        final b64 = base64Encode(bytes);
        final saved = await _apiService.saveCustomer(
          id: _customerId,
          name: _customerName.trim().isEmpty ? 'Customer' : _customerName.trim(),
          phone: _customerPhone.trim(),
          email: _customerEmail.trim().isEmpty ? null : _customerEmail.trim(),
          dateOfBirth: _customerDob.trim().isEmpty ? null : _customerDob.trim(),
          imageBase64: b64,
        );
        if (!mounted) return;
        setState(() {
          _customerImageBase64 = saved['image_base64']?.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (_) {
        // Keep local image; backend upload is best-effort.
      } finally {
        if (mounted) setState(() => _isUploadingProfileImage = false);
      }
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
      // Always hit the network for self-order: local `cached_products` is shared
      // with POS and stays stale, so `block_self_order` would never update otherwise.
      final products = await _apiService.fetchProducts(
        limit: 200,
        forceRefresh: true,
      );
      final rawCombos = await _apiService.fetchCombos();
      final combos = rawCombos
          .map((c) => Product.fromCombo(Combo.fromJson(c)))
          .toList();
      products.addAll(combos);

      final categorySet = products.map((p) => p.category).toSet();
      final categories = [Category(id: 'All', name: 'All Items'), ...categorySet.map((name) => Category(id: name, name: name))]
        ;

      final highlights = await _apiService.fetchProductHighlights();
      final recIds = highlights['recommended'] ?? [];
      final popIds = highlights['popular'] ?? [];

      final recommendedProducts = products.where((p) => recIds.contains(p.id)).toList();
      final popularProducts = products.where((p) => popIds.contains(p.id)).toList();

      if (!mounted) return;
      final oldPreviewId = _previewProduct?.id;
      Product? nextPreview = _previewProduct;
      if (nextPreview != null) {
        final match =
            products.where((p) => p.id == nextPreview!.id).firstOrNull;
        if (match == null || match.blockSelfOrder) {
          nextPreview = null;
        } else {
          nextPreview = match;
        }
      }
      nextPreview ??=
          products.where((p) => !p.blockSelfOrder).firstOrNull;

      setState(() {
        _products = products;
        _recommendedProducts = recommendedProducts;
        _popularProducts = popularProducts;
        _categories = categories;
        _isLoadingCatalog = false;
        _previewProduct = nextPreview;
        if (nextPreview?.id != oldPreviewId) {
          _previewQty = 1;
          _previewToppings = [];
        }
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
        'date_of_birth': '',
        'birthdate': '',
        'reward_points': 0,
      };

      if (!mounted) return;
      setState(() {
        _customerId = matched?['id'] as int?;
        _customerName = (matched?['name'] ?? widget.customerName).toString();
        _customerPhone = (matched?['phone'] ?? '').toString();
        _customerEmail = (matched?['email'] ?? '').toString();
        _customerDob =
            (matched?['date_of_birth'] ?? matched?['birthdate'] ?? '').toString();
        _rewardPoints =
            int.tryParse((matched?['reward_points'] ?? 0).toString()) ?? 0;
        _rewardRank = int.tryParse((matched?['reward_rank'] ?? 0).toString()) ?? 0;
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
          final legacyBanner = (config['banner_image_data_url'] ?? '').toString();
          if (legacyBanner.startsWith('data:image')) {
            _bannerImageDataUrls = [legacyBanner];
          }
        }

        // Pre-decode images to avoid lag during first display
        for (final url in _bannerImageDataUrls) {
          _bytesFromDataUrl(url);
        }
        for (final url in _adImageDataUrls) {
          _bytesFromDataUrl(url);
        }

        if (_adImageDataUrls.isEmpty && (config['ad_enabled'] ?? true) == true) {
          final legacyAd = (config['ad_image_data_url'] ?? '').toString();
          if (legacyAd.startsWith('data:image')) {
            _adImageDataUrls = [legacyAd];
          }
        }
        final cs = config['customer_support'];
        if (cs is Map) {
          final m = Map<String, dynamic>.from(cs);
          _supportFacebookUrl = (m['facebook_url'] ?? '').toString();
          _supportWhatsappNumber = (m['whatsapp_number'] ?? '').toString();
          _supportWhatsappLink = (m['whatsapp_link'] ?? '').toString();
        } else {
          _supportFacebookUrl = '';
          _supportWhatsappNumber = '';
          _supportWhatsappLink = '';
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
    if (_decodedImageCache.containsKey(dataUrl)) return _decodedImageCache[dataUrl];
    
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      _decodedImageCache[dataUrl] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAdPopupIfAvailable() async {
    if (!mounted || _hasShownAdPopup || _adImageDataUrls.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
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
              final screenH = MediaQuery.sizeOf(context).height;
              final orientation = MediaQuery.orientationOf(context);
              final heightFrac =
                  orientation == Orientation.landscape ? 0.38 : 0.5;
              final adHeight = (screenH * heightFrac).clamp(140.0, 460.0);
              return SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    SizedBox(
                      height: adHeight,
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
    if (_qrImageDataUrl.isEmpty || !_qrImageDataUrl.startsWith('data:image')) {
      return null;
    }
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
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 30; // assume Android 11 as safe default
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

  void _showSelfOrderBlockedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This item is run out and cannot be ordered.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setPreviewProduct(Product product) {
    if (product.blockSelfOrder) {
      _showSelfOrderBlockedMessage();
      return;
    }
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
    if (product.blockSelfOrder) return;
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

  /// System gesture insets (home bar / 3-button nav) — prefer over [MediaQuery.padding]
  /// for bottom CTAs; `padding` is often 0 on Android with gesture navigation.
  static double _gestureNavBottomPad(BuildContext context) {
    return 8 + MediaQuery.viewPaddingOf(context).bottom;
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

    String paymentChoice = 'transfer';
    XFile? proofImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bool hasBranch = _selectedBranchId != null && (_selectedBranchId ?? 0) > 0;
            final bool canConfirm =
                hasBranch && (paymentChoice != 'transfer' || proofImage != null);
            final bottomInset =
                MediaQuery.viewInsetsOf(ctx).bottom + _gestureNavBottomPad(ctx);
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: FractionallySizedBox(
                heightFactor: 0.90,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)?.choosePaymentMethod ?? 'Choose Payment Method',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppLocalizations.of(context)?.selectBranch ?? 'Select Branch',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              if (_isLoadingBranches)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (_branches.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    AppLocalizations.of(context)?.noBranchesFound ?? 'No branches found. Please ask staff.',
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _selectedBranchId,
                                      isExpanded: true,
                                      items: _branches.map((b) {
                                        final id = (b['id'] is int)
                                            ? b['id'] as int
                                            : int.tryParse('${b['id']}') ?? 0;
                                        final name = (b['name'] ?? '').toString();
                                        final code = (b['code'] ?? '').toString().trim();
                                        final label = code.isNotEmpty ? '$name ($code)' : name;
                                        return DropdownMenuItem<int>(
                                          value: id,
                                          child: Text(label),
                                        );
                                      }).toList(),
                                      onChanged: (v) async {
                                        if (v == null) return;
                                        final match = _branches.where((b) {
                                          final id = (b['id'] is int)
                                              ? b['id'] as int
                                              : int.tryParse('${b['id']}') ?? 0;
                                          return id == v;
                                        }).toList();
                                        final name = match.isNotEmpty ? (match.first['name'] ?? '').toString() : '';
                                        setSheetState(() {
                                          _selectedBranchId = v;
                                        });
                                        await _apiService.setCachedCustomerBranch(
                                          branchId: v,
                                          branchName: name,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),

                              if (paymentChoice == 'transfer') ...[
                                const SizedBox(height: 10),
                                if (_transferBanks.length > 1) ...[
                                  Text(
                                    AppLocalizations.of(context)?.selectBank ?? 'Select Bank',
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
                                Text(
                                  AppLocalizations.of(context)?.scanQrCode ?? 'Scan QR Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, c) {
                                    final qrSide = (c.maxWidth * 0.72).clamp(160.0, 220.0);
                                    return Center(
                                      child: SizedBox(
                                        width: qrSide,
                                        height: qrSide,
                                        child: Container(
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
                                    );
                                  },
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
                                    label: Text(AppLocalizations.of(context)?.downloadQr ?? 'Download QR'),
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
                                          ? AppLocalizations.of(context)?.uploadTransferProof ?? 'Upload Transfer Proof'
                                          : AppLocalizations.of(context)?.proofSelected ?? 'Proof Selected',
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
                                    child: Text(
                                      AppLocalizations.of(context)?.transferProofSelectedMsg ?? 'Transfer proof selected. It will be uploaded when you confirm order.',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                    branchId: _selectedBranchId,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            '${AppLocalizations.of(context)?.confirmOrder ?? 'Confirm Order'} (₭${_cartTotal.toStringAsFixed(2)})',
                          ),
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

  Future<void> _placeOrder({
    required String paymentChoice,
    String? proofImagePath,
    int? transferBankId,
    int? branchId,
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

      final displayName = _customerName.trim().isNotEmpty
          ? _customerName.trim()
          : widget.customerName.trim();

      final result = await _apiService.submitOrder(
        userId: widget.userId,
        partnerId: widget.partnerId,
        paymentType: paymentChoice,
        isPaid: false,
        lines: lines,
        branchId: branchId,
        customerName: displayName,
        customerPhone: _customerPhone.trim(),
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
      // Refresh both history (to show the new order) and profile (to update reward points)
      await Future.wait([_loadHistory(), _loadProfile()]);

      if (!mounted) return;
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
        // Email no longer shown in UI; keep sending if already populated.
        email: _customerEmail.trim().isEmpty ? null : _customerEmail.trim(),
        dateOfBirth: _customerDob.trim().isEmpty ? null : _customerDob.trim(),
      );

      if (!mounted) return;
      setState(() {
        _customerId = saved['id'] as int?;
        _customerName = (saved['name'] ?? _customerName).toString();
        _customerPhone = (saved['phone'] ?? _customerPhone).toString();
        _customerEmail = (saved['email'] ?? _customerEmail).toString();
        _customerDob =
            (saved['date_of_birth'] ?? saved['birthdate'] ?? _customerDob)
                .toString();
        _rewardPoints =
            int.tryParse(
              (saved['reward_points'] ?? _rewardPoints).toString(),
            ) ??
            _rewardPoints;
        _rewardRank = int.tryParse((saved['reward_rank'] ?? _rewardRank).toString()) ?? _rewardRank;
      });

      await _loadHistory();
      if (!mounted) return;
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

  void _openEditProfileSheet() {
    String name = _customerName;
    String phone = _customerPhone;
    String dob = _customerDob;

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
              bottom: 20 + _gestureNavBottomPad(context) - 8,
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
                      _buildProfileDateField(
                        label: 'DATE OF BIRTH',
                        value: dob,
                        onChanged: (val) => setSheetState(() => dob = val),
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
                                  _customerDob = dob;
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

  Widget _buildProfileDateField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final controller = TextEditingController(text: value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            prefixIcon: const Icon(Icons.cake_outlined, color: _brandNavy),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () async {
                final now = DateTime.now();
                DateTime initial = DateTime(now.year - 20, 1, 1);
                try {
                  final parts = value.split('-');
                  if (parts.length == 3) {
                    final y = int.parse(parts[0]);
                    final m = int.parse(parts[1]);
                    final d = int.parse(parts[2]);
                    initial = DateTime(y, m, d);
                  }
                } catch (_) {}

                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(1900, 1, 1),
                  lastDate: DateTime(now.year, now.month, now.day),
                );
                if (picked == null) return;
                final yyyy = picked.year.toString().padLeft(4, '0');
                final mm = picked.month.toString().padLeft(2, '0');
                final dd = picked.day.toString().padLeft(2, '0');
                final iso = '$yyyy-$mm-$dd';
                controller.text = iso;
                onChanged(iso);
              },
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _brandNavy, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rankPill(int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          Text(
            '#$rank',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF7C2D12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileNotificationTile() {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCE5FF)),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: _brandNavy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _brandNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pushNotificationsEnabled
                        ? 'Order updates on this device'
                        : 'Push alerts are turned off',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _pushNotificationsEnabled,
              activeThumbColor: _brandNavy,
              onChanged: (v) async {
                await PushNotificationsService.setCustomerPushEnabled(v);
                if (mounted) setState(() => _pushNotificationsEnabled = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCE5FF)),
                ),
                child: Icon(icon, color: _brandNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _brandNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing,
              ] else ...[
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openProductDetail(Product product) {
    if (product.blockSelfOrder) {
      _showSelfOrderBlockedMessage();
      return;
    }
    int qty = 1;
    List<Topping> selectedToppings = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
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
                      bottom: 16 + _gestureNavBottomPad(context),
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

  bool get _isAppBarRefreshBusy {
    return _isLoadingCatalog ||
        _isLoadingProfile ||
        _isLoadingHistory ||
        _isLoadingSelfOrderConfig ||
        _isLoadingBranches;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final isMobile = width < 600;
    final isSmall = width < 360;

    return Scaffold(
      backgroundColor: _brandNavy,
      appBar: AppBar(
        backgroundColor: _brandNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'LaDolce',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: _isAppBarRefreshBusy ? null : _onAppBarRefresh,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.refresh, size: 22),
            ),
          ),
        ],
      ),
      body: ColoredBox(
        color: _brandNavy,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: ColoredBox(
                    color: Colors.white,
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _buildHomeTab(isWide: isWide, isSmall: isSmall, isMobile: isMobile),
                        _buildCartTab(isSmall: isSmall),
                        _buildHistoryTab(isSmall: isSmall),
                        _buildProfileTab(isWide: isWide, isSmall: isSmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _selectedTabIndex == 0 && _cartCount > 0
          ? _buildStickyCartBar()
          : null,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: const NavigationBarThemeData(
            indicatorColor: Colors.transparent,
            elevation: 0,
            height: 64,
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedTabIndex = index),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: _navInactive),
              selectedIcon: _navSelectedIcon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: _cartCount > 0
                  ? Badge(
                      label: Text('$_cartCount'),
                      backgroundColor: Colors.red,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: _navInactive,
                      ),
                    )
                  : Icon(
                      Icons.shopping_bag_outlined,
                      color: _navInactive,
                    ),
              selectedIcon: _cartCount > 0
                  ? Badge(
                      label: Text('$_cartCount'),
                      backgroundColor: Colors.red,
                      child: _navSelectedIcon(Icons.shopping_bag),
                    )
                  : _navSelectedIcon(Icons.shopping_bag),
              label: 'Cart',
            ),
            NavigationDestination(
              icon: Icon(Icons.access_time, color: _navInactive),
              selectedIcon: _navSelectedIcon(Icons.access_time),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: _navInactive),
              selectedIcon: _navSelectedIcon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAppBarRefresh() async {
    await _refreshEverything();
  }

  Future<void> _refreshEverything() async {
    // Refresh all data like during initial login
    await Future.wait([
      _loadCatalog(),
      _loadProfile(),
      _loadHistory(),
      _loadSelfOrderConfig(),
      _loadBranches(),
    ]);
  }

  Widget _buildHomeTab({required bool isWide, required bool isSmall, bool isMobile = false}) {
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
    final showHighlights = _selectedCategory == 'All Items';
    final highlightsSlivers = <Widget>[
      if (showHighlights && _recommendedProducts.isNotEmpty)
        SliverToBoxAdapter(child: _buildRecommendedSlider(isSmall: isSmall, isWide: isWide)),
      if (showHighlights && _popularProducts.isNotEmpty)
        SliverToBoxAdapter(child: _buildPopularSlider(isSmall: isSmall, isWide: isWide)),
      SliverToBoxAdapter(child: _buildSectionHeader('All Products', isSmall: isSmall)),
    ];

    final sliverGrid = items.isEmpty
        ? const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No items found')))
        : SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isSmall ? 8 : 12,
              12,
              isSmall ? 8 : 12,
              isWide ? 12 : (_isCartEmpty ? 12 : 92),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 3 : (isMobile ? 1 : 2),
                mainAxisExtent: isMobile ? 100 : 120,
                crossAxisSpacing: isSmall ? 8 : 10,
                mainAxisSpacing: isSmall ? 8 : 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCard(
                  items[index],
                  isWide: isWide,
                  isSmall: isSmall,
                ),
                childCount: items.length,
              ),
            ),
          );

    if (!isWide) {
      return _buildMobileHomeSliver(
        isSmall: isSmall, 
        highlightsSlivers: highlightsSlivers,
        sliverGrid: sliverGrid,
      );
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
              Expanded(
                flex: 62,
                child: CustomScrollView(
                  slivers: [
                    ...highlightsSlivers,
                    sliverGrid,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 38,
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

  Widget _buildSectionHeader(String title, {required bool isSmall}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isSmall ? 12 : 16, 16, isSmall ? 12 : 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _brandNavy,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmall ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: _textPrimaryDark,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Big card slider for Recommended (image + name only, tappable)
  Widget _buildRecommendedSlider({required bool isSmall, required bool isWide}) {
    if (_recommendedProducts.isEmpty) return const SizedBox.shrink();
    // Card width: fill screen proportionally; 3 cards max
    // phone: ~(screenWidth - padding) / 1.35 to show partial 2nd card
    // tablet: ~(availableWidth) / 2.8 per card
    final hPad = isSmall ? 12.0 : 16.0;
    final cardHeight = isSmall ? 180.0 : 230.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recommended Products', isSmall: isSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: cardHeight,
          child: LayoutBuilder(builder: (context, constraints) {
            // Show ~1.4 cards on phone, ~2.2 on tablet so user knows it scrolls
            final cardWidth = isWide
                ? (constraints.maxWidth - hPad * 2) / 2.2
                : (constraints.maxWidth - hPad) / 1.4;
            return ListView.builder(
              padding: EdgeInsets.only(left: hPad, right: hPad),
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedProducts.length,
              itemBuilder: (context, index) {
                final product = _recommendedProducts[index];
                final blocked = product.blockSelfOrder;
                Uint8List? imgBytes;
                if (product.imageBase64 != null && product.imageBase64!.isNotEmpty) {
                  try { imgBytes = base64Decode(product.imageBase64!); } catch (_) {}
                }
                return GestureDetector(
                  onTap: blocked
                      ? _showSelfOrderBlockedMessage
                      : () => _openProductDetail(product),
                  child: Opacity(
                    opacity: blocked ? 0.55 : 1.0,
                    child: Container(
                      width: cardWidth,
                      margin: EdgeInsets.only(right: isSmall ? 10 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _brandNavy.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            // Full-card image
                            Positioned.fill(
                              child: imgBytes != null
                                  ? Image.memory(imgBytes, fit: BoxFit.cover)
                                  : Container(
                                      color: _brandNavy.withOpacity(0.08),
                                      child: const Icon(Icons.fastfood, size: 48, color: Color(0xFFCBD5E1)),
                                    ),
                            ),
                            // Gradient overlay at bottom
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.72),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  isSmall ? 10 : 14,
                                  20,
                                  isSmall ? 10 : 14,
                                  isSmall ? 10 : 14,
                                ),
                                child: Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: isSmall ? 13 : 15,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            // Recommended badge
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '⭐ Recommended',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isSmall ? 10 : 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Standard compact horizontal slider for Popular products
  Widget _buildPopularSlider({required bool isSmall, required bool isWide}) {
    if (_popularProducts.isEmpty) return const SizedBox.shrink();
    final cardHeight = isSmall ? 160.0 : 200.0;
    final cardWidth = isSmall ? 140.0 : 175.0;
    final hPad = isSmall ? 12.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Most Popular', isSmall: isSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            scrollDirection: Axis.horizontal,
            itemCount: _popularProducts.length,
            itemBuilder: (context, index) {
              final product = _popularProducts[index];
              final blocked = product.blockSelfOrder;
              Uint8List? imgBytes;
              if (product.imageBase64 != null && product.imageBase64!.isNotEmpty) {
                try { imgBytes = base64Decode(product.imageBase64!); } catch (_) {}
              }
              return GestureDetector(
                onTap: blocked
                    ? _showSelfOrderBlockedMessage
                    : () => _openProductDetail(product),
                child: Opacity(
                  opacity: blocked ? 0.55 : 1.0,
                  child: Container(
                    width: cardWidth,
                    margin: EdgeInsets.only(right: isSmall ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _brandNavy.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: imgBytes != null
                                ? Image.memory(imgBytes, fit: BoxFit.cover, width: double.infinity)
                                : Container(
                                    color: _brandNavy.withOpacity(0.07),
                                    child: const Center(
                                      child: Icon(Icons.fastfood, size: 36, color: Color(0xFFCBD5E1)),
                                    ),
                                  ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isSmall ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₭${product.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: isSmall ? 12 : 13,
                                      fontWeight: FontWeight.w700,
                                      color: _brandNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMobileHomeSliver({
    required bool isSmall,
    required List<Widget> highlightsSlivers,
    required Widget sliverGrid,
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
        ...highlightsSlivers,
        sliverGrid,
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
    final blocked = product.blockSelfOrder;
    return InkWell(
      onTap: () {
        if (blocked) {
          _showSelfOrderBlockedMessage();
          return;
        }
        if (isWide) {
          _setPreviewProduct(product);
        } else {
          _openProductDetail(product);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: blocked ? 0.55 : 1,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 104,
                      height: 104,
                      child: _buildProductImage(product),
                    ),
                  ),
                  if (blocked)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ColoredBox(
                          color: Colors.white.withOpacity(0.45),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.runOut ?? 'Run out',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: isSmall ? 10 : 11,
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
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
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₭${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: blocked ? Colors.grey : _brandNavy,
                            fontSize: isSmall ? 14 : 16,
                          ),
                        ),
                        if (!blocked)
                          Container(
                            width: isSmall ? 28 : 30,
                            height: isSmall ? 28 : 30,
                            decoration: BoxDecoration(
                              color: _brandNavy,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: isSmall ? 16 : 18,
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
          errorBuilder: (_, _, _) => _fallbackImage(),
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
        errorBuilder: (_, _, _) => _fallbackImage(),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12 + _gestureNavBottomPad(context),
      ),
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
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildCurrentCartPanel() {
    final product = _previewProduct;
    final previewBlocked = product?.blockSelfOrder ?? false;
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
      child: LayoutBuilder(builder: (context, constraints) {
        // Make image height proportional to available space
        final imgH = (constraints.maxHeight * 0.33).clamp(80.0, 180.0);
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — always visible
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
              // Content: no-product placeholder OR scrollable product details
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
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: imgH,
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
                              onChanged: previewBlocked
                                  ? (int _) {}
                                  : (newQty) => setState(() => _previewQty = newQty),
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
                            onPressed: previewBlocked || product.toppings.isEmpty
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
                            onPressed: previewBlocked
                                ? null
                                : () {
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
                              backgroundColor:
                                  previewBlocked ? Colors.grey : _brandNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              previewBlocked ? 'Run out' : 'Add to Cart',
                              style: const TextStyle(fontWeight: FontWeight.w900),
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
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  void _openToppingsPickerForPreview(Product product) {
    if (product.blockSelfOrder) {
      _showSelfOrderBlockedMessage();
      return;
    }
    if (product.toppings.isEmpty) return;
    final temp = List<Topping>.from(_previewToppings);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.72,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + _gestureNavBottomPad(ctx),
                ),
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
                        separatorBuilder: (_, _) =>
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
            separatorBuilder: (_, _) => const SizedBox(height: 12),
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
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + _gestureNavBottomPad(context),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      ],
    );
  }

  String _formatHistoryDateLabel(String? raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(d.toLocal());
  }

  String _formatHistoryTotalK(dynamic v) {
    final n = double.tryParse((v ?? 0).toString()) ?? 0.0;
    return 'K${n.toStringAsFixed(2)}';
  }

  Widget _navSelectedIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFFDBE7FF),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _brandNavy, size: 24),
    );
  }

  Widget _buildHistoryTab({bool isSmall = false}) {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_historyItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: _brandNavy.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 16),
              const Text(
                'No order history yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your completed orders will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _labelGray,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmall ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshEverything,
      color: _brandNavy,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        itemCount: _historyItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          final statusText = _friendlyStatus(
            (item['state'] ?? '').toString(),
            (item['payment_method'] ?? '').toString(),
          );
          final dateLabel =
              _formatHistoryDateLabel(item['date_order']?.toString());
          final pay = (item['payment_method'] ?? 'Unknown').toString();

          return Material(
            color: _historyCardBg,
            elevation: 0,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openHistoryDetail(item),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item['name']?.toString() ?? 'Order',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: _textPrimaryDark,
                            ),
                          ),
                        ),
                        Text(
                          _formatHistoryTotalK(item['amount_total']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _textPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _historyMetaRow('Payment method', pay),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            color: _labelGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        _historyStatusPill(statusText, item['state']?.toString() ?? ''),
                      ],
                    ),
                    if (dateLabel != '-') ...[
                      const SizedBox(height: 6),
                      _historyMetaRow('Date', dateLabel),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'View order details',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: Color(0xFF2563EB),
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
      ),
    );
  }

  Widget _historyMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _labelGray,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _textPrimaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _historyStatusPill(String friendly, String rawState) {
    final paid = rawState == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: paid ? const Color(0xFFDCF4E0) : const Color(0xFFFFE7CC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        paid ? 'Paid' : friendly,
        style: TextStyle(
          color: paid ? const Color(0xFF166534) : const Color(0xFFC2410C),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  String _friendlyStatus(String rawState, String paymentMethod) {
    if (rawState == 'waiting_transfer_review') {
      return 'Waiting transfer verification';
    }
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => CustomerOrderDetailScreen(
          item: item,
          api: _apiService,
          onRefresh: _loadHistory,
        ),
      ),
    );
  }

  Widget _buildProfileTab({bool isWide = false, bool isSmall = false}) {
    if (_isLoadingProfile) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brandNavy, _brandNavy2],
          ),
        ),
        child: const CustomPaint(
          painter: _LuxuryPatternPainter(),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 760;
        final customerMemoryImage = _customerMemoryImage();
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

        return SizedBox(
          height: constraints.maxHeight,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brandNavy, _brandNavy2],
              ),
            ),
            child: CustomPaint(
              painter: const _LuxuryPatternPainter(),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isSmall ? 12 : 16,
                        12,
                        isSmall ? 12 : 16,
                        8,
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
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _customerDob.isEmpty ? ' ' : 'DOB: $_customerDob',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
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
                                          _profileMenuTile(
                                            title: 'Profile',
                                            subtitle:
                                                '${_customerPhone.isEmpty ? '-' : _customerPhone}  •  DOB: ${_customerDob.isEmpty ? '-' : _customerDob}',
                                            icon: Icons.person_outline,
                                            onTap: _openEditProfileSheet,
                                          ),
                                          const SizedBox(height: 10),
                                          _profileNotificationTile(),
                                          const SizedBox(height: 10),
                                          _profileMenuTile(
                                            title: 'Ranking',
                                            subtitle: 'See Top 50 rewards leaderboard',
                                            icon: Icons.emoji_events_outlined,
                                            trailing: _rewardRank > 0
                                                ? _rankPill(_rewardRank)
                                                : null,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => RankingScreen(
                                                    myRank: _rewardRank <= 0 ? null : _rewardRank,
                                                    myPoints: _rewardPoints,
                                                    myName: _customerName,
                                                    myImageBase64: _customerImageBase64,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          _profileMenuTile(
                                            title: 'Customer support',
                                            subtitle: 'Facebook & WhatsApp (from store settings)',
                                            icon: Icons.support_agent_outlined,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => CustomerSupportScreen(
                                                    facebookUrl: _supportFacebookUrl,
                                                    whatsappNumber: _supportWhatsappNumber,
                                                    whatsappLink: _supportWhatsappLink,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSmall ? 12 : 16,
                      4,
                      isSmall ? 12 : 16,
                      _gestureNavBottomPad(context),
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
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0x55FFFFFF)),
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
