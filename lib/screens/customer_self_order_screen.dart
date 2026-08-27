import 'dart:convert';
import '../utils/bilingual_name.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' show sin, cos, sqrt, asin, pi;
import 'dart:ui' as ui;
import 'customer_support_screen.dart';
import 'ranking_screen.dart';
import '../services/push_notifications_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/http_client_wrapper.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import 'customer_order_detail_screen.dart';
import '../models/cart_item.dart';
import '../models/combo.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/skeleton_loaders.dart';
import 'login_screen.dart';
import 'order_chat_screen.dart';

class _FavoritePlace {
  final String id;
  final String name;
  final String address;
  final String placeId;
  final double? latitude;
  final double? longitude;
  final String mapsUrl;

  const _FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.placeId,
    this.latitude,
    this.longitude,
    this.mapsUrl = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'place_id': placeId,
    'latitude': latitude,
    'longitude': longitude,
    'maps_url': mapsUrl,
  };

  factory _FavoritePlace.fromJson(Map<String, dynamic> json) {
    return _FavoritePlace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      placeId: (json['place_id'] ?? '').toString(),
      latitude: double.tryParse((json['latitude'] ?? '').toString()),
      longitude: double.tryParse((json['longitude'] ?? '').toString()),
      mapsUrl: (json['maps_url'] ?? '').toString(),
    );
  }

  _FavoritePlace copyWith({
    String? id,
    String? name,
    String? address,
    String? placeId,
    double? latitude,
    double? longitude,
    String? mapsUrl,
  }) {
    return _FavoritePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapsUrl: mapsUrl ?? this.mapsUrl,
    );
  }
}

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
  /// Null-safe localisation lookup; every call site keeps its English
  /// literal as a fallback.
  AppLocalizations? get _l10n => AppLocalizations.of(context);

  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, Uint8List> _decodedImageCache = {};

  // Brand palette (based on bear logo)
  static const _brandNavy = Color(0xFF0D1565);
  static const _brandNavy2 = Color(0xFF142B8C);
  static const _brandSurface = Colors.white;
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
  bool _isDeletingAccount = false;
  bool _isLoadingSelfOrderConfig = true;

  String _selectedCategory = 'All Items';
  String? _catalogError;
  int _selectedTabIndex = 0;

  String? _appliedCouponCode;
  double _couponDiscount = 0.0;
  bool _isApplyingCoupon = false;
  final TextEditingController _couponController = TextEditingController();

  List<Product> _products = [];
  List<Product> _recommendedProducts = [];
  List<Product> _popularProducts = [];
  PageController? _recommendedPageController;
  Timer? _recommendedAutoSlideTimer;
  int _recommendedSlideIndex = 0;
  int _recommendedAutoSlideCount = 0;
  double _recommendedViewportFraction = 0.86;
  // Category id/name double as the matching key for the filter tabs, so this
  // stays English; the tab label is localised where it is rendered.
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

  // Delivery Fee Calculation
  double _deliveryFee = 0.0;
  bool _isFreeDeliveryTipApplicable = false;
  double _amountNeededForFreeDelivery = 0.0;
  double _currentDeliveryDistanceKm = 0.0;

  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371; // Earth radius in km
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _degreesToRadians(double degree) {
    return degree * pi / 180;
  }

  void _calculateDeliveryFee(bool isSelfPickup) {
    if (isSelfPickup) {
      _deliveryFee = 0.0;
      _isFreeDeliveryTipApplicable = false;
      _amountNeededForFreeDelivery = 0.0;
      _currentDeliveryDistanceKm = 0.0;
      return;
    }

    if (_selectedBranchId == null || _selectedFavoritePlaceId == null) {
      _deliveryFee = 0.0;
      _isFreeDeliveryTipApplicable = false;
      _amountNeededForFreeDelivery = 0.0;
      _currentDeliveryDistanceKm = 0.0;
      return;
    }

    // Find branch
    final branchMatches = _branches.where(
      (b) => _branchIdFromMap(b) == _selectedBranchId,
    );
    if (branchMatches.isEmpty) return;
    final branch = branchMatches.first;

    // Find favorite place
    final placeMatches = _favoritePlaces.where(
      (p) => p.id == _selectedFavoritePlaceId,
    );
    if (placeMatches.isEmpty) return;
    final place = placeMatches.first;

    final double bLat = (branch['latitude'] as num?)?.toDouble() ?? 0.0;
    final double bLon = (branch['longitude'] as num?)?.toDouble() ?? 0.0;
    final double pLat = place.latitude ?? 0.0;
    final double pLon = place.longitude ?? 0.0;

    if (bLat == 0.0 || bLon == 0.0 || pLat == 0.0 || pLon == 0.0) {
      _deliveryFee = 0.0;
      _isFreeDeliveryTipApplicable = false;
      _amountNeededForFreeDelivery = 0.0;
      _currentDeliveryDistanceKm = 0.0;
      return;
    }

    final double distanceKm = _calculateHaversineDistance(
      bLat,
      bLon,
      pLat,
      pLon,
    );
    _currentDeliveryDistanceKm = distanceKm;
    final double freeRadius =
        (branch['free_delivery_radius_km'] as num?)?.toDouble() ?? 0.0;
    final double minOrderAmount =
        (branch['min_order_amount_for_free_delivery'] as num?)?.toDouble() ??
        0.0;
    final double baseFee =
        (branch['base_rider_fee'] as num?)?.toDouble() ?? 0.0;

    final cartTotal = _cartTotal - _effectiveCouponDiscount;

    _isFreeDeliveryTipApplicable = false;
    _amountNeededForFreeDelivery = 0.0;

    // Check free delivery radius
    if (freeRadius > 0 && distanceKm <= freeRadius) {
      if (cartTotal >= minOrderAmount) {
        _deliveryFee = 0.0;
        return;
      } else {
        _deliveryFee = baseFee;
        _isFreeDeliveryTipApplicable = true;
        _amountNeededForFreeDelivery = minOrderAmount - cartTotal;
        return;
      }
    }

    // Outside free radius (or no free radius), use tiered rules
    final rulesRaw = branch['rider_fee_rules'] as List<dynamic>? ?? [];
    double calculatedFee = baseFee; // default if no rules match or exist

    if (rulesRaw.isNotEmpty) {
      // Sort rules by distance_km ascending
      final rules = rulesRaw.map((r) => r as Map<String, dynamic>).toList();
      rules.sort((a, b) {
        final da = (a['distance_km'] as num?)?.toDouble() ?? 0.0;
        final db = (b['distance_km'] as num?)?.toDouble() ?? 0.0;
        return da.compareTo(db);
      });

      bool ruleMatched = false;
      for (var r in rules) {
        final ruleDist = (r['distance_km'] as num?)?.toDouble() ?? 0.0;
        if (distanceKm <= ruleDist) {
          calculatedFee = (r['fee_amount'] as num?)?.toDouble() ?? 0.0;
          ruleMatched = true;
          break;
        }
      }

      // If distance is beyond all rules, apply the maximum rule's fee
      if (!ruleMatched) {
        calculatedFee = (rules.last['fee_amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    _deliveryFee = calculatedFee;
  }

  Product? _previewProduct;
  int _previewQty = 1;
  List<Topping> _previewToppings = [];

  int? _customerId;
  String _customerName = '';
  String _customerPhone = '';
  String _customerEmail = '';
  String _customerDob = '';
  String _clientId = '';
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
  // Monotonic counter mirroring PushNotificationsService._syncGeneration so
  // stale onFailure callbacks from superseded toggles are silently dropped.
  int _notifSyncToken = 0;
  bool _hasShownAdPopup = false;
  String? _profileImagePath;
  bool _isUploadingProfileImage = false;
  List<_FavoritePlace> _favoritePlaces = [];
  String? _selectedFavoritePlaceId;

  List<Map<String, dynamic>> _historyItems = [];
  Timer? _riderLocationTimer;
  final Map<String, Map<String, dynamic>> _riderLocations = {};

  // Branch selection (customer self-order)
  bool _isLoadingBranches = true;
  List<Map<String, dynamic>> _branches = const [];
  int? _selectedBranchId;
  bool _isRaining = false;

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Product.isCustomerMode = true;
    PushNotificationsService.setAppActive(true);
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
    _loadFavoritePlaces().then((_) {
      _checkAndApplyWeatherTheme();
    });
    _startRiderLocationPolling();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoadingBranches = true);
    final cachedId = await _apiService.getCachedCustomerBranchId();
    final cachedName = await _apiService.getCachedCustomerBranchName();
    try {
      var branches = <Map<String, dynamic>>[];
      try {
        branches = await _apiService.fetchBranchesPublic();
      } catch (_) {}
      if (branches.isEmpty) {
        try {
          branches = await _apiService.fetchBranches();
        } catch (_) {}
      }
      if (!mounted) return;

      int? selectedId = cachedId;
      String selectedName = (cachedName ?? '').trim();

      if (selectedId != null) {
        final match = branches.where((b) {
          return _branchIdFromMap(b) == selectedId;
        }).toList();
        if (match.isNotEmpty) {
          selectedName = _branchNameFromMap(match.first);
        } else {
          selectedId = null;
        }
      }
      if (selectedId == null && branches.isNotEmpty) {
        selectedId = _branchIdFromMap(branches.first);
        selectedName = _branchNameFromMap(branches.first);
      }
      if (branches.isEmpty && selectedId != null && selectedId > 0) {
        branches = [
          {
            'id': selectedId,
            'name': selectedName.isEmpty ? (_l10n?.branch ?? 'Branch') : selectedName,
          },
        ];
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
      _loadSelfOrderConfig();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (cachedId != null && cachedId > 0) {
          _branches = [
            {
              'id': cachedId,
              'name': (cachedName ?? '').trim().isEmpty
                  ? (_l10n?.branch ?? 'Branch')
                  : cachedName!.trim(),
            },
          ];
          _selectedBranchId = cachedId;
        } else {
          _branches = const [];
          _selectedBranchId = null;
        }
        _isLoadingBranches = false;
      });
      _loadSelfOrderConfig();
    }
  }

  int? _branchIdFromMap(Map<String, dynamic> branch) {
    for (final key in const ['id', 'branch_id', 'pos_branch_id']) {
      final raw = branch[key];
      final id = raw is int ? raw : int.tryParse('${raw ?? ''}');
      if (id != null && id > 0) return id;
    }
    return null;
  }

  String _branchNameFromMap(Map<String, dynamic> branch) {
    for (final key in const ['name', 'branch_name', 'display_name']) {
      final name = (branch[key] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return (_l10n?.branch ?? 'Branch');
  }

  bool _isBranchClosed(Map<String, dynamic> branch) {
    final open = (branch['open_time'] as num?)?.toDouble() ?? 0.0;
    final close = (branch['close_time'] as num?)?.toDouble() ?? 0.0;
    if (open == 0.0 && close == 0.0) {
      return false; // Not configured or always open
    }

    final nowLao = DateTime.now().toUtc().add(const Duration(hours: 7));
    final currentTime = nowLao.hour + (nowLao.minute / 60.0);

    if (open < close) {
      // Normal hours, e.g., 08:00 to 22:00
      return currentTime < open || currentTime > close;
    } else {
      // Overnight hours, e.g., 22:00 to 04:00 (next day)
      return currentTime < open && currentTime > close;
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
            builder: (_) => LoginScreen(
              infoMessage: (_l10n?.sessionExpired ?? 'Session expired. Please login again.'),
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
    Product.isCustomerMode = false;
    PushNotificationsService.setAppActive(false);
    _recommendedAutoSlideTimer?.cancel();
    _recommendedPageController?.dispose();
    _noteController.dispose();
    _riderLocationTimer?.cancel();
    super.dispose();
  }

  void _ensureRecommendedSliderController(double viewportFraction) {
    if (_recommendedPageController != null &&
        (_recommendedViewportFraction - viewportFraction).abs() < 0.001) {
      return;
    }
    final oldController = _recommendedPageController;
    _recommendedViewportFraction = viewportFraction;
    _recommendedPageController = PageController(
      viewportFraction: _recommendedViewportFraction,
    );
    oldController?.dispose();
  }

  void _startRecommendedAutoSlide(int itemCount) {
    if (itemCount <= 1) {
      _recommendedAutoSlideTimer?.cancel();
      _recommendedAutoSlideTimer = null;
      _recommendedAutoSlideCount = itemCount;
      return;
    }
    if (_recommendedAutoSlideTimer != null &&
        _recommendedAutoSlideCount == itemCount) {
      return;
    }
    _recommendedAutoSlideTimer?.cancel();
    _recommendedAutoSlideCount = itemCount;
    _recommendedAutoSlideTimer = Timer.periodic(const Duration(seconds: 3), (
      _,
    ) {
      final controller = _recommendedPageController;
      if (!mounted || controller == null || !controller.hasClients) return;
      _recommendedSlideIndex = (_recommendedSlideIndex + 1) % itemCount;
      controller.animateToPage(
        _recommendedSlideIndex,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    });
  }

  String get _profileImagePrefsKey =>
      'customer_profile_image_path_${widget.partnerId ?? widget.userId}';

  String get _favoritePlacesPrefsKey =>
      'customer_favorite_places_${widget.partnerId ?? widget.userId}';

  _FavoritePlace? get _selectedFavoritePlace {
    final id = _selectedFavoritePlaceId;
    if (id == null) return null;
    return _favoritePlaces.where((p) => p.id == id).firstOrNull;
  }

  Future<void> _loadFavoritePlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritePlacesPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final places = decoded
          .whereType<Map>()
          .map((m) => _FavoritePlace.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.id.isNotEmpty && p.address.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _favoritePlaces = places;
        if (places.isNotEmpty) {
          _selectedFavoritePlaceId = places.first.id;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveFavoritePlaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritePlacesPrefsKey,
      jsonEncode(_favoritePlaces.map((p) => p.toJson()).toList()),
    );
  }

  String get _googleMapsApiKey =>
      (dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '').trim();

  Future<bool> _checkWeatherIsBad(double lat, double lng) async {
    final key = _googleMapsApiKey;
    if (key.isEmpty) return false;
    try {
      final uri =
          Uri.https('weather.googleapis.com', '/v1/currentConditions:lookup', {
            'key': key,
            'location.latitude': lat.toString(),
            'location.longitude': lng.toString(),
            'unitsSystem': 'METRIC',
          });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;

      final weatherCondition = decoded['weatherCondition'];
      if (weatherCondition is! Map) return false;

      final type = (weatherCondition['type'] ?? '').toString().toUpperCase();
      final descriptionObj = weatherCondition['description'];
      final description = descriptionObj is Map
          ? (descriptionObj['text'] ?? '').toString().toLowerCase()
          : '';

      final badTypes = {
        'RAIN',
        'THUNDERSTORM',
        'WIND_AND_RAIN',
        'SNOW',
        'BLIZZARD',
        'HAIL',
        'STORM',
        'TORNADO',
        'HURRICANE',
        'TYPHOON',
        'CYCLONE',
        'HEAVY_RAIN',
        'SHOWER',
        'DRIZZLE',
        'FREEZING_RAIN',
        'ICE_PALLETS',
        'DUST',
        'SANDSTORM',
      };

      if (badTypes.contains(type)) {
        return true;
      }

      final badKeywords = [
        'rain',
        'storm',
        'thunder',
        'snow',
        'blizzard',
        'hail',
        'wind',
        'shower',
        'drizzle',
        'ฝน',
        'พายุ',
        'ຝົນ',
        'ພາຍຸ',
        'ລົມ',
      ];

      for (final keyword in badKeywords) {
        if (description.contains(keyword)) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkAndApplyWeatherTheme() async {
    double lat = 17.9757;
    double lng = 102.6130;

    // Attempt to use favorite place coordinates if available
    final selectedPlace = _selectedFavoritePlace;
    if (selectedPlace != null &&
        selectedPlace.latitude != null &&
        selectedPlace.longitude != null) {
      lat = selectedPlace.latitude!;
      lng = selectedPlace.longitude!;
    } else if (_favoritePlaces.isNotEmpty) {
      final firstPlace = _favoritePlaces.first;
      if (firstPlace.latitude != null && firstPlace.longitude != null) {
        lat = firstPlace.latitude!;
        lng = firstPlace.longitude!;
      }
    }

    final isBad = await _checkWeatherIsBad(lat, lng);
    if (mounted) {
      setState(() {
        _isRaining = isBad;
      });
      if (isBad) {
        _showBadWeatherSnackBar();
      }
    }
  }

  void _showBadWeatherSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.thunderstorm_rounded,
              color: Color(0xFFFBBF24),
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.weatherWarning ??
                    (_l10n?.weatherWarning ?? 'Due to bad weather, your delivery or rider may be delayed.'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: const Color(0xFF475569).withOpacity(0.4),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _searchGooglePlaces(String query) async {
    final key = _googleMapsApiKey;
    if (key.isEmpty || query.trim().length < 3) return const [];
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': query.trim(), 'key': key, 'types': 'geocode'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || decoded is! Map) return const [];
    final predictions = decoded['predictions'];
    if (predictions is! List) return const [];
    return predictions
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  Future<_FavoritePlace?> _fetchGooglePlaceDetails(
    Map<String, dynamic> prediction,
  ) async {
    final key = _googleMapsApiKey;
    final placeId = (prediction['place_id'] ?? '').toString();
    if (key.isEmpty || placeId.isEmpty) return null;
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
          'place_id': placeId,
          'fields': 'place_id,name,formatted_address,geometry,url',
          'key': key,
        });
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || decoded is! Map) return null;
    final result = decoded['result'];
    if (result is! Map) return null;
    final location = result['geometry'] is Map
        ? (result['geometry'] as Map)['location']
        : null;
    final lat = location is Map
        ? double.tryParse((location['lat'] ?? '').toString())
        : null;
    final lng = location is Map
        ? double.tryParse((location['lng'] ?? '').toString())
        : null;
    final name = (result['name'] ?? prediction['description'] ?? '').toString();
    final address =
        (result['formatted_address'] ?? prediction['description'] ?? '')
            .toString();
    return _FavoritePlace(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? address : name.trim(),
      address: address.trim(),
      placeId: placeId,
      latitude: lat,
      longitude: lng,
      mapsUrl: (result['url'] ?? '').toString(),
    );
  }

  String _mapsUrlForLatLng(LatLng latLng) =>
      'https://www.google.com/maps/search/?api=1&query=${latLng.latitude},${latLng.longitude}';

  Future<_FavoritePlace> _favoritePlaceFromLatLng(LatLng latLng) async {
    final key = _googleMapsApiKey;
    String name = 'Selected location';
    String address =
        '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
    String placeId =
        '${latLng.latitude.toStringAsFixed(6)},${latLng.longitude.toStringAsFixed(6)}';

    if (key.isNotEmpty) {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '${latLng.latitude},${latLng.longitude}',
        'key': key,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded is Map) {
        final results = decoded['results'];
        if (results is List && results.isNotEmpty && results.first is Map) {
          final result = Map<String, dynamic>.from(results.first as Map);
          final formatted = (result['formatted_address'] ?? '').toString();
          final reversePlaceId = (result['place_id'] ?? '').toString();
          if (formatted.trim().isNotEmpty) {
            address = formatted.trim();
            name = formatted.split(',').first.trim();
          }
          if (reversePlaceId.trim().isNotEmpty) {
            placeId = reversePlaceId.trim();
          }
        }
      }
    }

    return _FavoritePlace(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      address: address,
      placeId: placeId,
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      mapsUrl: _mapsUrlForLatLng(latLng),
    );
  }

  Future<void> _openAddFavoritePlaceSheet(StateSetter parentSetState) async {
    final searchController = TextEditingController();
    final labelController = TextEditingController();
    List<Map<String, dynamic>> predictions = [];
    bool isSearching = false;
    bool isResolvingMapTap = false;
    String? error;
    final selected = _selectedFavoritePlace;
    final fallbackLatLng = LatLng(
      selected?.latitude ?? 17.9757,
      selected?.longitude ?? 102.6331,
    );
    LatLng selectedLatLng = fallbackLatLng;
    _FavoritePlace? selectedPlace = selected;
    if (selected != null) {
      labelController.text = selected.name;
    }
    GoogleMapController? mapController;
    int cameraResolveToken = 0;
    String? sheetMapStyle;

    void savePlace(_FavoritePlace place) {
      setState(() {
        _favoritePlaces = [place, ..._favoritePlaces];
        _selectedFavoritePlaceId = place.id;
      });
      parentSetState(() {
        _selectedFavoritePlaceId = place.id;
        _calculateDeliveryFee(false);
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch(String value) async {
              setSheetState(() {
                isSearching = true;
                error = null;
              });
              try {
                final result = await _searchGooglePlaces(value);
                if (!context.mounted) return;
                setSheetState(() => predictions = result);
              } catch (e) {
                if (!context.mounted) return;
                setSheetState(() => error = 'Could not search for places. Please check your connection.');
              } finally {
                if (context.mounted) {
                  setSheetState(() => isSearching = false);
                }
              }
            }

            Future<void> loadMapStyle() async {
              try {
                final style = await rootBundle.loadString(
                  'assets/map_styles/night_elegant.json',
                );
                if (sheetCtx.mounted) {
                  setSheetState(() => sheetMapStyle = style);
                  if (mapController != null) {
                    mapController!.setMapStyle(style);
                  }
                }
              } catch (_) {}
            }

            Future<void> resolveMapCenter() async {
              final token = ++cameraResolveToken;
              setSheetState(() {
                selectedPlace = null;
                isResolvingMapTap = true;
                error = null;
              });
              try {
                final place = await _favoritePlaceFromLatLng(selectedLatLng);
                if (!sheetCtx.mounted || token != cameraResolveToken) return;
                setSheetState(() => selectedPlace = place);
              } catch (e) {
                if (!sheetCtx.mounted || token != cameraResolveToken) return;
                setSheetState(() => error = 'Could not read the selected address. Please try again.');
              } finally {
                if (sheetCtx.mounted && token == cameraResolveToken) {
                  setSheetState(() => isResolvingMapTap = false);
                }
              }
            }

            final screenHeight = MediaQuery.sizeOf(sheetCtx).height;
            final keyboardInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            final bottomPad = keyboardInset + _gestureNavBottomPad(sheetCtx);
            final maxSheetHeight = screenHeight - bottomPad - 32;
            final sheetHeight = maxSheetHeight < 320
                ? maxSheetHeight
                : maxSheetHeight.clamp(320.0, screenHeight * 0.86).toDouble();

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
              child: SizedBox(
                height: sheetHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_l10n?.addFavoritePlace ?? (_l10n?.addFavoritePlace ?? 'Add favorite place'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: _l10n?.searchAddressOrPlace ?? (_l10n?.searchAddressOrPlace ?? 'Search address or place'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.trim().length < 3) {
                          setSheetState(() => predictions = []);
                          return;
                        }
                        Future.delayed(const Duration(milliseconds: 350), () {
                          if (searchController.text == value) {
                            runSearch(value);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: labelController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: _l10n?.nameThisPlace ?? (_l10n?.nameThisPlace ?? 'Name this place, e.g. House'),
                        prefixIcon: const Icon(Icons.bookmark_border),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: ['House', 'Work', 'Friend house']
                          .map(
                            (label) => ActionChip(
                              label: Text(label),
                              onPressed: () {
                                labelController.text = label;
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    if (predictions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: predictions.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = predictions[index];
                            final title =
                                (p['structured_formatting'] is Map
                                        ? (p['structured_formatting']
                                              as Map)['main_text']
                                        : null)
                                    ?.toString() ??
                                (p['description'] ?? '').toString();
                            final subtitle =
                                (p['structured_formatting'] is Map
                                        ? (p['structured_formatting']
                                              as Map)['secondary_text']
                                        : null)
                                    ?.toString() ??
                                '';
                            return ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(title),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : Text(subtitle),
                              onTap: () async {
                                final place = await _fetchGooglePlaceDetails(p);
                                if (place == null) return;
                                final latLng =
                                    place.latitude != null &&
                                        place.longitude != null
                                    ? LatLng(place.latitude!, place.longitude!)
                                    : selectedLatLng;
                                selectedLatLng = latLng;
                                selectedPlace = place;
                                searchController.text = place.name;
                                setSheetState(() => predictions = []);
                                await mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(latLng, 17),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: selectedLatLng,
                                zoom: 15,
                              ),
                              gestureRecognizers: {
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              onMapCreated: (controller) {
                                mapController = controller;
                                if (sheetMapStyle != null) {
                                  controller.setMapStyle(sheetMapStyle);
                                } else {
                                  loadMapStyle();
                                }
                              },
                              onCameraMove: (position) {
                                selectedLatLng = position.target;
                              },
                              onCameraIdle: resolveMapCenter,
                            ),
                            const IgnorePointer(
                              child: Icon(
                                Icons.location_pin,
                                size: 46,
                                color: Colors.redAccent,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.transparent,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x22000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () async {
                                      try {
                                        final locationEnabled =
                                            await Geolocator.isLocationServiceEnabled();
                                        if (!locationEnabled) {
                                          if (sheetCtx.mounted) {
                                            setSheetState(
                                              () => error =
                                                  'Location services are disabled. Please enable them in Settings.',
                                            );
                                          }
                                          return;
                                        }
                                        final status =
                                            await Geolocator.checkPermission();
                                        if (status ==
                                            LocationPermission.denied) {
                                          final req =
                                              await Geolocator.requestPermission();
                                          if (req ==
                                              LocationPermission.denied) {
                                            if (sheetCtx.mounted) {
                                              setSheetState(
                                                () => error =
                                                    'Location permission denied.',
                                              );
                                            }
                                            return;
                                          }
                                        }
                                        if (status ==
                                            LocationPermission.deniedForever) {
                                          if (sheetCtx.mounted) {
                                            setSheetState(
                                              () => error =
                                                  'Location permission permanently denied. Please enable it in Settings.',
                                            );
                                          }
                                          return;
                                        }
                                        final pos =
                                            await Geolocator.getCurrentPosition(
                                              locationSettings:
                                                  const LocationSettings(
                                                    accuracy:
                                                        LocationAccuracy.high,
                                                    timeLimit: Duration(
                                                      seconds: 10,
                                                    ),
                                                  ),
                                            );
                                        final latLng = LatLng(
                                          pos.latitude,
                                          pos.longitude,
                                        );
                                        selectedLatLng = latLng;
                                        await mapController?.animateCamera(
                                          CameraUpdate.newLatLngZoom(
                                            latLng,
                                            17,
                                          ),
                                        );
                                      } catch (_) {
                                        if (sheetCtx.mounted) {
                                          setSheetState(
                                            () => error =
                                                'Could not get current location. Please allow location access and try again.',
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.my_location,
                                        color: Color(0xFF0D1565),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(999),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x22000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(_l10n?.moveMapToPlacePin ?? (_l10n?.moveMapToPlacePin ?? 'Move the map to place the pin'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _brandNavy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            color: selectedPlace == null
                                ? Colors.grey
                                : _brandNavy,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isResolvingMapTap
                                  ? (_l10n?.readingSelectedAddress ?? 'Reading selected address...')
                                  : selectedPlace?.address ??
                                        'Search or move the map to select a place.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: selectedPlace == null || isResolvingMapTap
                            ? null
                            : () async {
                                final customName = labelController.text.trim();
                                final place = selectedPlace!.copyWith(
                                  name: customName.isEmpty
                                      ? selectedPlace!.name
                                      : customName,
                                );
                                savePlace(place);
                                await _saveFavoritePlaces();
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }
                              },
                        icon: const Icon(Icons.check),
                        label: Text(_l10n?.addSelectedPlace ?? (_l10n?.addSelectedPlace ?? 'Add selected place')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandNavy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
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
      },
    );
  }

  Future<void> _deleteFavoritePlace(
    _FavoritePlace place,
    StateSetter? parentSetState,
  ) async {
    setState(() {
      _favoritePlaces = _favoritePlaces.where((p) => p.id != place.id).toList();
      if (_selectedFavoritePlaceId == place.id) {
        _selectedFavoritePlaceId = _favoritePlaces.isNotEmpty
            ? _favoritePlaces.first.id
            : null;
      }
    });
    parentSetState?.call(() {});
    await _saveFavoritePlaces();
  }

  String get _favoritePlacesSubtitle {
    if (_favoritePlaces.isEmpty) return (_l10n?.addDeliveryPlaces ?? 'Add delivery places for self order');
    final selected = _selectedFavoritePlace;
    final count = _favoritePlaces.length;
    final label = selected?.name ?? _favoritePlaces.first.name;
    return count == 1 ? label : '$label  •  $count saved';
  }

  void _openFavoritePlacesSheet() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _FavoritePlacesScreen(
          favoritePlaces: _favoritePlaces,
          selectedPlaceId: _selectedFavoritePlaceId,
          onSelectPlace: (id) {
            setState(() => _selectedFavoritePlaceId = id);
            _apiService.saveSelectedFavoritePlace(id);
          },
          onDeletePlace: (place) => _deleteFavoritePlace(place, null),
          onAddPlace: () {
            Navigator.pop(ctx);
            _openAddFavoritePlaceSheet(setState);
          },
        ),
      ),
    ).then((changed) {
      if (changed == true && mounted) setState(() {});
    });
  }

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
        // Avatars render at a few hundred px; sending a full 12MP photo as
        // base64 inside a JSON body is what made this save fail.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
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
          name: _customerName.trim().isEmpty
              ? (_l10n?.roleCustomer ?? 'Customer')
              : _customerName.trim(),
          phone: _cleanProfileText(_customerPhone),
          email: _cleanProfileText(_customerEmail).isEmpty
              ? null
              : _cleanProfileText(_customerEmail),
          dateOfBirth: _customerDob.trim().isEmpty ? null : _customerDob.trim(),
          imageBase64: b64,
        );
        if (!mounted) return;
        setState(() {
          _customerImageBase64 = saved['image_base64']?.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n?.profileImageUpdated ?? (_l10n?.profileImageUpdated ?? 'Profile image updated')),
            backgroundColor: Colors.green,
          ),
        );
      } catch (_) {
        // Keep local image; backend upload is best-effort.
      } finally {
        if (mounted) setState(() => _isUploadingProfileImage = false);
      }
    } on PlatformException catch (e) {
      // Silently ignore 'already_active' — user tapped the picker button twice.
      if (e.code == 'already_active') return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.couldNotOpenImagePicker ?? (_l10n?.couldNotOpenImagePicker ?? 'Could not open the image picker. Please try again.')),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.couldNotOpenImagePicker ?? (_l10n?.couldNotOpenImagePicker ?? 'Could not open the image picker. Please try again.')),
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

  String _cleanProfileText(dynamic value) {
    final text = (value ?? '').toString().trim();
    final lower = text.toLowerCase();
    if (text.isEmpty ||
        lower == 'false' ||
        lower == 'null' ||
        lower == 'none') {
      return '';
    }
    return text;
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
        branchId: _selectedBranchId,
        limit: 200,
        forceRefresh: true,
      );
      final rawCombos = await _apiService.fetchCombos();
      final combos = rawCombos
          .map((c) => Product.fromCombo(Combo.fromJson(c)))
          .toList();
      products.addAll(combos);

      final categorySet = products.map((p) => p.category).toSet();
      final categories = [
        Category(id: 'All', name: (_l10n?.allItems ?? 'All Items')),
        ...categorySet.map((name) => Category(id: name, name: name)),
      ];

      final highlights = await _apiService.fetchProductHighlights(branchId: _selectedBranchId);
      final recIds = highlights['recommended'] ?? [];
      final popIds = highlights['popular'] ?? [];

      final recommendedProducts = products
          .where((p) => recIds.contains(p.id))
          .toList();
      final popularProducts = products
          .where((p) => popIds.contains(p.id))
          .toList();

      if (!mounted) return;
      final oldPreviewId = _previewProduct?.id;
      Product? nextPreview = _previewProduct;
      if (nextPreview != null) {
        final match = products
            .where((p) => p.id == nextPreview!.id)
            .firstOrNull;
        if (match == null || match.blockSelfOrder) {
          nextPreview = null;
        } else {
          nextPreview = match;
        }
      }
      nextPreview ??= products.where((p) => !p.blockSelfOrder).firstOrNull;

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

  void _updateProfileState(Map<String, dynamic> matched) {
    if (!mounted) return;
    setState(() {
      _customerId = matched['id'] as int?;
      final matchedName = _cleanProfileText(matched['name']);
      _customerName = matchedName.isNotEmpty
          ? matchedName
          : widget.customerName;
      _customerPhone = _cleanProfileText(matched['phone']);
      _customerEmail = _cleanProfileText(matched['email']);
      _clientId = _cleanProfileText(matched['client_id']);
      final matchedDob = _cleanProfileText(matched['date_of_birth']);
      _customerDob = matchedDob.isNotEmpty
          ? matchedDob
          : _cleanProfileText(matched['birthdate']);
      _rewardPoints =
          int.tryParse((matched['reward_points'] ?? 0).toString()) ?? 0;
      _rewardRank = int.tryParse((matched['reward_rank'] ?? 0).toString()) ?? 0;
      _customerImageBase64 = matched['image_base64']?.toString();
    });
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      // 1. Try reading from cache first (no network request, instant load)
      final cachedCustomers = await _apiService.fetchCustomers(
        forceRefresh: false,
      );
      Map<String, dynamic>? matched;

      if (widget.partnerId != null) {
        for (final c in cachedCustomers) {
          if (c is Map<String, dynamic> && c['id'] == widget.partnerId) {
            matched = c;
            break;
          }
        }
      }

      if (matched != null) {
        _updateProfileState(matched);
      }

      // 2. Fetch fresh data from the server and update cache & UI
      final freshCustomers = await _apiService.fetchCustomers(
        forceRefresh: true,
      );
      Map<String, dynamic>? freshMatched;
      if (widget.partnerId != null) {
        for (final c in freshCustomers) {
          if (c is Map<String, dynamic> && c['id'] == widget.partnerId) {
            freshMatched = c;
            break;
          }
        }
      }

      if (freshMatched != null) {
        _updateProfileState(freshMatched);
      } else if (matched == null) {
        // Fallback if not found anywhere yet
        _updateProfileState({
          'id': widget.partnerId,
          'name': widget.customerName,
          'phone': '',
          'email': '',
          'date_of_birth': '',
          'birthdate': '',
          'reward_points': 0,
        });
      }
      setState(() => _isLoadingProfile = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    setState(() => _isLoadingHistory = true);
    try {
      final List<Map<String, dynamic>> serverHistory;
      if (widget.partnerId != null) {
        serverHistory = await _apiService.fetchCustomerOrders(
          widget.partnerId!,
        );
      } else {
        serverHistory = await _apiService.fetchReceiptHistory(
          forceRefresh: forceRefresh,
        );
      }
      if (forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('customer_self_order_history');
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
          'payment_method': item['payment_method'] ?? (_l10n?.unknown ?? 'Unknown'),
          'state': item['state'] ?? 'paid',
          'delivery_status': item['delivery_status'] ?? 'none',
          'delivery_latitude': item['delivery_latitude'],
          'delivery_longitude': item['delivery_longitude'],
          'delivery_maps_url': item['delivery_maps_url'],
          'customer': item['customer'] ?? '',
          'transfer_proof_url': item['transfer_proof_url'],
          'lines': item['lines'] ?? const [],
        };
      }).toList();

      final List<Map<String, dynamic>> filteredServer = [];
      final mine = _customerName.trim().toLowerCase();
      final isGenericName =
          mine.isEmpty ||
          mine == 'customer' ||
          mine == 'guest' ||
          mine == 'anonymous';

      final localKeys = localHistory.map((item) {
        final idKey = item['id']?.toString() ?? '';
        final nameKey = (item['name'] ?? '').toString();
        return idKey.isNotEmpty && idKey != '0' ? 'id:$idKey' : 'name:$nameKey';
      }).toSet();

      for (final item in normalizedServer) {
        final idKey = item['id']?.toString() ?? '';
        final nameKey = (item['name'] ?? '').toString();
        final key = idKey.isNotEmpty && idKey != '0'
            ? 'id:$idKey'
            : 'name:$nameKey';

        if (localKeys.contains(key)) {
          filteredServer.add(item);
          continue;
        }

        if (widget.partnerId != null) {
          filteredServer.add(item);
        } else if (!isGenericName) {
          final c = (item['customer'] ?? '').toString().trim().toLowerCase();
          if (c == mine && mine.isNotEmpty) {
            filteredServer.add(item);
          }
        }
      }

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
          final existingProofPath = (existing['proof_image_path'] ?? '')
              .toString()
              .trim();
          final mergedProofUrl = (merged['transfer_proof_url'] ?? '')
              .toString()
              .trim();
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

  void _startRiderLocationPolling() {
    _riderLocationTimer?.cancel();
    _pollRiderLocations();
    _riderLocationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _pollRiderLocations(),
    );
  }

  Future<void> _pollRiderLocations() async {
    final activeOrders = _historyItems.where((item) {
      final ds = (item['delivery_status'] ?? '').toString().toLowerCase();
      return ds == 'on_the_way' || ds == 'arrived';
    }).toList();
    if (activeOrders.isEmpty) return;
    for (final order in activeOrders) {
      final id = order['id'];
      if (id == null) continue;
      try {
        final loc = await _apiService.fetchRiderLocation(id.toString());
        if (loc != null && mounted) {
          setState(() {
            _riderLocations[id.toString()] = Map<String, dynamic>.from(loc);
          });
        }
      } catch (_) {
        // best-effort
      }
    }
  }

  Map<String, double>? _parseLatLngFromUrl(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      String? q = uri.queryParameters['q'] ?? uri.queryParameters['query'];
      if (q != null) {
        final parts = q.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            return {'latitude': lat, 'longitude': lng};
          }
        }
      }

      final match = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }
    } catch (_) {}
    return null;
  }

  void _openRiderMap(String orderId) {
    final order = _historyItems.cast<Map<String, dynamic>?>().firstWhere(
      (o) => (o?['id']?.toString() ?? '') == orderId,
      orElse: () => null,
    );
    double? destLat;
    double? destLng;
    if (order != null) {
      final rawLat = order['delivery_latitude'];
      final rawLng = order['delivery_longitude'];
      if (rawLat != null) {
        destLat = (rawLat is num)
            ? rawLat.toDouble()
            : double.tryParse(rawLat.toString());
      }
      if (rawLng != null) {
        destLng = (rawLng is num)
            ? rawLng.toDouble()
            : double.tryParse(rawLng.toString());
      }

      final mapsUrl = order['delivery_maps_url']?.toString() ?? '';
      if ((destLat == null ||
              destLng == null ||
              destLat == 0.0 ||
              destLng == 0.0) &&
          mapsUrl.isNotEmpty) {
        final parsed = _parseLatLngFromUrl(mapsUrl);
        if (parsed != null) {
          destLat = parsed['latitude'];
          destLng = parsed['longitude'];
        }
      }
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RiderTrackingSheet(
        orderId: orderId,
        apiService: _apiService,
        initialLocation: _riderLocations[orderId],
        destinationLat: destLat,
        destinationLng: destLng,
      ),
    );
  }

  Future<void> _loadSelfOrderConfig() async {
    if (mounted) {
      setState(() => _isLoadingSelfOrderConfig = true);
    }
    try {
      final config = await _apiService.fetchSelfOrderConfig(
        branchId: _selectedBranchId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        final rawBanks = (config['banks'] as List?) ?? const [];
        _transferBanks = rawBanks
            .whereType<Map>()
            .map((b) => Map<String, dynamic>.from(b))
            .toList();

        // ── select default bank ──
        if (_transferBanks.isNotEmpty) {
          final defaultIdx = _transferBanks.indexWhere(
            (b) => b['is_default'] == true,
          );
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

        // Pre-decode images to avoid lag during first display
        for (final url in _bannerImageDataUrls) {
          _bytesFromDataUrl(url);
        }
        for (final url in _adImageDataUrls) {
          _bytesFromDataUrl(url);
        }

        if (_adImageDataUrls.isEmpty &&
            (config['ad_enabled'] ?? true) == true) {
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
    if (_decodedImageCache.containsKey(dataUrl)) {
      return _decodedImageCache[dataUrl];
    }

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

  Uint8List? _bytesFromBase64(String b64) {
    if (b64.isEmpty) return null;
    if (_decodedImageCache.containsKey(b64)) return _decodedImageCache[b64];
    try {
      final bytes = base64Decode(b64);
      _decodedImageCache[b64] = bytes;
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
              final heightFrac = orientation == Orientation.landscape
                  ? 0.38
                  : 0.5;
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
                              final bytes = _bytesFromDataUrl(
                                _adImageDataUrls[index],
                              );
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
                          onTap: () =>
                              Navigator.of(context).pop(dontShowToday.value),
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 34,
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

  Future<void> _downloadQrCode([
    ScaffoldMessengerState? feedbackMessenger,
  ]) async {
    void showSnack(SnackBar snackBar) {
      if (!mounted) return;
      final messenger = feedbackMessenger ?? ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: snackBar.content,
          backgroundColor: snackBar.backgroundColor,
          duration: snackBar.duration,
          action: snackBar.action,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        ),
      );
    }

    try {
      final Uint8List? bytes = _qrBytesFromDataUrl();
      if (bytes == null || bytes.isEmpty) {
        showSnack(
          SnackBar(
            content: Text(_l10n?.noQrImageConfigured ?? (_l10n?.noQrImageConfigured ?? 'No QR image configured yet')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ── permissions ──────────────────────────────────────────
      if (Platform.isIOS) {
        final status = await Permission.photosAddOnly.request();
        if (!status.isGranted && !status.isLimited) {
          if (!mounted) return;
          final blocked = status.isPermanentlyDenied || status.isRestricted;
          showSnack(
            SnackBar(
              content: Text(
                blocked
                    ? (_l10n?.photosPermissionBlocked ?? 'Photos permission is blocked. Open Settings to allow access.')
                    : (_l10n?.photoPermissionRequired ?? 'Photo permission is required to save QR'),
              ),
              action: blocked
                  ? SnackBarAction(
                      label: _l10n?.settings ?? (_l10n?.settings ?? 'Settings'),
                      onPressed: openAppSettings,
                    )
                  : null,
            ),
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
            showSnack(
              SnackBar(
                content: Text(_l10n?.storagePermissionRequired ?? (_l10n?.storagePermissionRequired ?? 'Storage permission is required to save QR')),
              ),
            );
            return;
          }
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      dynamic result;
      if (Platform.isIOS) {
        // iOS is more reliable with raw bytes saving directly to Photos.
        result = await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name: 'la_dolce_qr_$timestamp',
        );
      } else {
        // ── Android: save via temp file → GallerySaver ─────────
        final tempDir = await getTemporaryDirectory();
        final filename = 'la_dolce_qr_$timestamp.png';
        final tempFile = File('${tempDir.path}/$filename');
        await tempFile.writeAsBytes(bytes, flush: true);
        result = await ImageGallerySaverPlus.saveFile(
          tempFile.path,
          name: 'la_dolce_qr_$timestamp',
        );
        // cleanup
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      debugPrint('Gallery save result: $result');

      if (!mounted) return;

      // ── check result more robustly ────────────────────────────
      final isSuccess =
          result is Map &&
          ((result['isSuccess'] == true) ||
              (result['success'] == true) ||
              (result['filePath'] != null &&
                  (result['filePath'] as String).isNotEmpty));

      if (isSuccess) {
        showSnack(
          SnackBar(
            content: Text(_l10n?.qrSavedToGallery ?? (_l10n?.qrSavedToGallery ?? 'QR saved to gallery ✓')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Fallback: save to Downloads folder directly
        await _saveQrToDownloads(bytes, feedbackMessenger: feedbackMessenger);
      }
    } catch (e) {
      debugPrint('_downloadQrCode error: $e');
      if (!mounted) return;
      showSnack(
        SnackBar(
          content: Text(_l10n?.couldNotSaveQr ?? (_l10n?.couldNotSaveQr ?? 'Could not save QR code. Please try again.')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── fallback: save directly to Downloads ─────────────────────
  Future<void> _saveQrToDownloads(
    Uint8List bytes, {
    ScaffoldMessengerState? feedbackMessenger,
  }) async {
    void showSnack(SnackBar snackBar) {
      if (!mounted) return;
      final messenger = feedbackMessenger ?? ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: snackBar.content,
          backgroundColor: snackBar.backgroundColor,
          duration: snackBar.duration,
          action: snackBar.action,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        ),
      );
    }

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

      final filename =
          'la_dolce_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('Saved to: ${file.path}');

      if (!mounted) return;
      showSnack(
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
      showSnack(
        SnackBar(content: Text(_l10n?.couldNotSaveQrDownloads ?? (_l10n?.couldNotSaveQrDownloads ?? 'Could not save QR to Downloads. Please try again.')), backgroundColor: Colors.red),
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
    return (product.effectivePrice + extra) * qty;
  }

  void _showSelfOrderBlockedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n?.itemRunOut ?? (_l10n?.itemRunOut ?? 'This item is run out and cannot be ordered.')),
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
    bool isRedeemed = false,
  }) {
    if (product.blockSelfOrder) return;
    final selectedIds = selectedToppings.map((t) => t.id).toSet();
    final index = _cartItems.indexWhere((item) {
      if (item.product.id != product.id) return false;
      if (item.isRedeemed != isRedeemed) return false;
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
            isRedeemed: isRedeemed,
            pointPrice: isRedeemed ? product.pointPrice : 0,
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

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isApplyingCoupon = true);
    try {
      final res = await _apiService.validateCoupon(
        code,
        partnerId: widget.partnerId,
      );
      setState(() {
        _appliedCouponCode = code;
        _couponDiscount =
            double.tryParse((res['discount_amount'] ?? 0).toString()) ?? 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n?.couponApplied ?? (_l10n?.couponApplied ?? 'Coupon applied successfully!')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _appliedCouponCode = null;
        _couponDiscount = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplyingCoupon = false);
      }
    }
  }

  void _removeCoupon() {
    setState(_clearCouponState);
  }

  /// Lets the customer attach a preparation note to one cart line, e.g.
  /// "sugar 50%". Stored on CartItem.kitchenNote, the same field the POS uses
  /// for its own kitchen notes, so the cashier and kitchen ticket render it
  /// exactly as a staff-entered note.
  Future<void> _editItemNote(CartItem item) async {
    // The dialog owns its TextEditingController. Creating it here and disposing
    // it once showDialog returns pulls it out from under the TextField while the
    // route is still animating out, which breaks the dialog's teardown and
    // trips InheritedElement's `_dependents.isEmpty` assertion.
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _ItemNoteDialog(
        initialNote: item.kitchenNote,
        title: _l10n?.noteForKitchen ?? 'Note for the kitchen',
        hint:
            _l10n?.kitchenNoteHint ?? 'Less sugar, no ice, extra spicy...',
        removeLabel: _l10n?.remove ?? 'Remove',
        cancelLabel: _l10n?.cancel ?? 'Cancel',
        saveLabel: _l10n?.save ?? 'Save',
      ),
    );
    if (result == null) return; // dismissed / cancelled
    if (!mounted) return;
    setState(() => item.kitchenNote = result.trim());
  }

  /// Builds the order-level note sent to Odoo.
  ///
  /// Per-item notes are NOT folded in here: they travel on each line as
  /// `note`, which pos_backend stores on pos.order.line.note ('Kitchen Note')
  /// and returns from both /self_orders/pending and /open_tickets, so the
  /// cashier already sees them per item. Duplicating them here would print the
  /// same request twice.
  ///
  /// This exists to stop '[SELF-PICKUP]' from replacing what the customer
  /// typed, which previously discarded their note entirely on pickup orders.
  String? _composeOrderNote({
    required bool isSelfPickup,
    required String? customerNote,
  }) {
    final parts = <String>[];
    if (isSelfPickup) parts.add('[SELF-PICKUP]');
    final typed = (customerNote ?? '').trim();
    if (typed.isNotEmpty) parts.add(typed);
    return parts.isEmpty ? null : parts.join(' | ');
  }

  /// A coupon can never discount more than the cart it applies to. Reducing
  /// quantities after applying one used to drive the displayed total — and the
  /// amount_total posted to Odoo — negative.
  double get _effectiveCouponDiscount =>
      _couponDiscount > _cartTotal ? _cartTotal : _couponDiscount;

  /// Drops the applied coupon. Must run whenever the cart is emptied as well as
  /// on explicit removal: a coupon is spent by the order that used it, and
  /// leaving it set carried the old discount into the next order and sent a
  /// stale code to the backend.
  ///
  /// Call inside a setState.
  void _clearCouponState() {
    _appliedCouponCode = null;
    _couponDiscount = 0.0;
    _couponController.clear();
  }

  void _showCheckoutOptions() {
    if (_cartItems.isEmpty || _isPlacingOrder) return;

    if (_customerPhone.trim().isEmpty) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(_l10n?.phoneNumberRequiredTitle ?? (_l10n?.phoneNumberRequiredTitle ?? 'Phone Number Required')),
          content: Text(_l10n?.verifiedPhoneRequired ?? (_l10n?.verifiedPhoneRequired ?? 'A verified phone number is required before placing an order. Please update your profile.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l10n?.cancel ?? (_l10n?.cancel ?? 'Cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openEditProfileSheet();
              },
              child: Text(_l10n?.updateProfile ?? (_l10n?.updateProfile ?? 'Update Profile')),
            ),
          ],
        ),
      );
      return;
    }

    _noteController.clear();
    String paymentChoice = 'transfer';
    XFile? proofImage;
    bool isSelfPickup = false;
    _calculateDeliveryFee(isSelfPickup);
    final sheetMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
            final selectedBranchMap = _branches.firstWhere(
              (b) => _branchIdFromMap(b) == _selectedBranchId,
              orElse: () => const <String, dynamic>{},
            );
            final bool isClosed = selectedBranchMap.isNotEmpty && _isBranchClosed(selectedBranchMap);
            final bool hasBranch =
                _selectedBranchId != null && (_selectedBranchId ?? 0) > 0 && !isClosed;
            final bool hasPlace =
                isSelfPickup || _selectedFavoritePlace != null;
            final bool canConfirm =
                hasBranch &&
                hasPlace &&
                (paymentChoice != 'transfer' || proofImage != null);
            final bottomInset =
                MediaQuery.viewInsetsOf(ctx).bottom + _gestureNavBottomPad(ctx);
            return ScaffoldMessenger(
              key: sheetMessengerKey,
              child: Stack(
                children: [
                  Padding(
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
                                      AppLocalizations.of(
                                            context,
                                          )?.choosePaymentMethod ??
                                          (_l10n?.choosePaymentMethod ?? 'Choose Payment Method'),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.selectBranch ??
                                          (_l10n?.selectBranch ?? 'Select Branch'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_isLoadingBranches)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (_branches.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.noBranchesFound ??
                                              (_l10n?.noBranchesFound ?? 'No branches found. Please ask staff.'),
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedBranchId,
                                            isExpanded: true,
                                            items: _branches.map((b) {
                                              final id =
                                                  _branchIdFromMap(b) ?? 0;
                                              final name = _branchNameFromMap(
                                                b,
                                              );
                                              final code = (b['code'] ?? '')
                                                  .toString()
                                                  .trim();
                                              final closed = _isBranchClosed(b);
                                              final label = code.isNotEmpty
                                                  ? '$name ($code)${closed ? " - [CLOSED]" : ""}'
                                                  : '$name${closed ? " - [CLOSED]" : ""}';
                                              return DropdownMenuItem<int>(
                                                value: id,
                                                child: Text(
                                                  label,
                                                  style: TextStyle(
                                                    color: closed ? Colors.red : null,
                                                    fontWeight: closed ? FontWeight.bold : null,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (v) async {
                                              if (v == null) return;
                                              final match = _branches.where((
                                                b,
                                              ) {
                                                return _branchIdFromMap(b) == v;
                                              }).toList();
                                              final name = match.isNotEmpty
                                                  ? _branchNameFromMap(
                                                      match.first,
                                                    )
                                                  : '';
                                              setSheetState(() {
                                                _selectedBranchId = v;
                                                _calculateDeliveryFee(
                                                  isSelfPickup,
                                                );
                                              });
                                              await _apiService
                                                  .setCachedCustomerBranch(
                                                    branchId: v,
                                                    branchName: name,
                                                  );
                                              setSheetState(() {
                                                _isLoadingSelfOrderConfig = true;
                                              });
                                              await _loadSelfOrderConfig();
                                              _loadCatalog(); 
                                              if (mounted) {
                                                setSheetState(() {});
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    if (isClosed) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.red.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline, color: Colors.red),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(_l10n?.branchClosed ?? (_l10n?.branchClosed ?? 'This branch is currently closed. Please choose another branch or order later.'),
                                                style: TextStyle(
                                                  color: Colors.red.shade800,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    // ── Fulfillment type ──
                                    Text(_l10n?.howReceiveOrder ?? (_l10n?.howReceiveOrder ?? 'How will you receive your order?'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setSheetState(() {
                                              isSelfPickup = false;
                                              _calculateDeliveryFee(
                                                isSelfPickup,
                                              );
                                            }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: !isSelfPickup
                                                    ? _brandNavy
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    const BorderRadius.horizontal(
                                                      left: Radius.circular(12),
                                                    ),
                                                border: Border.all(
                                                  color: !isSelfPickup
                                                      ? _brandNavy
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.delivery_dining,
                                                    color: !isSelfPickup
                                                        ? Colors.white
                                                        : Colors.grey.shade500,
                                                    size: 26,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(_l10n?.riderDelivery ?? (_l10n?.riderDelivery ?? 'Rider delivery'),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                      color: !isSelfPickup
                                                          ? Colors.white
                                                          : Colors
                                                                .grey
                                                                .shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setSheetState(() {
                                              isSelfPickup = true;
                                              _calculateDeliveryFee(
                                                isSelfPickup,
                                              );
                                            }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelfPickup
                                                    ? _brandNavy
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    const BorderRadius.horizontal(
                                                      right: Radius.circular(
                                                        12,
                                                      ),
                                                    ),
                                                border: Border.all(
                                                  color: isSelfPickup
                                                      ? _brandNavy
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.store_outlined,
                                                    color: isSelfPickup
                                                        ? Colors.white
                                                        : Colors.grey.shade500,
                                                    size: 26,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(_l10n?.comePickUpMyself ?? (_l10n?.comePickUpMyself ?? 'Come pick up myself'),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                      color: isSelfPickup
                                                          ? Colors.white
                                                          : Colors
                                                                .grey
                                                                .shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (!isSelfPickup) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(_l10n?.deliveryPlace ?? (_l10n?.deliveryPlace ?? 'Delivery place'),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () =>
                                                _openAddFavoritePlaceSheet(
                                                  setSheetState,
                                                ),
                                            icon: const Icon(
                                              Icons.add_location_alt_outlined,
                                            ),
                                            label: Text(_l10n?.add ?? (_l10n?.add ?? 'Add')),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (_favoritePlaces.isEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Text(_l10n?.addFavoritePlaceBeforeOrder ?? (_l10n?.addFavoritePlaceBeforeOrder ?? 'Please add a favorite place before confirming the order.'),
                                            style: TextStyle(
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedFavoritePlaceId,
                                              isExpanded: true,
                                              hint: Text(_l10n?.selectDeliveryPlace ?? (_l10n?.selectDeliveryPlace ?? 'Select a delivery place'),
                                              ),
                                              items: _favoritePlaces.map((
                                                place,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: place.id,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        place.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        place.address,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                if (value == null) return;
                                                setState(() {
                                                  _selectedFavoritePlaceId =
                                                      value;
                                                });
                                                setSheetState(() {
                                                  _calculateDeliveryFee(
                                                    isSelfPickup,
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(bottom: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A000000),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(_l10n?.paymentBreakdown ?? (_l10n?.paymentBreakdown ?? 'Payment Breakdown'),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_l10n?.subtotal ?? (_l10n?.subtotal ?? 'Subtotal'),
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                '₭${_cartTotal.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_couponDiscount > 0) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(_l10n?.discount ?? (_l10n?.discount ?? 'Discount'),
                                                  style: TextStyle(
                                                    color: Colors.red.shade600,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  '-₭${_couponDiscount.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    color: Colors.red.shade600,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (_cartItems.fold<int>(
                                                0,
                                                (sum, item) =>
                                                    sum + item.totalPoints,
                                              ) >
                                              0) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(_l10n?.pointsRequired ?? (_l10n?.pointsRequired ?? 'Points Required'),
                                                  style: TextStyle(
                                                    color:
                                                        Colors.orange.shade700,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  '${_cartItems.fold<int>(0, (sum, item) => sum + item.totalPoints)} Pts',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.orange.shade700,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (!isSelfPickup) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Delivery Fee (${_currentDeliveryDistanceKm.toStringAsFixed(1)} km)',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  '₭${_deliveryFee.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            child: Divider(height: 1),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_l10n?.totalPayment ?? (_l10n?.totalPayment ?? 'Total Payment'),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              Text(
                                                '₭${(_cartTotal - _effectiveCouponDiscount + _deliveryFee).toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 20,
                                                  color: Color(0xFF001460),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (!isSelfPickup &&
                                              _isFreeDeliveryTipApplicable) ...[
                                            const SizedBox(height: 16),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.green.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.info_outline,
                                                    color: Colors.green,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'Add ₭${_amountNeededForFreeDelivery.toStringAsFixed(0)} more to get free delivery!',
                                                      style: const TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      AppLocalizations.of(context)?.orderNote ??
                                          (_l10n?.orderNote ?? 'Order Note / Pickup Time'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _noteController,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            AppLocalizations.of(
                                              context,
                                            )?.orderNoteHint ??
                                            (_l10n?.orderNoteHint ?? 'e.g., Pickup at 3:00 PM, extra spicy, etc.'),
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _brandNavy,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 12),

                                    if (paymentChoice == 'transfer') ...[
                                      const SizedBox(height: 10),
                                      if (_transferBanks.length > 1) ...[
                                        Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.selectBank ??
                                              (_l10n?.selectBank ?? 'Select Bank'),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<int>(
                                              value: _selectedBankIndex,
                                              isExpanded: true,
                                              items: List.generate(
                                                _transferBanks.length,
                                                (i) {
                                                  final b = _transferBanks[i];
                                                  return DropdownMenuItem(
                                                    value: i,
                                                    child: Text(
                                                      '${b['label'] ?? b['bank_name']} — ${b['account_name']}',
                                                    ),
                                                  );
                                                },
                                              ),
                                              onChanged: (idx) {
                                                if (idx == null) return;
                                                setSheetState(() {
                                                  _selectedBankIndex = idx;
                                                  _syncSelectedBank();
                                                  proofImage =
                                                      null; // reset proof on bank change
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                      Text(
                                        AppLocalizations.of(
                                              context,
                                            )?.scanQrCode ??
                                            (_l10n?.scanQrCode ?? 'Scan QR Code'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      LayoutBuilder(
                                        builder: (context, c) {
                                          final qrSide = (c.maxWidth * 0.72)
                                              .clamp(160.0, 220.0);
                                          return Center(
                                            child: SizedBox(
                                              width: qrSide,
                                              height: qrSide,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                                child: _isLoadingSelfOrderConfig
                                                    ? const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      )
                                                    : (_qrBytesFromDataUrl() !=
                                                              null
                                                          ? Image.memory(
                                                              _qrBytesFromDataUrl()!,
                                                              fit: BoxFit
                                                                  .contain,
                                                            )
                                                          : Center(
                                                              child: Text(_l10n?.qrNotConfigured ?? (_l10n?.qrNotConfigured ?? 'QR not configured in Odoo Settings'),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
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
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _downloadQrCode(
                                            sheetMessengerKey.currentState,
                                          ),
                                          icon: const Icon(Icons.download),
                                          label: Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.downloadQr ??
                                                (_l10n?.downloadQr ?? 'Download QR'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final picked = await _imagePicker
                                                .pickImage(
                                                  source: ImageSource.gallery,
                                                  // Any source size is
                                                  // accepted. Downscaling is
                                                  // not a restriction, it is
                                                  // what makes the upload
                                                  // finish: a raw 12MP photo is
                                                  // several MB and timed out on
                                                  // mobile data. 2000px keeps a
                                                  // transfer slip sharp.
                                                  maxWidth: 2000,
                                                  maxHeight: 2000,
                                                  imageQuality: 85,
                                                );
                                            if (picked != null) {
                                              setSheetState(
                                                () => proofImage = picked,
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.upload_file),
                                          label: Text(
                                            proofImage == null
                                                ? AppLocalizations.of(
                                                        context,
                                                      )?.uploadTransferProof ??
                                                      (_l10n?.uploadTransferProof ?? 'Upload Transfer Proof')
                                                : AppLocalizations.of(
                                                        context,
                                                      )?.proofSelected ??
                                                      (_l10n?.proofSelected ?? 'Proof Selected'),
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.transferProofSelectedMsg ??
                                                (_l10n?.transferProofSelectedMsg ?? 'Transfer proof selected. It will be uploaded when you confirm order.'),
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
                                          transferBankId:
                                              _transferBanks.isNotEmpty
                                              ? _transferBanks[_selectedBankIndex]['id']
                                                    as int?
                                              : null,
                                          branchId: _selectedBranchId,
                                          note: _noteController.text.trim(),
                                          isSelfPickup: isSelfPickup,
                                          favoritePlace: isSelfPickup
                                              ? (_favoritePlaces.isNotEmpty
                                                    ? _favoritePlaces.first
                                                    : null)
                                              : _selectedFavoritePlace,
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brandNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  '${AppLocalizations.of(context)?.confirmOrder ?? (_l10n?.confirmOrder ?? 'Confirm Order')} (₭${(_cartTotal - _effectiveCouponDiscount + _deliveryFee).toStringAsFixed(2)})',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Scaffold(backgroundColor: Colors.transparent),
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

  Future<void> _placeOrder({
    required String paymentChoice,
    String? proofImagePath,
    int? transferBankId,
    int? branchId,
    String? note,
    bool isSelfPickup = false,
    _FavoritePlace? favoritePlace,
  }) async {
    if (_cartItems.isEmpty || _isPlacingOrder) return;
    if (!_hasCustomerPhone()) {
      await _showPhoneRequiredForOrderDialog();
      return;
    }

    setState(() => _isPlacingOrder = true);
    bool isBadWeather = _isRaining;
    if (!isBadWeather &&
        !isSelfPickup &&
        favoritePlace != null &&
        favoritePlace.latitude != null &&
        favoritePlace.longitude != null) {
      isBadWeather = await _checkWeatherIsBad(
        favoritePlace.latitude!,
        favoritePlace.longitude!,
      );
    }
    try {
      final int totalPointsNeeded = _cartItems.fold(
        0,
        (sum, item) => sum + item.totalPoints,
      );
      if (totalPointsNeeded > _rewardPoints) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n?.notEnoughPointsRedeem ?? (_l10n?.notEnoughPointsRedeem ?? 'Not enough points to redeem these items.')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final lines = _cartItems
          .map(
            (item) => {
              'product_id': item.product.id,
              'qty': item.quantity,
              'price_unit': item.isRedeemed ? 0.0 : item.product.effectivePrice,
              'topping_ids': item.selectedToppings.map((t) => t.id).toList(),
              'is_redeemed': item.isRedeemed,
              'point_cost': item.isRedeemed ? item.pointPrice : 0,
              // Matches the key the cashier review screen reads back.
              'note': item.kitchenNote.trim(),
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
        customerPhone: _cleanProfileText(_customerPhone),
        note: _composeOrderNote(
          isSelfPickup: isSelfPickup,
          customerNote: note,
        ),
        deliveryPlaceName: favoritePlace?.name,
        deliveryPlaceAddress: favoritePlace?.address,
        deliveryPlaceId: favoritePlace?.placeId,
        deliveryLatitude: favoritePlace?.latitude,
        deliveryLongitude: favoritePlace?.longitude,
        deliveryMapsUrl: favoritePlace?.mapsUrl,
        couponCode: _appliedCouponCode,
        deliveryFee: _deliveryFee,
      );

      String? uploadedProofUrl;
      var proofUploadFailed = false;
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
        } catch (e) {
          // The order still stands, but the customer must know the proof did
          // not arrive: silently swallowing this left them believing the shop
          // had their slip while the cashier saw nothing.
          debugPrint('[Order] Transfer proof upload failed: $e');
          proofUploadFailed = true;
        }
      }

      final nowIso = DateTime.now().toIso8601String();
      final localEntry = {
        'source': 'local',
        'id': result['order_id'] ?? 0,
        'name': result['order_reference'] ?? 'Order',
        'amount_total':
            _cartTotal - _effectiveCouponDiscount + _deliveryFee,
        'date_order': nowIso,
        'payment_method': paymentChoice == 'transfer'
            ? (_l10n?.payTransfer ?? 'Transfer')
            : (_l10n?.payAtStore ?? 'Pay At Store'),
        'state': paymentChoice == 'transfer'
            ? 'waiting transfer verification'
            : 'waiting payment at store',
        'customer': _customerName,
        'delivery_place_name': favoritePlace?.name,
        'delivery_place_address': favoritePlace?.address,
        'delivery_maps_url': favoritePlace?.mapsUrl,
        'delivery_latitude': favoritePlace?.latitude,
        'delivery_longitude': favoritePlace?.longitude,
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
        // The coupon was consumed by this order; without this it stayed
        // applied, kept discounting the next cart and could not be removed.
        _clearCouponState();
        _noteController.clear();
        _deliveryFee = 0.0;
        _selectedTabIndex =
            2; // History tab (Home=0, Cart=1, History=2, Profile=3)
      });
      // Refresh both history (to show the new order) and profile (to update reward points)
      await Future.wait([_loadHistory(forceRefresh: true), _loadProfile()]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentChoice == 'transfer'
                ? (uploadedProofUrl != null
                      ? (_l10n?.orderCreatedProofUploaded ?? 'Order created. Transfer proof uploaded.')
                      : (_l10n?.orderCreatedProofLocal ?? 'Order created. Transfer proof saved locally.'))
                : (_l10n?.orderCreatedPayAtStore ?? 'Order created. Please pay at the store.'),
          ),
          backgroundColor: Colors.green,
        ),
      );

      if (proofUploadFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l10n?.proofUploadFailed ??
                  'Order placed, but the transfer proof could not be '
                      'uploaded. Please show it to the staff.',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 8),
          ),
        );
      }

      if (isBadWeather && mounted) {
        setState(() {
          _isRaining = true;
        });
        _showBadWeatherSnackBar();
      }
    } catch (e) {
      debugPrint('[Order] Failed to place order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.failedToPlaceOrder ?? (_l10n?.failedToPlaceOrder ?? 'Failed to place order. Please check your connection and try again.')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  bool _hasCustomerPhone() {
    return _cleanProfileText(_customerPhone).isNotEmpty;
  }

  Future<void> _showPhoneRequiredForOrderDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(_l10n?.phoneNumberRequiredLower ?? (_l10n?.phoneNumberRequiredLower ?? 'Phone number required')),
        content: Text(_l10n?.addPhoneBeforeOrder ?? (_l10n?.addPhoneBeforeOrder ?? 'Please add your phone number before placing an order. This is required for customer verification and so the store can contact you if needed.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(_l10n?.cancel ?? (_l10n?.cancel ?? 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openEditProfileSheet();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandNavy,
              foregroundColor: Colors.white,
            ),
            child: Text(_l10n?.addPhone ?? (_l10n?.addPhone ?? 'Add phone')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile || _customerName.trim().isEmpty) return;
    setState(() => _isSavingProfile = true);
    try {
      final saved = await _apiService.saveCustomer(
        id: _customerId,
        name: _customerName.trim(),
        phone: _cleanProfileText(_customerPhone),
        // Email no longer shown in UI; keep sending if already populated.
        email: _cleanProfileText(_customerEmail).isEmpty
            ? null
            : _cleanProfileText(_customerEmail),
        dateOfBirth: _customerDob.trim().isEmpty ? null : _customerDob.trim(),
      );

      if (!mounted) return;
      setState(() {
        _customerId = saved['id'] as int?;
        final savedName = _cleanProfileText(saved['name']);
        if (savedName.isNotEmpty) _customerName = savedName;
        _customerPhone = _cleanProfileText(saved['phone']);
        _customerEmail = _cleanProfileText(saved['email']);
        _clientId = _cleanProfileText(saved['client_id']);
        final savedDob = _cleanProfileText(saved['date_of_birth']);
        _customerDob = savedDob.isNotEmpty
            ? savedDob
            : _cleanProfileText(saved['birthdate']).isNotEmpty
            ? _cleanProfileText(saved['birthdate'])
            : _customerDob;
        _rewardPoints =
            int.tryParse(
              (saved['reward_points'] ?? _rewardPoints).toString(),
            ) ??
            _rewardPoints;
        _rewardRank =
            int.tryParse((saved['reward_rank'] ?? _rewardRank).toString()) ??
            _rewardRank;
      });

      await _loadHistory(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.profileUpdated ?? (_l10n?.profileUpdated ?? 'Profile updated')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[Profile] Cannot save profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.couldNotSaveProfileConnection ?? (_l10n?.couldNotSaveProfileConnection ?? 'Could not save profile. Please check your connection and try again.')),
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

  Future<void> _confirmDeleteAccount() async {
    if (_isDeletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_l10n?.deleteAccountTitle ?? (_l10n?.deleteAccountTitle ?? 'Delete account?'),
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This will permanently delete your account, including your reward '
          'points, vouchers and order history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_l10n?.cancel ?? (_l10n?.cancel ?? 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_l10n?.delete ?? (_l10n?.delete ?? 'Delete'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    setState(() => _isDeletingAccount = true);
    try {
      final result = await _apiService.deleteAccount();
      if (result['status'] == 'success') {
        // Best-effort: delete the Firebase user record too, so all personal
        // data is removed and a future Google re-register gets a fresh UID.
        // May fail with requires-recent-login — non-fatal, just skip.
        try {
          await FirebaseAuthService.instance.deleteCurrentUser();
        } catch (_) {}
        // Best-effort: clear Google/Firebase session so the next
        // Google sign-in doesn't silently reuse the deleted account.
        try {
          await FirebaseAuthService.instance.signOut();
        } catch (_) {}
        await _apiService.logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n?.accountDeleted ?? (_l10n?.accountDeleted ?? 'Your account has been deleted.')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  (_l10n?.couldNotDeleteAccount ?? 'Could not delete account. Please try again.'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  void _openRewardsCatalog() {
    final redeemableProducts = _products.where((p) {
      if (!p.isRedeemable) return false;
      final now = DateTime.now();
      if (p.redeemStartDate != null && now.isBefore(p.redeemStartDate!))
        return false;
      if (p.redeemEndDate != null && now.isAfter(p.redeemEndDate!))
        return false;
      return true;
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_l10n?.rewardsCatalog ?? (_l10n?.rewardsCatalog ?? 'Rewards Catalog'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        '$_rewardPoints Pts',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Expanded(
                child: redeemableProducts.isEmpty
                    ? Center(
                        child: Text(_l10n?.noRewardsAvailable ?? (_l10n?.noRewardsAvailable ?? 'No rewards available at the moment.'),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: redeemableProducts.length,
                        itemBuilder: (context, index) {
                          final product = redeemableProducts[index];
                          final canAfford = _rewardPoints >= product.pointPrice;
                          return GestureDetector(
                            onTap: canAfford
                                ? () {
                                    _confirmRedeem(product);
                                  }
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_l10n?.notEnoughPoints ?? (_l10n?.notEnoughPoints ?? 'Not enough points!')),
                                      ),
                                    );
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: _buildProductImage(product),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.displayName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: canAfford
                                                  ? _brandNavy
                                                  : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${product.pointPrice} Pts',
                                              style: TextStyle(
                                                color: canAfford
                                                    ? Colors.white
                                                    : Colors.grey.shade600,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
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
            ],
          ),
        );
      },
    );
  }

  void _confirmRedeem(Product product) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isRedeeming = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(_l10n?.redeemRewardTitle ?? (_l10n?.redeemRewardTitle ?? 'Redeem Reward?'),
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Text(
                'Do you want to convert ${product.pointPrice} points into a voucher for ${product.displayName}?',
              ),
              actions: [
                TextButton(
                  onPressed: isRedeeming ? null : () => Navigator.pop(ctx),
                  child: Text(_l10n?.cancel ?? (_l10n?.cancel ?? 'Cancel'),
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandNavy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isRedeeming
                      ? null
                      : () async {
                          setDialogState(() => isRedeeming = true);
                          try {
                            // Note: We need the customer's partner ID.
                            // Since self order screen doesn't directly expose partner ID except via matching _customerPhone,
                            // we can just pass widget.partnerId if available, or try to get it.
                            if (widget.partnerId == null) {
                              throw Exception(
                                'Customer not logged in properly.',
                              );
                            }
                            await _apiService.redeemVoucher(
                              widget.partnerId!,
                              product.id,
                            );
                            if (mounted) {
                              Navigator.pop(ctx); // Close dialog
                              Navigator.pop(context); // Close Catalog
                              setState(() {
                                _rewardPoints -= product.pointPrice;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_l10n?.voucherCreated ?? (_l10n?.voucherCreated ?? 'Voucher created successfully!'),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _openMyVouchers(); // Automatically open vouchers list
                            }
                          } catch (e) {
                            setDialogState(() => isRedeeming = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isRedeeming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_l10n?.redeem ?? (_l10n?.redeem ?? 'Redeem')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showVoucherQrDialog(Map<String, dynamic> voucher) {
    Timer? _pollTimer;
    bool _isClaimed = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Start polling when dialog opens
            if (_pollTimer == null && !_isClaimed) {
              _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
                try {
                  if (widget.partnerId == null) return;
                  final vouchers = await _apiService.fetchMyVouchers(widget.partnerId!);
                  final updatedVoucher = vouchers.firstWhere(
                    (v) => v['code'] == voucher['code'],
                    orElse: () => <String, dynamic>{},
                  );
                  if (updatedVoucher.isNotEmpty && updatedVoucher['state'] == 'claimed') {
                    timer.cancel();
                    if (mounted) {
                      setState(() {
                        _isClaimed = true;
                      });
                      // Auto-refresh the My Vouchers list after 2 seconds
                      Future.delayed(const Duration(seconds: 2), () {
                        if (Navigator.canPop(ctx)) {
                          Navigator.pop(ctx);
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context); // Close the My Vouchers sheet
                            _openMyVouchers(); // Re-open to refresh state
                          }
                        }
                      });
                    }
                  }
                } catch (e) {
                  // Ignore polling errors
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                _isClaimed ? (_l10n?.claimedSuccessfully ?? 'Claimed Successfully!') : (voucher['product_name'] ?? 'Voucher'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _isClaimed ? Colors.green : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isClaimed 
                      ? (_l10n?.rewardClaimedEnjoy ?? 'Your reward has been claimed. Enjoy!')
                      : (_l10n?.scanQrAtCounter ?? 'Scan this QR code at the counter to claim your reward.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_isClaimed)
                    const Center(
                      child: Icon(Icons.check_circle, color: Colors.green, size: 120),
                    )
                  else
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: QrImageView(
                          data: voucher['code'] ?? '',
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    voucher['code'] ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: _isClaimed ? Colors.green : _brandNavy,
                      decoration: _isClaimed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _pollTimer?.cancel();
                    Navigator.pop(ctx);
                  },
                  child: Text(_l10n?.close ?? (_l10n?.close ?? 'Close')),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Ensure timer is cancelled when dialog is dismissed
      _pollTimer?.cancel();
    });
  }

  void _openMyVouchers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_l10n?.myVouchers ?? (_l10n?.myVouchers ?? 'My Vouchers'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  Expanded(
                    child: widget.partnerId == null
                        ? Center(child: Text(_l10n?.notLoggedIn ?? (_l10n?.notLoggedIn ?? 'Not logged in.')))
                        : FutureBuilder<List<Map<String, dynamic>>>(
                            future: _apiService.fetchMyVouchers(
                              widget.partnerId!,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Error: ${snapshot.error}'),
                                );
                              }
                              final vouchers = snapshot.data ?? [];
                              if (vouchers.isEmpty) {
                                return Center(
                                  child: Text(
                                    "You don't have any vouchers yet.",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: vouchers.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final v = vouchers[index];
                                  final bool isClaimed =
                                      v['state'] == 'claimed';
                                  return GestureDetector(
                                    onTap: isClaimed
                                        ? null
                                        : () => _showVoucherQrDialog(v),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isClaimed
                                            ? Colors.grey.shade100
                                            : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isClaimed
                                              ? Colors.grey.shade300
                                              : Colors.blue.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isClaimed
                                                  ? Icons.check_circle_outline
                                                  : Icons.qr_code_2,
                                              size: 32,
                                              color: isClaimed
                                                  ? Colors.grey
                                                  : _brandNavy,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  bilingualName(
                                                    v,
                                                    fallback:
                                                        _l10n?.unknown ??
                                                        'Unknown',
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                    color: isClaimed
                                                        ? Colors.grey.shade600
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Code: ${v['code']}',
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isClaimed
                                                        ? Colors.grey.shade500
                                                        : _brandNavy,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isClaimed)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _brandNavy,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(_l10n?.voucherActive ?? (_l10n?.voucherActive ?? 'ACTIVE'),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
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

  void _openEditProfileSheet() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfileEditScreen(
          currentName: _customerName,
          currentPhone: _customerPhone,
          currentDob: _customerDob,
          onSave: (name, phone, dob) async {
            _customerName = name;
            _customerPhone = _cleanProfileText(phone);
            _customerDob = dob;
            await _saveProfile();
          },
        ),
      ),
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
          const Icon(
            Icons.emoji_events_rounded,
            size: 16,
            color: Color(0xFFF59E0B),
          ),
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
    return InkWell(
      onTap: () {
        final v = !_pushNotificationsEnabled;
        // ── Optimistic UI update ───────────────────────────────────
        final previousValue = _pushNotificationsEnabled;
        final myToken = ++_notifSyncToken;
        setState(() => _pushNotificationsEnabled = v);

        // ── Background FCM sync ────────────────────────────────────
        PushNotificationsService.setCustomerPushEnabled(
          v,
          onFailure: (reason) {
            if (!mounted || myToken != _notifSyncToken) return;
            setState(() => _pushNotificationsEnabled = previousValue);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_l10n?.couldNotUpdateNotifications ?? (_l10n?.couldNotUpdateNotifications ?? 'Could not update notification settings. Please try again.'),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: _brandNavy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_l10n?.notifications ?? (_l10n?.notifications ?? 'Notifications'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _textPrimaryDark,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pushNotificationsEnabled
                            ? (_l10n?.orderUpdatesOnDevice ?? 'Order updates on this device')
                            : (_l10n?.pushAlertsOff ?? 'Push alerts are turned off'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _labelGray,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _pushNotificationsEnabled,
                  activeThumbColor: Colors.white,
                  activeColor: _brandNavy,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD5E1),
                  onChanged: (v) {
                    final previousValue = _pushNotificationsEnabled;
                    final myToken = ++_notifSyncToken;
                    setState(() => _pushNotificationsEnabled = v);

                    PushNotificationsService.setCustomerPushEnabled(
                      v,
                      onFailure: (reason) {
                        if (!mounted || myToken != _notifSyncToken) return;
                        setState(
                          () => _pushNotificationsEnabled = previousValue,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_l10n?.couldNotUpdateNotifications ?? (_l10n?.couldNotUpdateNotifications ?? 'Could not update notification settings. Please try again.'),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 76, right: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ),
        ],
      ),
    );
  }

  Widget _profileMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _brandNavy, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _textPrimaryDark,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _labelGray,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing,
                ] else ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                  ),
                ],
              ],
            ),
          ),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.only(left: 76, right: 16),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ),
        ],
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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final totalPrice =
                (product.effectivePrice +
                    selectedToppings.fold(
                      0.0,
                      (sum, t) => sum + t.extraPrice,
                    )) *
                qty;

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                child: Stack(
                  children: [
                    // Scrollable Body
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Image Area
                            Stack(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 380,
                                  child: _buildProductImage(product),
                                ),
                                // Gradient for text readability if needed
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.3),
                                          Colors.transparent,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Content Card
                            Transform.translate(
                              offset: const Offset(0, -30),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(32),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.displayName,
                                                style: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w900,
                                                  color: _brandNavy,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                product.category,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: _brandNavy.withOpacity(
                                                    0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 32),

                                    // Quantity & Price Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_l10n?.quantity ?? (_l10n?.quantity ?? 'Quantity'),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: _brandNavy,
                                          ),
                                        ),
                                        _QtyStepper(
                                          qty: qty,
                                          onChanged: (val) =>
                                              setSheetState(() => qty = val),
                                          color: _brandNavy,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 40),

                                    // Toppings Section
                                    if (product.toppings.isNotEmpty) ...[
                                      Text(_l10n?.customization ?? (_l10n?.customization ?? 'Customization'),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: _brandNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: product.toppings.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          final topping =
                                              product.toppings[index];
                                          final isSelected = selectedToppings
                                              .any((t) => t.id == topping.id);

                                          return InkWell(
                                            onTap: () {
                                              setSheetState(() {
                                                if (isSelected) {
                                                  selectedToppings.removeWhere(
                                                    (t) => t.id == topping.id,
                                                  );
                                                } else {
                                                  selectedToppings.add(topping);
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFFEFF6FF)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? _brandNavy
                                                      : const Color(0xFFE2E8F0),
                                                  width: isSelected ? 2 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          topping.name,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: isSelected
                                                                ? _brandNavy
                                                                : _textPrimaryDark,
                                                          ),
                                                        ),
                                                        if (topping.extraPrice >
                                                            0)
                                                          Text(
                                                            '+₭${topping.extraPrice.toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isSelected
                                                                  ? _brandNavy
                                                                        .withOpacity(
                                                                          0.7,
                                                                        )
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: _brandNavy,
                                                    )
                                                  else
                                                    const Icon(
                                                      Icons.add_circle_outline,
                                                      color: Color(0xFFCBD5E1),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Bar (Close Button)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          foregroundColor: _brandNavy,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ),

                    // Fixed Bottom Action Bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          20,
                          24,
                          20 + _gestureNavBottomPad(context),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_l10n?.totalPrice ?? (_l10n?.totalPrice ?? 'Total Price'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '₭${totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: _brandNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _addToCart(
                                      product,
                                      quantity: qty,
                                      selectedToppings: selectedToppings,
                                      isRedeemed: false,
                                    );
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$qty ${product.displayName} added to cart',
                                        ),
                                        backgroundColor: _brandNavy,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(
                                          milliseconds: 1500,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _brandNavy,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(_l10n?.addToCart ?? (_l10n?.addToCart ?? 'Add to Cart'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
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

    final navDestinations = [
      NavigationDestination(
        icon: Icon(Icons.home_outlined, color: _navInactive),
        selectedIcon: _navSelectedIcon(Icons.home),
        label: _l10n?.navHome ?? (_l10n?.navHome ?? 'Home'),
      ),
      NavigationDestination(
        icon: _cartCount > 0
            ? Badge(
                label: Text('$_cartCount'),
                backgroundColor: Colors.red,
                child: Icon(Icons.shopping_bag_outlined, color: _navInactive),
              )
            : Icon(Icons.shopping_bag_outlined, color: _navInactive),
        selectedIcon: _cartCount > 0
            ? Badge(
                label: Text('$_cartCount'),
                backgroundColor: Colors.red,
                child: _navSelectedIcon(Icons.shopping_bag),
              )
            : _navSelectedIcon(Icons.shopping_bag),
        label: _l10n?.navCart ?? (_l10n?.navCart ?? 'Cart'),
      ),
      NavigationDestination(
        icon: Icon(Icons.access_time, color: _navInactive),
        selectedIcon: _navSelectedIcon(Icons.access_time),
        label: _l10n?.navHistory ?? (_l10n?.navHistory ?? 'History'),
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline, color: _navInactive),
        selectedIcon: _navSelectedIcon(Icons.person),
        label: _l10n?.navProfile ?? (_l10n?.navProfile ?? 'Profile'),
      ),
    ];

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
          if (_cartCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => setState(() => _selectedTabIndex = 1),
                icon: const Badge(
                  label: Text(''),
                  backgroundColor: Colors.red,
                  child: Icon(
                    Icons.shopping_bag,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                label: Text(
                  '₭${_cartTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: _l10n?.refresh ?? (_l10n?.refresh ?? 'Refresh'),
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
            if (_isRaining)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    const Icon(
                      Icons.thunderstorm_rounded,
                      color: Color(0xFFFBBF24),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.weatherWarning ??
                            (_l10n?.weatherWarning ?? 'Due to bad weather, your delivery or rider may be delayed.'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: ColoredBox(
                    color: Colors.white,
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _buildHomeTab(
                          isWide: isWide,
                          isSmall: isSmall,
                          isMobile: isMobile,
                        ),
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
      bottomSheet: null,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: const NavigationBarThemeData(
            indicatorColor: Colors.transparent,
            elevation: 0,
            height: 64,
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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
          destinations: navDestinations,
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
      _loadHistory(forceRefresh: true),
      _loadSelfOrderConfig(),
      _loadBranches(),
    ]);
  }

  Widget _buildHomeTab({
    required bool isWide,
    required bool isSmall,
    bool isMobile = false,
  }) {
    if (_isLoadingCatalog) {
      return CustomerSelfOrderSkeleton(
        isWide: isWide,
        isMobile: isMobile,
        isSmall: isSmall,
      );
    }

    if (_catalogError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 46),
            const SizedBox(height: 12),
            Text(_catalogError ?? (_l10n?.errorLoadingProducts ?? 'Error loading products')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadCatalog, child: Text(_l10n?.retry ?? (_l10n?.retry ?? 'Retry'))),
          ],
        ),
      );
    }

    final items = _filteredProducts;
    final showHighlights = _selectedCategory == 'All Items';
    final highlightsSlivers = <Widget>[
      if (showHighlights && _recommendedProducts.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildRecommendedSlider(isSmall: isSmall, isWide: isWide),
        ),
      if (showHighlights && _popularProducts.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildPopularSlider(isSmall: isSmall, isWide: isWide),
        ),
      SliverToBoxAdapter(
        child: _buildSectionHeader('All Products', isSmall: isSmall),
      ),
    ];

    final isNarrowWideLayout =
        isWide && MediaQuery.sizeOf(context).width < 1200;
    final sliverGrid = items.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(_l10n?.noItemsFound ?? (_l10n?.noItemsFound ?? 'No items found'))),
          )
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
                mainAxisExtent: isWide
                    ? (isNarrowWideLayout ? 140 : 132)
                    : (isMobile ? 110 : 126),
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

    return Row(
      children: [
        // Left Column: Current Cart Preview
        Expanded(
          flex: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
            child: _buildCurrentCartPanel(),
          ),
        ),
        const SizedBox(width: 12),
        // Right Column: Catalog Content
        Expanded(
          flex: 72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: _buildBannerCarousel(isSmall: isSmall),
              ),
              _buildCategoryChipsBar(isSmall: isSmall),
              Expanded(
                child: CustomScrollView(
                  slivers: [...highlightsSlivers, sliverGrid],
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
  Widget _buildRecommendedSlider({
    required bool isSmall,
    required bool isWide,
  }) {
    if (_recommendedProducts.isEmpty) return const SizedBox.shrink();
    // Card width: fill screen proportionally; 3 cards max
    // phone: ~(screenWidth - padding) / 1.35 to show partial 2nd card
    // tablet: ~(availableWidth) / 2.8 per card
    final hPad = isSmall ? 12.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recommended Products', isSmall: isSmall),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // Maintain a strict 2:1 aspect ratio for the banners.
            final cardWidth = isWide
                ? (constraints.maxWidth - hPad * 2) / 2.2
                : (constraints.maxWidth - hPad * 2) / 1.2;
            final cardHeight = cardWidth / 2;
            final available = (constraints.maxWidth - hPad * 2).clamp(
              1.0,
              99999.0,
            );
            final viewportFraction = ((cardWidth / available).clamp(
              0.35,
              0.95,
            )).toDouble();
            _ensureRecommendedSliderController(viewportFraction);
            _startRecommendedAutoSlide(_recommendedProducts.length);

            return SizedBox(
              height: cardHeight,
              child: PageView.builder(
                controller: _recommendedPageController,
                padEnds: false,
                onPageChanged: (index) => _recommendedSlideIndex = index,
                itemCount: _recommendedProducts.length,
                itemBuilder: (context, index) {
                  final product = _recommendedProducts[index];
                  final blocked = product.blockSelfOrder;
                  Uint8List? imgBytes;

                  // Prioritize recommended image for this specific slider
                  final imgData =
                      (product.recommendedImageBase64 != null &&
                          product.recommendedImageBase64!.isNotEmpty)
                      ? product.recommendedImageBase64
                      : product.imageBase64;

                  if (imgData != null && imgData.isNotEmpty) {
                    imgBytes = _bytesFromBase64(imgData);
                  }
                  return GestureDetector(
                    onTap: blocked
                        ? _showSelfOrderBlockedMessage
                        : () => _openProductDetail(product),
                    child: Opacity(
                      opacity: blocked ? 0.55 : 1.0,
                      child: Container(
                        width: cardWidth,
                        margin: EdgeInsets.only(
                          left: index == 0 ? hPad : (isSmall ? 5 : 7),
                          right: index == _recommendedProducts.length - 1
                              ? hPad
                              : (isSmall ? 5 : 7),
                        ),
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
                                    ? Image.memory(
                                        imgBytes,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      )
                                    : Container(
                                        color: _brandNavy.withOpacity(0.08),
                                        child: const Icon(
                                          Icons.fastfood,
                                          size: 48,
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                              ),
                              // Gradient overlay at bottom
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
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
                                    product.displayName,
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
                              // Direct Add Button
                              if (!blocked)
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      _addToCart(
                                        product,
                                        quantity: 1,
                                        selectedToppings: [],
                                        isRedeemed:
                                            _selectedCategory ==
                                            'Redeem points',
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${product.displayName} added to cart',
                                          ),
                                          backgroundColor: _brandNavy,
                                          duration: const Duration(
                                            milliseconds: 900,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: isSmall ? 36 : 40,
                                      height: isSmall ? 36 : 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: _brandNavy,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              // Recommended badge
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(_l10n?.recommendedBadge ?? (_l10n?.recommendedBadge ?? '⭐ Recommended'),
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
              ),
            );
          },
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
              if (product.imageBase64 != null &&
                  product.imageBase64!.isNotEmpty) {
                imgBytes = _bytesFromBase64(product.imageBase64!);
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
                                ? Image.memory(
                                    imgBytes,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    gaplessPlayback: true,
                                  )
                                : Container(
                                    color: _brandNavy.withOpacity(0.07),
                                    child: const Center(
                                      child: Icon(
                                        Icons.fastfood,
                                        size: 36,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    product.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isSmall ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (_selectedCategory ==
                                              'Redeem points')
                                            Text(
                                              '${product.pointPrice} Pts',
                                              style: TextStyle(
                                                fontSize: isSmall ? 12 : 13,
                                                fontWeight: FontWeight.w800,
                                                color: _brandNavy,
                                              ),
                                            )
                                          else ...[
                                            if (product.promotionPrice != null)
                                              Text(
                                                '₭${product.price.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: isSmall ? 9 : 10,
                                                  color: Colors.grey.shade400,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                            Text(
                                              '₭${product.effectivePrice.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: isSmall ? 12 : 13,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    product.promotionPrice !=
                                                        null
                                                    ? Colors.red
                                                    : _brandNavy,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (!blocked)
                                        GestureDetector(
                                          onTap: () {
                                            _addToCart(
                                              product,
                                              quantity: 1,
                                              selectedToppings: [],
                                              isRedeemed:
                                                  _selectedCategory ==
                                                  'Redeem points',
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${product.displayName} added to cart',
                                                ),
                                                backgroundColor: _brandNavy,
                                                duration: const Duration(
                                                  milliseconds: 900,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: isSmall ? 26 : 28,
                                            height: isSmall ? 26 : 28,
                                            decoration: BoxDecoration(
                                              color: _brandNavy,
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                child: Text(_l10n?.freshPicksToday ?? (_l10n?.freshPicksToday ?? 'Fresh picks for you today'),
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
    final isBestSelling = _popularProducts.any((p) => p.id == product.id);
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
        child: Stack(
          children: [
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: isWide ? 104 : 90,
                            height: isWide ? 104 : 90,
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
                                      AppLocalizations.of(context)?.runOut ??
                                          (_l10n?.runOut ?? 'Run out'),
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
                      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.displayName,
                            maxLines: isWide ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              fontSize: isSmall ? 13 : 14,
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
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      if (product.promotionPrice != null)
                                        Text(
                                          '₭${product.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: Colors.grey.shade400,
                                            fontSize: isSmall ? 11 : 12,
                                          ),
                                        ),
                                      Text(
                                        '₭${product.effectivePrice.toStringAsFixed(0)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: product.promotionPrice != null
                                              ? Colors.red
                                              : (blocked
                                                    ? Colors.grey
                                                    : _brandNavy),
                                          fontSize: isSmall ? 14 : 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!blocked) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    _addToCart(
                                      product,
                                      quantity: 1,
                                      selectedToppings: [],
                                      isRedeemed: false,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${product.displayName} added to cart',
                                        ),
                                        backgroundColor: _brandNavy,
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _brandNavy,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _brandNavy.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isBestSelling)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x40EF4444),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(_l10n?.bestSeller ?? (_l10n?.bestSeller ?? 'Best Seller'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 9 : 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (product.promotionPrice != null)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Text(_l10n?.promoBadge ?? (_l10n?.promoBadge ?? 'PROMO'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
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
      final bytes = _bytesFromBase64(product.imageBase64!);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallbackImage(),
        );
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

  Widget _buildCurrentCartPanel() {
    final product = _previewProduct;
    final previewBlocked = product?.blockSelfOrder ?? false;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Panel Header (Immersive Image or Placeholder)
            if (product == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _brandNavy.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.touch_app_outlined,
                          size: 40,
                          color: _brandNavy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(_l10n?.selectItemToPreview ?? (_l10n?.selectItemToPreview ?? 'Select an item\nto preview'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Immersive Image Area
              SizedBox(
                height: 220,
                width: double.infinity,
                child: _buildProductImage(product),
              ),

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _brandNavy,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _brandNavy.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'L-POS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _brandGold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Quantity Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_l10n?.quantity ?? (_l10n?.quantity ?? 'Quantity'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _brandNavy,
                            ),
                          ),
                          _QtyStepper(
                            qty: _previewQty,
                            onChanged: previewBlocked
                                ? (v) {}
                                : (val) => setState(() => _previewQty = val),
                            color: _brandNavy,
                            isSmall: true,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Toppings List (Read-only summary with a button to edit)
                      Text(_l10n?.customization ?? (_l10n?.customization ?? 'Customization'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _brandNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: previewBlocked
                            ? null
                            : () => _openToppingsPickerForPreview(product),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _previewToppings.isEmpty
                                      ? (_l10n?.noToppingsSelected ?? 'No Toppings Selected')
                                      : _previewToppings
                                            .map((t) => t.name)
                                            .join(', '),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _previewToppings.isEmpty
                                        ? const Color(0xFF94A3B8)
                                        : _textPrimaryDark,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Total Row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _brandNavy.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_l10n?.subtotal ?? (_l10n?.subtotal ?? 'Subtotal'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '₭${_previewTotal(product, _previewQty, _previewToppings).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _brandNavy,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: previewBlocked
                        ? null
                        : () {
                            _addToCart(
                              product,
                              quantity: _previewQty,
                              selectedToppings: _previewToppings,
                              isRedeemed: false,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.displayName} added to cart'),
                                backgroundColor: _brandNavy,
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: previewBlocked
                          ? Colors.grey
                          : _brandNavy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      previewBlocked ? (_l10n?.runOut ?? 'Run out') : (_l10n?.addToCart ?? 'Add to Cart'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
                            'Toppings for ${product.displayName}',
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
                    Text(_l10n?.optional ?? (_l10n?.optional ?? 'Optional'),
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
                                  : (_l10n?.free ?? 'Free'),
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
                        child: Text(_l10n?.done ?? (_l10n?.done ?? 'Done'),
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
              Text(_l10n?.cartEmpty ?? (_l10n?.cartEmpty ?? 'Your cart is empty'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // "Add items from Home" text
              Text(_l10n?.addItemsFromHome ?? (_l10n?.addItemsFromHome ?? 'Add items from Home'),
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
              final itemNote = item.kitchenNote.trim();
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                // Tapping anywhere on the line opens its kitchen note.
                child: InkWell(
                  onTap: () => _editItemNote(item),
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
                            item.product.displayName,
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                itemNote.isEmpty
                                    ? Icons.add_comment_outlined
                                    : Icons.edit_note_rounded,
                                size: 15,
                                color: itemNote.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.amber.shade800,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  itemNote.isEmpty
                                      ? (_l10n?.addNote ?? 'Add note')
                                      : itemNote,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: itemNote.isEmpty
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                    color: itemNote.isEmpty
                                        ? Colors.grey.shade500
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (item.product.promotionPrice != null) ...[
                                Text(
                                  '₭${item.product.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '₭${item.product.effectivePrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: item.product.promotionPrice != null
                                      ? Colors.red
                                      : _brandNavy,
                                ),
                              ),
                            ],
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
              // Coupon Section
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      // Not `enabled: false`: TextField wraps itself (and its
                      // decoration) in an IgnorePointer when disabled, which
                      // swallowed taps on the remove-X below. readOnly stops
                      // editing but keeps the suffix icon tappable.
                      readOnly: _appliedCouponCode != null,
                      decoration: InputDecoration(
                        hintText: _l10n?.enterCouponCode ?? (_l10n?.enterCouponCode ?? 'Enter coupon code'),
                        // Greyed fill keeps the "locked" cue the disabled state
                        // used to give.
                        filled: _appliedCouponCode != null,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        suffixIcon: _appliedCouponCode != null
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                tooltip:
                                    _l10n?.removeCoupon ?? 'Remove coupon',
                                onPressed: _removeCoupon,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isApplyingCoupon || _appliedCouponCode != null
                        ? null
                        : _applyCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isApplyingCoupon
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _appliedCouponCode != null ? (_l10n?.couponApplied2 ?? 'Applied') : (_l10n?.apply ?? 'Apply'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
              if (_couponDiscount > 0) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discount ($_appliedCouponCode)',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '- ₭${_couponDiscount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_l10n?.total ?? (_l10n?.total ?? 'Total'),
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),

                  Text(
                    '₭${(_cartTotal - _effectiveCouponDiscount).toStringAsFixed(0)}',
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
                      : Text(_l10n?.checkout ?? (_l10n?.checkout ?? 'Checkout'),
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
      return const Center(child: CircularProgressIndicator());
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
              Text(_l10n?.noOrderHistory ?? (_l10n?.noOrderHistory ?? 'No order history yet'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(_l10n?.completedOrdersHere ?? (_l10n?.completedOrdersHere ?? 'Your completed orders will show up here.'),
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
          final deliveryStatus = (item['delivery_status'] ?? '').toString();
          final isOrderPaid =
              (item['state']?.toString().toLowerCase().trim() == 'paid');
          final statusText = _friendlyStatus(
            (item['state'] ?? '').toString(),
            (item['payment_method'] ?? '').toString(),
            deliveryStatus: deliveryStatus,
          );
          final dateLabel = _formatHistoryDateLabel(
            item['date_order']?.toString(),
          );
          final pay = (item['payment_method'] ?? (_l10n?.unknown ?? 'Unknown')).toString();

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
                        Text(_l10n?.status ?? (_l10n?.status ?? 'Status'),
                          style: TextStyle(
                            color: _labelGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        _historyStatusPill(
                          statusText,
                          item['state']?.toString() ?? '',
                          deliveryStatus: deliveryStatus,
                        ),
                      ],
                    ),
                    if (isOrderPaid ||
                        (deliveryStatus.isNotEmpty &&
                            deliveryStatus != 'none' &&
                            deliveryStatus != 'pending')) ...[
                      const SizedBox(height: 12),
                      _buildDeliveryProgress(
                        isOrderPaid ? 'delivered' : deliveryStatus,
                      ),
                    ],
                    if (deliveryStatus == 'on_the_way' ||
                        deliveryStatus == 'arrived') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openRiderMap((item['id'] ?? '').toString()),
                          icon: const Icon(Icons.location_on, size: 18),
                          label: Text(_l10n?.trackRider ?? (_l10n?.trackRider ?? 'Track Rider')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1D4ED8),
                            side: const BorderSide(color: Color(0xFF1D4ED8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                    if ((deliveryStatus == 'preparing' ||
                        deliveryStatus == 'on_the_way' ||
                        deliveryStatus == 'arrived' ||
                        deliveryStatus == 'completed') &&
                        item['id'] != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: Text(deliveryStatus == 'completed'
                              ? (_l10n?.viewChatHistory ?? 'View Chat History')
                              : (_l10n?.chatWithRider ?? 'Chat with Rider')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            final orderId = item['id'];
                            final orderRef = (item['name'] ?? '').toString();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderChatScreen(
                                  orderId: orderId is int
                                      ? orderId
                                      : int.tryParse(orderId.toString()) ?? 0,
                                  orderRef: orderRef,
                                  currentRole: 'customer',
                                  otherPartyName: (_l10n?.roleRider ?? 'Rider'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (dateLabel != '-') ...[
                      const SizedBox(height: 6),
                      _historyMetaRow('Date', dateLabel),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_l10n?.viewOrderDetails ?? (_l10n?.viewOrderDetails ?? 'View order details'),
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

  Widget _historyStatusPill(
    String friendly,
    String rawState, {
    String? deliveryStatus,
  }) {
    final state = rawState.toLowerCase().trim();
    final label = friendly.toLowerCase().trim();
    final ds = (deliveryStatus ?? '').toLowerCase().trim();
    final isWaiting =
        state == 'waiting_transfer_review' || label.contains('waiting');
    final isCancelled = state == 'cancelled' || label.contains('cancel');
    final isConfirmed = state == 'draft' || label.contains('confirm');
    final isPaid = state == 'paid' || label == 'paid';

    Color bg = const Color(0xFFE5EDFF);
    Color fg = const Color(0xFF1E3A8A);
    String text = friendly;

    if (isPaid) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      text = 'Complete';
    } else if (ds == 'delivered') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      text = 'Delivered';
    } else if (ds == 'arrived') {
      bg = const Color(0xFFCCFBF1);
      fg = const Color(0xFF0F766E);
      text = 'Rider arrived';
    } else if (ds == 'on_the_way') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
      text = 'On the way';
    } else if (ds == 'preparing') {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFC2410C);
      text = 'Preparing';
    } else if (isCancelled) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      text = 'Cancelled';
    } else if (isWaiting) {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFC2410C);
      text = 'Waiting transfer verification';
    } else if (isConfirmed) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      text = 'Order confirmed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  String _friendlyStatus(
    String rawState,
    String paymentMethod, {
    String? deliveryStatus,
  }) {
    if (rawState.toLowerCase().trim() == 'paid') {
      return (_l10n?.statusComplete ?? 'Complete');
    }
    final ds = (deliveryStatus ?? '').toLowerCase();
    if (ds == 'delivered') return (_l10n?.statusDelivered ?? 'Delivered');
    if (ds == 'arrived') return (_l10n?.statusRiderArrived ?? 'Rider arrived');
    if (ds == 'on_the_way') return (_l10n?.statusRiderOnWay ?? 'Rider is on the way');
    if (ds == 'preparing') return (_l10n?.statusPreparingYourOrder ?? 'Preparing your order');
    if (rawState == 'waiting_transfer_review') {
      return (_l10n?.statusWaitingTransfer ?? 'Waiting transfer verification');
    }
    if (rawState == 'draft' &&
        paymentMethod.toLowerCase().contains('transfer')) {
      return (_l10n?.statusTransferVerified ?? 'Transfer verified, preparing order');
    }
    if (rawState == 'draft') return (_l10n?.statusOrderConfirmed ?? 'Order confirmed');
    if (rawState == 'paid') return (_l10n?.statusComplete ?? 'Complete');
    if (rawState == 'cancelled') return (_l10n?.statusCancelled ?? 'Cancelled');
    return rawState.isEmpty ? '-' : rawState;
  }

  Widget _buildDeliveryProgress(String deliveryStatus) {
    const steps = ['preparing', 'on_the_way', 'arrived', 'delivered'];
    const labels = ['Preparing', 'On the way', 'Arrived', 'Delivered'];
    final currentIndex = switch (deliveryStatus.toLowerCase().trim()) {
      'preparing' => 0,
      'on_the_way' => 1,
      'arrived' => 2,
      'delivered' => 3,
      _ => -1,
    };
    if (currentIndex < 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_l10n?.deliveryProgress ?? (_l10n?.deliveryProgress ?? 'Delivery progress'),
          style: TextStyle(
            color: _labelGray,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(steps.length, (i) {
            final isActive = i == currentIndex;
            final isDone = i < currentIndex;
            final isPending = i > currentIndex;
            final isLast = i == steps.length - 1;
            final circleColor = isPending
                ? const Color(0xFFE2E8F0)
                : _brandNavy;
            return Expanded(
              child: Opacity(
                opacity: isDone ? 0.5 : 1.0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: circleColor,
                            child: (isActive || isDone)
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: (isActive || isDone)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isPending
                                  ? const Color(0xFF94A3B8)
                                  : _brandNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 16,
                          height: 2,
                          color: isDone
                              ? _brandNavy.withValues(alpha: 0.5)
                              : (isActive
                                    ? _brandNavy
                                    : const Color(0xFFE2E8F0)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _openHistoryDetail(Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => CustomerOrderDetailScreen(
          item: item,
          api: _apiService,
          onRefresh: () => _loadHistory(forceRefresh: true),
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
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
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

        return Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.white)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: constraints.maxHeight * 0.5,
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
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: isSmall ? 24 : 32,
                      bottom: 24,
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
                                  backgroundColor: const Color(0xFFF2F5FF),
                                  backgroundImage:
                                      (_profileImagePath != null &&
                                          File(_profileImagePath!).existsSync())
                                      ? FileImage(File(_profileImagePath!))
                                      : (customerMemoryImage != null)
                                      ? customerMemoryImage
                                      : null,
                                  child:
                                      (_profileImagePath == null ||
                                              !File(
                                                _profileImagePath!,
                                              ).existsSync()) &&
                                          (_customerImageBase64 == null ||
                                              _customerImageBase64!.isEmpty)
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
                                  borderRadius: BorderRadius.circular(999),
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
                                    borderRadius: BorderRadius.circular(999),
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
                        const SizedBox(height: 12),
                        Text(
                          _customerName.isEmpty ? (_l10n?.roleCustomer ?? 'Customer') : _customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isSmall ? 18 : 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _customerDob.isEmpty ? ' ' : 'DOB: $_customerDob',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_clientId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _clientId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_l10n?.clientIdCopied ?? (_l10n?.clientIdCopied ?? 'Client ID copied to clipboard!'),
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Client ID: $_clientId',
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.copy,
                                  size: 14,
                                  color: Color(0xFFE2E8F0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight * 0.5,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 40,
                            bottom: _gestureNavBottomPad(context) + 24,
                          ),
                          child: Column(
                            children: [
                              _profileMenuTile(
                                title: _l10n?.navProfile ?? (_l10n?.navProfile ?? 'Profile'),
                                subtitle:
                                    '${_customerPhone.isEmpty ? '-' : _customerPhone}  •  DOB: ${_customerDob.isEmpty ? '-' : _customerDob}',
                                icon: Icons.person_outline,
                                onTap: _openEditProfileSheet,
                              ),
                              _profileMenuTile(
                                title: _l10n?.rewardsCatalog ?? (_l10n?.rewardsCatalog ?? 'Rewards Catalog'),
                                subtitle: _l10n?.convertPointsIntoItems ?? (_l10n?.convertPointsIntoItems ?? 'Convert your points into free items'),
                                icon: Icons.card_giftcard_outlined,
                                onTap: () {
                                  _openRewardsCatalog();
                                },
                              ),
                              _profileMenuTile(
                                title: _l10n?.myVouchers ?? (_l10n?.myVouchers ?? 'My Vouchers'),
                                subtitle: _l10n?.viewClaimVouchers ?? (_l10n?.viewClaimVouchers ?? 'View and claim your saved vouchers'),
                                icon: Icons.qr_code_scanner_outlined,
                                onTap: () {
                                  _openMyVouchers();
                                },
                              ),
                              _profileMenuTile(
                                title: _l10n?.favoritePlaces ?? (_l10n?.favoritePlaces ?? 'Favorite places'),
                                subtitle: _favoritePlacesSubtitle,
                                icon: Icons.place_outlined,
                                onTap: _openFavoritePlacesSheet,
                              ),
                              _profileNotificationTile(),
                              _profileMenuTile(
                                title: _l10n?.ranking ?? (_l10n?.ranking ?? 'Ranking'),
                                subtitle: _l10n?.seeTop50 ?? (_l10n?.seeTop50 ?? 'See Top 50 rewards leaderboard'),
                                icon: Icons.emoji_events_outlined,
                                trailing: _rewardRank > 0
                                    ? _rankPill(_rewardRank)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RankingScreen(
                                        myRank: _rewardRank <= 0
                                            ? null
                                            : _rewardRank,
                                        myPoints: _rewardPoints,
                                        myName: _customerName,
                                        myImageBase64: _customerImageBase64,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _profileMenuTile(
                                title: _l10n?.customerSupport ?? (_l10n?.customerSupport ?? 'Customer support'),
                                subtitle: _l10n?.supportChannels ?? (_l10n?.supportChannels ?? 'Facebook & WhatsApp (from store settings)'),
                                icon: Icons.support_agent_outlined,
                                isLast: true,
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
                              const SizedBox(height: 32),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmall ? 16 : 24,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoggingOut ? null : _logout,
                                    icon: const Icon(Icons.logout),
                                    label: _isLoggingOut
                                        ? Text(_l10n?.loggingOut ?? (_l10n?.loggingOut ?? 'Logging out...'))
                                        : Text(_l10n?.logout ?? (_l10n?.logout ?? 'Logout')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(
                                        color: Color(0x55FF5252),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: isSmall ? 12 : 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _isDeletingAccount
                                    ? null
                                    : _confirmDeleteAccount,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xAAFF5252),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                child: Text(
                                  _isDeletingAccount
                                      ? (_l10n?.deletingAccount ?? 'Deleting account...')
                                      : (_l10n?.deleteAccount ?? 'Delete account'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 16 : 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reward points: $_rewardPoints',
                                  style: TextStyle(
                                    color: _textPrimaryDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: isSmall ? 14 : 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final Color color;
  final bool isSmall;

  const _QtyStepper({
    required this.qty,
    required this.onChanged,
    required this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FF),
        borderRadius: BorderRadius.circular(isSmall ? 10 : 14),
        border: Border.all(color: const Color(0xFFDCE5FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: isSmall ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: isSmall
                ? const BoxConstraints(minWidth: 32, minHeight: 32)
                : null,
            onPressed: qty <= 1 ? null : () => onChanged(qty - 1),
            icon: Icon(Icons.remove, color: color, size: isSmall ? 18 : 24),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$qty',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: isSmall ? 13 : 15,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: isSmall ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: isSmall
                ? const BoxConstraints(minWidth: 32, minHeight: 32)
                : null,
            onPressed: () => onChanged(qty + 1),
            icon: Icon(Icons.add, color: color, size: isSmall ? 18 : 24),
          ),
        ],
      ),
    );
  }
}

/// Note editor for one cart line.
///
/// A StatefulWidget purely so the controller's lifetime is tied to the dialog's
/// own element: it is disposed in [dispose], after the route has finished
/// tearing down, rather than by the caller the instant showDialog resolves.
class _ItemNoteDialog extends StatefulWidget {
  final String initialNote;
  final String title;
  final String hint;
  final String removeLabel;
  final String cancelLabel;
  final String saveLabel;

  const _ItemNoteDialog({
    required this.initialNote,
    required this.title,
    required this.hint,
    required this.removeLabel,
    required this.cancelLabel,
    required this.saveLabel,
  });

  @override
  State<_ItemNoteDialog> createState() => _ItemNoteDialogState();
}

class _ItemNoteDialogState extends State<_ItemNoteDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        if (widget.initialNote.trim().isNotEmpty)
          TextButton(
            // Empty string means "clear it"; null (dismiss) means "cancel".
            onPressed: () => Navigator.pop(context, ''),
            child: Text(
              widget.removeLabel,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}

class _ProfileEditScreen extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String currentDob;
  final Future<void> Function(String name, String phone, String dob) onSave;

  const _ProfileEditScreen({
    required this.currentName,
    required this.currentPhone,
    required this.currentDob,
    required this.onSave,
  });

  @override
  State<_ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<_ProfileEditScreen> {
  /// Null-safe localisation lookup; every call site keeps its English
  /// literal as a fallback.
  AppLocalizations? get _l10n => AppLocalizations.of(context);

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _dobCtrl;
  String _dob = '';
  bool _isSaving = false;
  bool _isVerifyingOtp = false;
  bool _isSendingOtp = false;
  String _otpError = '';

  static const _navy = Color(0xFF001460);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
    _phoneCtrl = TextEditingController(
      text: widget.currentPhone.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    _dobCtrl = TextEditingController(text: widget.currentDob);
    _dob = widget.currentDob;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_l10n?.editProfile ?? (_l10n?.editProfile ?? 'Edit profile')),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          _buildField(
            label: _l10n?.fullNameCaps ?? (_l10n?.fullNameCaps ?? 'FULL NAME'),
            controller: _nameCtrl,
            icon: Icons.person_outline,
            hintText: _l10n?.yourFullName ?? (_l10n?.yourFullName ?? 'Your Full Name'),
          ),
          const SizedBox(height: 20),
          _buildField(
            label: _l10n?.phoneCaps ?? (_l10n?.phoneCaps ?? 'PHONE'),
            controller: _phoneCtrl,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            hintText: _l10n?.phoneExample ?? (_l10n?.phoneExample ?? 'e.g. 20XXXXXXXX'),
            prefixText: '+856 ',
          ),
          const SizedBox(height: 20),
          _buildDateField(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_l10n?.saveChanges ?? (_l10n?.saveChanges ?? 'Save Changes'),
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
  }

  void _showOtpVerifyDialog(String telbizPhone) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: const Color(0xFFF6F7FB),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_l10n?.otpVerification ?? (_l10n?.otpVerification ?? 'OTP Verification'),
                          style: TextStyle(
                            color: _navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: _isVerifyingOtp || _isSendingOtp
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We have sent a 6-digit OTP to your phone number:\n+856 $telbizPhone',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: _navy,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: const Color(0xFF64748B).withOpacity(0.3),
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFDCE5FF),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFDCE5FF),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.length == 6) {
                          setDialogState(() {
                            _otpError = '';
                          });
                        }
                      },
                    ),
                    if (_otpError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _otpError,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isVerifyingOtp || _isSendingOtp
                            ? null
                            : () async {
                                final enteredCode = otpController.text.trim();
                                if (enteredCode.length != 6) {
                                  setDialogState(() {
                                    _otpError = 'Please enter a 6-digit code';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  _isVerifyingOtp = true;
                                  _otpError = '';
                                });

                                try {
                                  final response = await ApiService().verifyOtp(
                                    telbizPhone,
                                    enteredCode,
                                  );

                                  if (response['status'] != 'success') {
                                    throw Exception(
                                      response['message'] ??
                                          (_l10n?.otpVerificationFailed ?? 'OTP verification failed'),
                                    );
                                  }

                                  // Close OTP dialog
                                  if (!mounted) return;
                                  Navigator.pop(context);

                                  // Set parent state loading
                                  setState(() => _isSaving = true);

                                  // Save profile
                                  await widget.onSave(
                                    _nameCtrl.text,
                                    '+856$telbizPhone',
                                    _dob,
                                  );

                                  if (mounted) {
                                    Navigator.pop(
                                      this.context,
                                    ); // Close ProfileEdit screen
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    _otpError = e.toString().replaceAll(
                                      'Exception: ',
                                      '',
                                    );
                                    _isVerifyingOtp = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isVerifyingOtp
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(_l10n?.verifyAndSave ?? (_l10n?.verifyAndSave ?? 'VERIFY & SAVE'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _isVerifyingOtp || _isSendingOtp
                            ? null
                            : () async {
                                setDialogState(() {
                                  _isSendingOtp = true;
                                  _otpError = '';
                                });
                                try {
                                  final okRes = await ApiService().sendOtp(
                                    telbizPhone,
                                  );
                                  if (okRes['status'] != 'success') {
                                    throw Exception(
                                      okRes['message'] ??
                                          (_l10n?.failedToResendOtp ?? 'Failed to resend OTP'),
                                    );
                                  }
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_l10n?.otpResentSuccessfully ?? (_l10n?.otpResentSuccessfully ?? 'OTP code resent successfully!'),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  setDialogState(() {
                                    _otpError = e.toString().replaceAll(
                                      'Exception: ',
                                      '',
                                    );
                                  });
                                } finally {
                                  setDialogState(() {
                                    _isSendingOtp = false;
                                  });
                                }
                              },
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _navy,
                                ),
                              )
                            : Text(_l10n?.resendCode ?? (_l10n?.resendCode ?? 'Resend Code'),
                                style: TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
      },
    );
  }

  Future<void> _save() async {
    final inputPhone = _phoneCtrl.text.trim();
    String cleaned = inputPhone.replaceAll(RegExp(r'[^\d+]'), '');
    String telbizPhone = cleaned;
    if (telbizPhone.startsWith('+856')) {
      telbizPhone = telbizPhone.substring(4);
    } else if (telbizPhone.startsWith('856')) {
      telbizPhone = telbizPhone.substring(3);
    } else if (telbizPhone.startsWith('020')) {
      telbizPhone = telbizPhone.substring(1);
    } else if (telbizPhone.startsWith('030')) {
      telbizPhone = telbizPhone.substring(1);
    }
    telbizPhone = telbizPhone.trim();

    if (telbizPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.phoneNumberIsRequired ?? (_l10n?.phoneNumberIsRequired ?? 'Phone number is required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!telbizPhone.startsWith('20') || telbizPhone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.phoneMustStartWith20 ?? (_l10n?.phoneMustStartWith20 ?? 'Phone number must start with 20 and be exactly 10 digits long (e.g. 20XXXXXXXX)'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String currentCleaned = widget.currentPhone.replaceAll(
      RegExp(r'[^\d+]'),
      '',
    );
    String currentTelbiz = currentCleaned;
    if (currentTelbiz.startsWith('+856')) {
      currentTelbiz = currentTelbiz.substring(4);
    } else if (currentTelbiz.startsWith('856')) {
      currentTelbiz = currentTelbiz.substring(3);
    } else if (currentTelbiz.startsWith('020')) {
      currentTelbiz = currentTelbiz.substring(1);
    } else if (currentTelbiz.startsWith('030')) {
      currentTelbiz = currentTelbiz.substring(1);
    }
    currentTelbiz = currentTelbiz.trim();

    // If phone number has NOT changed, just save directly
    if (telbizPhone == currentTelbiz) {
      setState(() => _isSaving = true);
      try {
        await widget.onSave(_nameCtrl.text, widget.currentPhone, _dob);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        debugPrint('[Profile] Failed to save profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n?.couldNotSaveProfile ?? (_l10n?.couldNotSaveProfile ?? 'Could not save profile. Please try again.')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    // Phone number HAS changed. Send OTP first.
    setState(() => _isSaving = true);
    try {
      final res = await ApiService().sendOtp(telbizPhone);
      if (res['status'] != 'success') {
        throw Exception(res['message'] ?? (_l10n?.failedToSendOtp ?? 'Failed to send OTP'));
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Open OTP Dialog
      _showOtpVerifyDialog(telbizPhone);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? hintText,
    String? prefixText,
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
        Container(
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
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    prefixText: prefixText,
                    prefixStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_l10n?.dateOfBirthCaps ?? (_l10n?.dateOfBirthCaps ?? 'DATE OF BIRTH'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dobCtrl,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            prefixIcon: const Icon(Icons.cake_outlined, color: _navy),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _pickDate,
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
              borderSide: const BorderSide(color: _navy, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime initial = DateTime(now.year - 20, 1, 1);
    try {
      final parts = _dobCtrl.text.split('-');
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
    _dobCtrl.text = iso;
    setState(() => _dob = iso);
  }
}

class _FavoritePlacesScreen extends StatefulWidget {
  final List<_FavoritePlace> favoritePlaces;
  final String? selectedPlaceId;
  final void Function(String id) onSelectPlace;
  final Future<void> Function(_FavoritePlace place) onDeletePlace;
  final VoidCallback? onAddPlace;

  const _FavoritePlacesScreen({
    required this.favoritePlaces,
    required this.selectedPlaceId,
    required this.onSelectPlace,
    required this.onDeletePlace,
    this.onAddPlace,
  });

  @override
  State<_FavoritePlacesScreen> createState() => _FavoritePlacesScreenState();
}

class _FavoritePlacesScreenState extends State<_FavoritePlacesScreen> {
  /// Null-safe localisation lookup; every call site keeps its English
  /// literal as a fallback.
  AppLocalizations? get _l10n => AppLocalizations.of(context);

  late List<_FavoritePlace> _places;
  late String? _selectedId;

  static const _navy = Color(0xFF001460);

  @override
  void initState() {
    super.initState();
    _places = List.from(widget.favoritePlaces);
    _selectedId = widget.selectedPlaceId;
  }

  void _delete(_FavoritePlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n?.deletePlaceTitle ?? (_l10n?.deletePlaceTitle ?? 'Delete place?')),
        content: Text('Remove "${place.name}" from your favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n?.cancel ?? (_l10n?.cancel ?? 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n?.delete ?? (_l10n?.delete ?? 'Delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _places.removeWhere((p) => p.id == place.id);
      if (_selectedId == place.id) {
        _selectedId = _places.isNotEmpty ? _places.first.id : null;
      }
    });
    await widget.onDeletePlace(place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_l10n?.favoritePlaces ?? (_l10n?.favoritePlaces ?? 'Favorite places')),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: widget.onAddPlace),
        ],
      ),
      body: _places.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.place_outlined,
                      size: 36,
                      color: _navy.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(_l10n?.noFavoritePlaces ?? (_l10n?.noFavoritePlaces ?? 'No favorite places saved yet.'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final place = _places[index];
                final isSelected = _selectedId == place.id;
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _navy : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: isSelected
                        ? const Color(0xFFEFF6FF)
                        : null,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _navy.withValues(alpha: 0.1)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.place_outlined,
                        color: isSelected ? _navy : const Color(0xFF94A3B8),
                      ),
                    ),
                    title: Text(
                      place.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: () => _delete(place),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () {
                      setState(() => _selectedId = place.id);
                      widget.onSelectPlace(place.id);
                    },
                  ),
                );
              },
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

class _RiderTrackingSheet extends StatefulWidget {
  final String orderId;
  final ApiService apiService;
  final Map<String, dynamic>? initialLocation;
  final double? destinationLat;
  final double? destinationLng;

  const _RiderTrackingSheet({
    required this.orderId,
    required this.apiService,
    this.initialLocation,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  State<_RiderTrackingSheet> createState() => _RiderTrackingSheetState();
}

class _RiderTrackingSheetState extends State<_RiderTrackingSheet> {
  /// Null-safe localisation lookup; every call site keeps its English
  /// literal as a fallback.
  AppLocalizations? get _l10n => AppLocalizations.of(context);

  GoogleMapController? _mapController;
  Timer? _refreshTimer;
  Timer? _animTimer;
  BitmapDescriptor? _bikeMarker;
  final GlobalKey _markerCaptureKey = GlobalKey();

  double _riderLat = 0;
  double _riderLng = 0;
  double _targetLat = 0;
  double _targetLng = 0;
  bool _hasLocation = false;
  bool _isLoading = true;

  // Directions API variables
  List<LatLng> _routePoints = [];
  String? _apiDurationText;
  String? _apiDistanceText;
  LatLng? _lastRouteFetchedLatLng;
  bool _isFetchingRoute = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialLocation;
    if (init != null) {
      _targetLat = (init['latitude'] ?? 0).toDouble();
      _targetLng = (init['longitude'] ?? 0).toDouble();
      _riderLat = _targetLat;
      _riderLng = _targetLng;
      _hasLocation = true;
      _isLoading = false;
    }
    _fetchLocation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchLocation();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animTimer?.cancel();
    super.dispose();
  }

  void _captureMarkerIcon() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_bikeMarker != null) return;
      try {
        final boundary =
            _markerCaptureKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary == null) return;
        final image = await boundary.toImage(pixelRatio: 3);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          setState(
            () => _bikeMarker = BitmapDescriptor.fromBytes(
              byteData.buffer.asUint8List(),
            ),
          );
        }
      } catch (_) {}
    });
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final rad = 3.141592653589793 / 180;
    final dLat = (lat2 - lat1) * rad;
    final dLng = (lng2 - lng1) * rad;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * rad) * cos(lat2 * rad) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(sqrt(a));
    return r * c;
  }

  String _formatEta(double distanceKm) {
    if (distanceKm < 0.1) return (_l10n?.arrivingSoon ?? 'Arriving soon');
    final hours = distanceKm / 50;
    final totalMinutes = (hours * 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m}m';
  }

  Future<void> _fetchLocation() async {
    try {
      final loc = await widget.apiService.fetchRiderLocation(widget.orderId);
      if (!mounted) return;
      if (loc != null) {
        final newLat = (loc['latitude'] ?? 0).toDouble();
        final newLng = (loc['longitude'] ?? 0).toDouble();
        debugPrint(
          "[Customer Tracking] Fetched rider location: ($newLat, $newLng)",
        );
        setState(() {
          _targetLat = newLat;
          _targetLng = newLng;
          _isLoading = false;
          _hasLocation = true;
        });

        // Smart route fetch: if we haven't fetched yet, or if rider moved > 150 meters
        if (_lastRouteFetchedLatLng == null) {
          _fetchRoute();
        } else {
          final double distanceMoved =
              _distanceKm(
                newLat,
                newLng,
                _lastRouteFetchedLatLng!.latitude,
                _lastRouteFetchedLatLng!.longitude,
              ) *
              1000.0;
          if (distanceMoved > 150.0) {
            _fetchRoute();
          }
        }

        _startSmoothAnimation();
      } else {
        debugPrint("[Customer Tracking] Rider location is null");
        if (!_hasLocation) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("[Customer Tracking] Error fetching rider location: $e");
      if (mounted && !_hasLocation) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRoute() async {
    if (_isFetchingRoute) return;
    final destLat = widget.destinationLat;
    final destLng = widget.destinationLng;
    if (!_hasLocation || destLat == null || destLng == null) return;

    final apiKey = (dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '').trim();
    if (apiKey.isEmpty) {
      debugPrint("[Customer Tracking] GOOGLE_MAPS_API_KEY is empty.");
      return;
    }

    setState(() => _isFetchingRoute = true);

    try {
      final currentLatLng = LatLng(_targetLat, _targetLng);
      final url =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
            'origin': '$_targetLat,$_targetLng',
            'destination': '$destLat,$destLng',
            'key': apiKey,
          });

      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'OK') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0] as Map;
            final legs = route['legs'] as List;
            final overviewPolyline = route['overview_polyline'] as Map;
            final pointsStr = overviewPolyline['points'] as String;

            final points = _decodePolyline(pointsStr);

            String? duration;
            String? distance;
            if (legs.isNotEmpty) {
              final leg = legs[0] as Map;
              duration = leg['duration']['text'] as String;
              distance = leg['distance']['text'] as String;
            }

            if (mounted) {
              setState(() {
                _routePoints = points;
                _apiDurationText = duration;
                _apiDistanceText = distance;
                _lastRouteFetchedLatLng = currentLatLng;
              });
            }
            debugPrint(
              "[Customer Tracking] Successfully fetched route from Directions API.",
            );
            return;
          }
        } else {
          debugPrint(
            "[Customer Tracking] Directions API status not OK: ${data['status']}",
          );
        }
      } else {
        debugPrint(
          "[Customer Tracking] Directions API HTTP status: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("[Customer Tracking] Error fetching Directions API: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetchingRoute = false);
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.add(LatLng(lat / 1E5, lng / 1E5));
      }
    } catch (e) {
      debugPrint("[Customer Tracking] Error decoding polyline: $e");
    }
    return points;
  }

  void _startSmoothAnimation() {
    _animTimer?.cancel();
    // Animate camera to the NEW target once (not on every 100ms tick)
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(_targetLat, _targetLng)),
    );
    _animTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        _animTimer?.cancel();
        return;
      }
      final remainingLat = _targetLat - _riderLat;
      final remainingLng = _targetLng - _riderLng;
      const step = 0.12;
      _riderLat += remainingLat * step;
      _riderLng += remainingLng * step;
      final close =
          remainingLat.abs() < 0.000001 && remainingLng.abs() < 0.000001;
      if (close) {
        _riderLat = _targetLat;
        _riderLng = _targetLng;
        _animTimer?.cancel();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    _captureMarkerIcon();

    final destLat = widget.destinationLat;
    final destLng = widget.destinationLng;
    final eta = (_hasLocation && destLat != null && destLng != null)
        ? (_apiDurationText != null
              ? (_apiDistanceText != null
                    ? '$_apiDurationText ($_apiDistanceText)'
                    : _apiDurationText!)
              : _formatEta(_distanceKm(_riderLat, _riderLng, destLat, destLng)))
        : null;

    final markers = <Marker>{};
    if (_hasLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(_riderLat, _riderLng),
          icon:
              _bikeMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: _l10n?.roleRider ?? (_l10n?.roleRider ?? 'Rider')),
        ),
      );
    }
    if (destLat != null && destLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _l10n?.deliveryLocation ?? (_l10n?.deliveryLocation ?? 'Delivery location')),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (_hasLocation && destLat != null && destLng != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints.isNotEmpty
              ? _routePoints
              : [LatLng(_riderLat, _riderLng), LatLng(destLat, destLng)],
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.6),
          width: 4,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Hidden icon render target (0 opacity — still rendered for capture)
          Opacity(
            opacity: 0,
            child: RepaintBoundary(
              key: _markerCaptureKey,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D4ED8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.delivery_dining,
                color: Color(0xFF1D4ED8),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(_l10n?.liveRiderTracking ?? (_l10n?.liveRiderTracking ?? 'Live Rider Tracking'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: _CustomerSelfOrderScreenState._textPrimaryDark,
                ),
              ),
              const Spacer(),
              if (eta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        eta,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_hasLocation) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        size: 10,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 4),
                      Text(_l10n?.liveBadge ?? (_l10n?.liveBadge ?? 'LIVE'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (eta != null && destLat != null && destLng != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_bike,
                    size: 18,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 8),
                  Text(_l10n?.statusRiderOnWay ?? (_l10n?.statusRiderOnWay ?? 'Rider is on the way'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _CustomerSelfOrderScreenState._textPrimaryDark,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ETA: $eta',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  if (_hasLocation)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_riderLat, _riderLng),
                        zoom: 16,
                      ),
                      markers: markers,
                      polylines: polylines,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoading) ...[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(_l10n?.fetchingRiderLocation ?? (_l10n?.fetchingRiderLocation ?? 'Fetching rider location…'),
                              style: TextStyle(
                                color: _CustomerSelfOrderScreenState._labelGray,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.location_off,
                              size: 48,
                              color: Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 8),
                            Text(_l10n?.noLocationData ?? (_l10n?.noLocationData ?? 'No location data yet'),
                              style: TextStyle(
                                color: _CustomerSelfOrderScreenState._labelGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_l10n?.riderLocationWillAppear ?? (_l10n?.riderLocationWillAppear ?? 'Rider location will appear here once available'),
                              style: TextStyle(
                                color: _CustomerSelfOrderScreenState._labelGray,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _isLoading = true);
                                _fetchLocation();
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(_l10n?.retry ?? (_l10n?.retry ?? 'Retry')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_hasLocation)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_l10n?.riderLocation ?? (_l10n?.riderLocation ?? 'Rider location'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _CustomerSelfOrderScreenState._labelGray,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_riderLat.toStringAsFixed(6)}, ${_riderLng.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _CustomerSelfOrderScreenState
                                    ._textPrimaryDark,
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
        ],
      ),
    );
  }
}
