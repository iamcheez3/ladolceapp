import 'dart:async';
import '../utils/bilingual_name.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/push_notifications_service.dart';
import 'login_screen.dart';
import 'rider_navigation_screen.dart';
import 'order_chat_screen.dart';
import '../utils/money.dart';
import '../theme/ld.dart';

class RiderScreen extends StatefulWidget {
  final String riderName;
  final int riderId;

  const RiderScreen({
    super.key,
    required this.riderName,
    required this.riderId,
  });

  @override
  State<RiderScreen> createState() => _RiderScreenState();
}

class _RiderScreenState extends State<RiderScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];
  String? _errorMessage;
  Timer? _locationTimer;
  bool _locationPermissionGranted = false;
  bool _isSendingLocation = false;
  int _selectedTabIndex = 0;

  List<Map<String, dynamic>> get _currentOrders => _allOrders.where((o) {
        final s = (o['delivery_status'] ?? '').toString();
        return s != 'delivered';
      }).toList();

  List<Map<String, dynamic>> get _historyOrders => _allOrders.where((o) {
        final s = (o['delivery_status'] ?? '').toString();
        return s == 'delivered';
      }).toList();

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

  @override
  void initState() {
    super.initState();
    PushNotificationsService.setAppActive(true);
    _checkInitialLocationPermission();
    _fetchOrders();
  }

  Future<void> _checkInitialLocationPermission() async {
    try {
      final status = await Permission.location.status;
      if (status.isGranted) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled && mounted) {
          setState(() => _locationPermissionGranted = true);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    PushNotificationsService.setAppActive(false);
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _sendLocationUpdate();
    _locationTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _sendLocationUpdate();
    });
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  bool _hasActiveOrders() {
    for (final order in _currentOrders) {
      final status = (order['delivery_status'] ?? '').toString();
      if (status == 'on_the_way' || status == 'arrived') return true;
    }
    return false;
  }

  Future<void> _sendLocationUpdate() async {
    if (!_locationPermissionGranted || _isSendingLocation) return;
    _isSendingLocation = true;
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (e) {
        debugPrint("[Rider tracking] getCurrentPosition failed: $e. Trying last known position...");
        try {
          pos = await Geolocator.getLastKnownPosition();
        } catch (err) {
          debugPrint("[Rider tracking] getLastKnownPosition failed: $err");
        }
      }

      if (pos != null) {
        for (final order in _currentOrders) {
          final status = (order['delivery_status'] ?? '').toString();
          if (status == 'on_the_way' || status == 'arrived') {
            await _apiService.riderUpdateLocation(
              orderId: order['id'],
              latitude: pos.latitude,
              longitude: pos.longitude,
            );
            debugPrint("[Rider tracking] Sent location update: (${pos.latitude}, ${pos.longitude}) for order ${order['id']}");
          }
        }
      } else {
        debugPrint("[Rider tracking] Could not retrieve any position (both current and last known were null)");
      }
    } catch (e) {
      debugPrint("[Rider tracking] Unexpected error in _sendLocationUpdate: $e");
    } finally {
      _isSendingLocation = false;
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) {
          if (mounted) setState(() => _locationPermissionGranted = true);
          debugPrint("[Rider tracking] Location permission granted & services enabled.");
        } else {
          debugPrint("[Rider tracking] Location permission granted but services are disabled.");
        }
      } else {
        debugPrint("[Rider tracking] Location permission denied: $status");
      }
    } catch (e) {
      debugPrint("[Rider tracking] Error requesting location permission: $e");
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.fetchRiderOrders();
      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
        if (_hasActiveOrders()) {
          if (!_locationPermissionGranted) {
            await _requestLocationPermission();
          }
          _startLocationTracking();
        } else {
          _stopLocationTracking();
        }
      }
    } catch (e) {
      debugPrint('[Rider] fetchOrders failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load orders. Please check your connection and try again.';
        });
      }
    }
  }

  Future<void> _logout() async {
    _stopLocationTracking();
    await _apiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _handleAction(int orderId, String action) async {
    try {
      if (action == 'arrived') {
        await _apiService.riderArrived(orderId);
      } else if (action == 'complete') {
        await _apiService.riderComplete(orderId);
      }
      await _fetchOrders();
    } catch (e) {
      debugPrint('[Rider] handleAction failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.actionFailedPleaseTryAgain ?? (AppLocalizations.of(context)?.actionFailedPleaseTryAgain ?? 'Action failed. Please try again.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _deliveryStatusLabel(String? status) {
    switch (status) {
      case 'pending': return (AppLocalizations.of(context)?.pending ?? 'Pending');
      case 'preparing': return (AppLocalizations.of(context)?.statusPreparing ?? 'Preparing');
      case 'on_the_way': return (AppLocalizations.of(context)?.onTheWay ?? 'On The Way');
      case 'arrived': return (AppLocalizations.of(context)?.statusArrived ?? 'Arrived');
      case 'delivered': return (AppLocalizations.of(context)?.statusDelivered ?? 'Delivered');
      default: return status ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown');
    }
  }

  /// Text / icon color of a delivery status (always shown with its label).
  Color _deliveryStatusColor(String? status) {
    switch (status) {
      case 'pending':
      case 'preparing': return Ld.warning;
      case 'on_the_way': return Ld.navy;
      case 'arrived': return Ld.info;
      case 'delivered': return Ld.success;
      default: return Ld.muted;
    }
  }

  /// Soft background matching [_deliveryStatusColor].
  Color _deliveryStatusWash(String? status) {
    switch (status) {
      case 'pending':
      case 'preparing': return Ld.warningWash;
      case 'on_the_way': return Ld.ground;
      case 'arrived': return Ld.infoWash;
      case 'delivered': return Ld.successWash;
      default: return Ld.ground;
    }
  }

  IconData _deliveryStatusIcon(String? status) {
    switch (status) {
      case 'pending':
      case 'preparing': return Icons.hourglass_empty_rounded;
      case 'on_the_way': return Icons.delivery_dining_outlined;
      case 'arrived': return Icons.location_on_outlined;
      case 'delivered': return Icons.check_circle_outline_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  Widget _statusPill(String status) => LdPill(
        _deliveryStatusLabel(status),
        icon: _deliveryStatusIcon(status),
        background: _deliveryStatusWash(status),
        foreground: _deliveryStatusColor(status),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: LdHeader(
        title: _appBarTitle(),
        subtitle: widget.riderName,
        actions: [
          if (_locationTimer != null)
            Tooltip(
              message: l10n?.riderLocation ?? 'Rider location',
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Ld.successStrong,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.gps_fixed_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
          LdNavIconButton(
            icon: Icons.refresh_rounded,
            onPressed: _fetchOrders,
            tooltip: AppLocalizations.of(context)?.refresh ?? (AppLocalizations.of(context)?.refresh ?? 'Refresh'),
          ),
          LdNavIconButton(
            icon: Icons.logout_rounded,
            onPressed: _logout,
            tooltip: AppLocalizations.of(context)?.logout ?? (AppLocalizations.of(context)?.logout ?? 'Logout'),
          ),
        ],
      ),
      backgroundColor: Ld.ground,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  String _appBarTitle() {
    switch (_selectedTabIndex) {
      case 0: return (AppLocalizations.of(context)?.currentOrders ?? 'Current Orders');
      case 1: return (AppLocalizations.of(context)?.orderHistory ?? 'Order History');
      case 2: return (AppLocalizations.of(context)?.dashboard ?? 'Dashboard');
      default: return (AppLocalizations.of(context)?.roleRider ?? 'Rider');
    }
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Ld.navy));
    if (_errorMessage != null) return _buildError();

    switch (_selectedTabIndex) {
      case 0:
        return _currentOrders.isEmpty
            ? _buildEmpty(AppLocalizations.of(context)?.noCurrentOrders ?? 'No current orders', 'Active orders will appear here')
            : _buildOrderList(_currentOrders);
      case 1:
        return _historyOrders.isEmpty
            ? _buildEmpty(AppLocalizations.of(context)?.noHistoryYet ?? 'No history yet', 'Completed orders will appear here')
            : _buildOrderList(_historyOrders, isHistory: true);
      case 2:
        return _buildDashboard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LdIconTile(Icons.delivery_dining_outlined,
                size: 80, background: Ld.surface, color: Ld.faint),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Ld.title(19),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Ld.label,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchOrders,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)?.refresh ?? (AppLocalizations.of(context)?.refresh ?? 'Refresh')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Ld.navy,
                backgroundColor: Ld.surface,
                side: const BorderSide(color: Ld.line),
                minimumSize: const Size(160, Ld.tap),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LdIconTile(Icons.error_outline_rounded,
                size: 64, background: Ld.dangerWash, color: Ld.danger),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: Ld.body),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _fetchOrders,
              style: FilledButton.styleFrom(
                backgroundColor: Ld.navy,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, Ld.tap),
              ),
              child: Text(AppLocalizations.of(context)?.retry ?? (AppLocalizations.of(context)?.retry ?? 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  /// The order the rider is on right now: the first one on the way / at
  /// the door, else the first open one.
  int _heroIndex(List<Map<String, dynamic>> orders) {
    final i = orders.indexWhere((o) {
      final s = (o['delivery_status'] ?? '').toString();
      return s == 'on_the_way' || s == 'arrived';
    });
    return i < 0 ? 0 : i;
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders, {bool isHistory = false}) {
    final hero = isHistory ? -1 : _heroIndex(orders);
    final rest = <Map<String, dynamic>>[
      for (var i = 0; i < orders.length; i++)
        if (i != hero) orders[i],
    ];
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: Ld.navy,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth >= 600 ? 24.0 : 12.0;
          // Keep cards readable on wide tablets.
          final extra = c.maxWidth > 820 ? (c.maxWidth - 820) / 2 : 0.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side + extra, 14, side + extra, 24),
            children: [
              if (hero >= 0) _buildCurrentCard(orders[hero]),
              if (hero >= 0 && rest.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
                  child: Text(
                    '${AppLocalizations.of(context)?.orders ?? 'Orders'} (${rest.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ld.muted,
                    ),
                  ),
                ),
              for (final o in rest) _buildOrderCard(o, isHistory: isHistory),
            ],
          );
        },
      ),
    );
  }

  ({double? lat, double? lng, bool valid}) _destination(Map<String, dynamic> order) {
    final mapsUrl = order['delivery_maps_url']?.toString() ?? '';
    final rawLat = order['delivery_latitude'];
    final rawLng = order['delivery_longitude'];
    double? destLat;
    double? destLng;
    if (rawLat != null) {
      destLat = (rawLat is num) ? rawLat.toDouble() : double.tryParse(rawLat.toString());
    }
    if (rawLng != null) {
      destLng = (rawLng is num) ? rawLng.toDouble() : double.tryParse(rawLng.toString());
    }

    if ((destLat == null || destLng == null || destLat == 0.0 || destLng == 0.0) && mapsUrl.isNotEmpty) {
      final parsed = _parseLatLngFromUrl(mapsUrl);
      if (parsed != null) {
        destLat = parsed['latitude'];
        destLng = parsed['longitude'];
      }
    }
    final hasValidCoordinates = destLat != null && destLng != null && destLat != 0.0 && destLng != 0.0;
    return (lat: destLat, lng: destLng, valid: hasValidCoordinates);
  }

  /// "Current delivery" card: map band, customer, amount, details and the
  /// actions, always open.
  Widget _buildCurrentCard(Map<String, dynamic> order) {
    final total = (order['amount_total'] as num?)?.toDouble() ?? 0.0;
    final ref = order['order_reference'] ?? '';
    final customer = order['customer_name'] ?? '';
    final place = (order['delivery_place_name'] ?? '').toString();
    final address = (order['delivery_place_address'] ?? '').toString();
    final status = order['delivery_status']?.toString() ?? 'none';
    final where = place.isNotEmpty ? place : address;

    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ExcludeSemantics(
                  child: CustomPaint(painter: _MapBandPainter()),
                ),
                if (where.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: LdPill(
                        where,
                        icon: Icons.place_outlined,
                        background: Ld.surface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  customer.toString().isNotEmpty ? customer.toString() : ref.toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Ld.title(19),
                ),
                if (customer.toString().isNotEmpty)
                  Text(ref.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ld.label),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: _statusPill(status)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(AppLocalizations.of(context)?.total ?? 'Total',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ld.small),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text('LAK ${money(total)}', style: Ld.price(20, color: Ld.ink)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._orderDetails(order, isHistory: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {bool isHistory = false}) {
    final total = (order['amount_total'] as num?)?.toDouble() ?? 0.0;
    final ref = order['order_reference'] ?? '';
    final customer = order['customer_name'] ?? '';
    final status = order['delivery_status']?.toString() ?? 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: Ld.card(),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: Ld.navy,
          collapsedIconColor: Ld.muted,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: LdIconTile(
            _deliveryStatusIcon(status),
            background: _deliveryStatusWash(status),
            color: _deliveryStatusColor(status),
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ref.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Ld.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: Text('LAK ${money(total)}', style: Ld.price(16, color: Ld.ink, weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusPill(status),
                if (customer.toString().isNotEmpty)
                  Text('Customer: $customer', style: Ld.small),
              ],
            ),
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: _orderDetails(order, isHistory: isHistory),
        ),
      ),
    );
  }

  /// Phone, note, place, lines, chat and the delivery actions of an order.
  List<Widget> _orderDetails(Map<String, dynamic> order, {required bool isHistory}) {
    final lines = List<Map<String, dynamic>>.from(order['lines'] ?? []);
    final ref = order['order_reference'] ?? '';
    final customer = order['customer_name'] ?? '';
    final phone = order['customer_phone'] ?? '';
    final place = order['delivery_place_name'] ?? '';
    final address = order['delivery_place_address'] ?? '';
    final status = order['delivery_status']?.toString() ?? 'none';
    final mapsUrl = order['delivery_maps_url']?.toString() ?? '';
    final orderNote = order['note']?.toString() ?? '';

    final dest = _destination(order);
    final destLat = dest.lat;
    final destLng = dest.lng;
    final hasValidCoordinates = dest.valid;

    const btnShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Ld.rMd)));
    const btnText = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    return [
      if (phone.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.phone_outlined, size: 18, color: Ld.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(phone, style: Ld.body.copyWith(fontSize: 15))),
            ],
          ),
        ),
      if (orderNote.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: Ld.card(radius: Ld.r, color: Ld.warningWash, border: Ld.lineSoft),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.edit_note_rounded, size: 20, color: Ld.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customer Note:\n$orderNote',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Ld.ink,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      if (place.isNotEmpty || address.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: Ld.card(radius: Ld.r, color: Ld.ground, border: Ld.lineSoft),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (place.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18, color: Ld.navy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(place,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Ld.ink)),
                    ),
                  ],
                ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(address, style: Ld.label),
              ],
              if (!isHistory && hasValidCoordinates && (status == 'on_the_way' || status == 'arrived')) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.navigation_outlined, size: 20),
                  label: Text(AppLocalizations.of(context)?.navigateInApp ?? (AppLocalizations.of(context)?.navigateInApp ?? 'Navigate (In App)'),
                      maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    backgroundColor: Ld.navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(Ld.tap),
                    shape: btnShape,
                    textStyle: btnText,
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RiderNavigationScreen(
                          orderId: order['id'],
                          orderRef: ref,
                          customerName: customer,
                          customerPhone: phone,
                          deliveryPlace: place,
                          deliveryAddress: address,
                          destinationLat: destLat!,
                          destinationLng: destLng!,
                          mapsUrl: mapsUrl,
                          initialStatus: status,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchOrders();
                    }
                  },
                ),
              ],
              if (mapsUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(mapsUrl);
                    if (uri != null) {
                      try {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {}
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Ld.navy,
                    minimumSize: const Size.fromHeight(44),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(
                    AppLocalizations.of(context)?.openInGoogleMapsApp ?? (AppLocalizations.of(context)?.openInGoogleMapsApp ?? 'Open in Google Maps App'),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      const Divider(height: 1, color: Ld.line),
      const SizedBox(height: 6),
      ...lines.map((line) {
        final lineNote = line['note']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${line['qty']}×',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Ld.navy)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bilingualName(
                        line,
                        fallback:
                            AppLocalizations.of(context)?.item ?? 'Item',
                      ),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Ld.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LAK ${money(line['subtotal'] as num?)}',
                    style: Ld.price(15, color: Ld.ink, weight: FontWeight.w600),
                  ),
                ],
              ),
              if (lineNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 26),
                  child: Text(
                    '- $lineNote',
                    style: const TextStyle(fontSize: 13, color: Ld.danger, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        );
      }),
      if (order['id'] != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
          label: Text(
              isHistory ? (AppLocalizations.of(context)?.viewChatHistory ?? 'View Chat History') : (AppLocalizations.of(context)?.chatWithCustomer ?? 'Chat with Customer'),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: Ld.navy,
            side: const BorderSide(color: Ld.line),
            minimumSize: const Size.fromHeight(Ld.tap),
            shape: btnShape,
            textStyle: btnText,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderChatScreen(
                  orderId: order['id'] as int,
                  orderRef: order['order_reference']?.toString() ?? '',
                  currentRole: 'rider',
                  otherPartyName: order['customer_name']?.toString() ?? (AppLocalizations.of(context)?.roleCustomer ?? 'Customer'),
                ),
              ),
            );
          },
        ),
      ],
      if (!isHistory && (status == 'on_the_way' || status == 'arrived')) ...[
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final arrived = OutlinedButton.icon(
            onPressed: () => _handleAction(order['id'], 'arrived'),
            icon: const Icon(Icons.location_on_outlined, size: 20),
            label: Text(AppLocalizations.of(context)?.statusArrived ?? (AppLocalizations.of(context)?.statusArrived ?? 'Arrived'),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: Ld.navy,
              side: const BorderSide(color: Ld.navy),
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: btnShape,
              textStyle: btnText,
            ),
          );
          final complete = FilledButton.icon(
            onPressed: () => _handleAction(order['id'], 'complete'),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(AppLocalizations.of(context)?.statusComplete ?? (AppLocalizations.of(context)?.statusComplete ?? 'Complete'),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            style: FilledButton.styleFrom(
              backgroundColor: Ld.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: btnShape,
              textStyle: btnText,
            ),
          );
          // Narrow phones: one full-width button per row.
          if (status == 'on_the_way' && c.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [arrived, const SizedBox(height: 10), complete],
            );
          }
          return Row(
            children: [
              if (status == 'on_the_way') Expanded(child: arrived),
              if (status == 'on_the_way') const SizedBox(width: 10),
              Expanded(child: complete),
            ],
          );
        }),
      ],
    ];
  }

  Widget _buildDashboard() {
    final totalOrders = _allOrders.length;
    final activeOrders = _currentOrders.length;
    final completedOrders = _historyOrders.length;
    final totalRevenue = _allOrders.fold<double>(
      0, (sum, o) => sum + ((o['amount_total'] as num?)?.toDouble() ?? 0));

    final pendingCount = _allOrders.where((o) => (o['delivery_status'] ?? '').toString() == 'pending').length;
    final preparingCount = _allOrders.where((o) => (o['delivery_status'] ?? '').toString() == 'preparing').length;
    final onTheWayCount = _allOrders.where((o) => (o['delivery_status'] ?? '').toString() == 'on_the_way').length;
    final arrivedCount = _allOrders.where((o) => (o['delivery_status'] ?? '').toString() == 'arrived').length;

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: Ld.navy,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth >= 600 ? 24.0 : 12.0;
          final extra = c.maxWidth > 820 ? (c.maxWidth - 820) / 2 : 0.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side + extra, 14, side + extra, 24),
            children: [
              _dashboardCard(
                icon: Icons.delivery_dining_outlined,
                title: AppLocalizations.of(context)?.totalOrders ?? (AppLocalizations.of(context)?.totalOrders ?? 'Total Orders'),
                value: '$totalOrders',
                color: Ld.navy,
                wash: Ld.ground,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dashboardCard(
                      icon: Icons.timer_outlined,
                      title: AppLocalizations.of(context)?.active ?? (AppLocalizations.of(context)?.active ?? 'Active'),
                      value: '$activeOrders',
                      color: Ld.warning,
                      wash: Ld.warningWash,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dashboardCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: AppLocalizations.of(context)?.completed ?? (AppLocalizations.of(context)?.completed ?? 'Completed'),
                      value: '$completedOrders',
                      color: Ld.success,
                      wash: Ld.successWash,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _dashboardCard(
                icon: Icons.payments_outlined,
                title: AppLocalizations.of(context)?.totalRevenue ?? (AppLocalizations.of(context)?.totalRevenue ?? 'Total Revenue'),
                value: 'LAK ${money(totalRevenue)}',
                color: Ld.info,
                wash: Ld.infoWash,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(AppLocalizations.of(context)?.ordersByStatus ?? (AppLocalizations.of(context)?.ordersByStatus ?? 'Orders by Status'),
                  style: Ld.title(18),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: Ld.card(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildStatusRow('pending', pendingCount),
                    _buildStatusRow('preparing', preparingCount),
                    _buildStatusRow('on_the_way', onTheWayCount),
                    _buildStatusRow('arrived', arrivedCount),
                    _buildStatusRow('delivered', completedOrders, last: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color wash,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: Ld.card(),
      child: Row(
        children: [
          LdIconTile(icon, background: wash, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ld.small,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: Ld.price(22)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String status, int count, {bool last = false}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Ld.lineSoft)),
      ),
      child: Row(
        children: [
          Icon(_deliveryStatusIcon(status), size: 20, color: _deliveryStatusColor(status)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _deliveryStatusLabel(status),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Ld.ink,
              ),
            ),
          ),
          LdBadge(
            '$count',
            color: _deliveryStatusWash(status),
            textColor: _deliveryStatusColor(status),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ld.line)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            indicatorColor: Ld.ground,
            elevation: 0,
            height: 68,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 13,
                color: states.contains(WidgetState.selected) ? Ld.navy : Ld.muted,
              ),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedTabIndex = index),
          backgroundColor: Ld.surface,
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined, color: Ld.muted),
              selectedIcon: const Icon(Icons.receipt_long_rounded, color: Ld.navy),
              label: AppLocalizations.of(context)?.order ?? (AppLocalizations.of(context)?.order ?? 'Order'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_rounded, color: Ld.muted),
              selectedIcon: const Icon(Icons.history_rounded, color: Ld.navy),
              label: AppLocalizations.of(context)?.navHistory ?? (AppLocalizations.of(context)?.navHistory ?? 'History'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined, color: Ld.muted),
              selectedIcon: const Icon(Icons.dashboard_rounded, color: Ld.navy),
              label: AppLocalizations.of(context)?.dashboard ?? (AppLocalizations.of(context)?.dashboard ?? 'Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Illustrative street-map band on the current delivery card (decorative,
/// not a live map: the live map is in [RiderNavigationScreen]).
class _MapBandPainter extends CustomPainter {
  const _MapBandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFDCE3F0));
    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 10;
    for (final y in [size.height * 0.35, size.height * 0.72]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), street);
    }
    for (final x in [size.width * 0.25, size.width * 0.64]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), street);
    }
    final start = Offset(size.width * 0.16, size.height * 0.82);
    final end = Offset(size.width * 0.84, size.height * 0.22);
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(size.width * 0.34, start.dy, size.width * 0.34, size.height * 0.42,
          size.width * 0.56, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.42, end.dx, end.dy);
    canvas.drawPath(
      route,
      Paint()
        ..color = Ld.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(start, 8, Paint()..color = Ld.navy);
    canvas.drawCircle(end, 10, Paint()..color = Ld.gold);
    canvas.drawCircle(
      end,
      10,
      Paint()
        ..color = Ld.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_MapBandPainter oldDelegate) => false;
}
