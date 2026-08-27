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
  static const Color _navy = Color(0xFF1E3A8A);

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

  Color _deliveryStatusColor(String? status) {
    switch (status) {
      case 'pending':
      case 'preparing': return Colors.orange;
      case 'on_the_way': return Colors.blue;
      case 'arrived': return Colors.teal;
      case 'delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _deliveryStatusIcon(String? status) {
    switch (status) {
      case 'pending':
      case 'preparing': return Icons.hourglass_empty;
      case 'on_the_way': return Icons.delivery_dining;
      case 'arrived': return Icons.location_on;
      case 'delivered': return Icons.check_circle;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          if (_locationTimer != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.gps_fixed, size: 18, color: Colors.green[300]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                widget.riderName,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
            tooltip: AppLocalizations.of(context)?.refresh ?? (AppLocalizations.of(context)?.refresh ?? 'Refresh'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: AppLocalizations.of(context)?.logout ?? (AppLocalizations.of(context)?.logout ?? 'Logout'),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchOrders,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)?.refresh ?? (AppLocalizations.of(context)?.refresh ?? 'Refresh')),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchOrders,
              child: Text(AppLocalizations.of(context)?.retry ?? (AppLocalizations.of(context)?.retry ?? 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders, {bool isHistory = false}) {
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], isHistory: isHistory);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {bool isHistory = false}) {
    final lines = List<Map<String, dynamic>>.from(order['lines'] ?? []);
    final total = (order['amount_total'] as num?)?.toDouble() ?? 0.0;
    final ref = order['order_reference'] ?? '';
    final customer = order['customer_name'] ?? '';
    final phone = order['customer_phone'] ?? '';
    final place = order['delivery_place_name'] ?? '';
    final address = order['delivery_place_address'] ?? '';
    final status = order['delivery_status']?.toString() ?? 'none';
    final mapsUrl = order['delivery_maps_url']?.toString() ?? '';
    final orderNote = order['note']?.toString() ?? '';

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(_deliveryStatusIcon(status), color: _deliveryStatusColor(status)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ref,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _navy,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _deliveryStatusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _deliveryStatusLabel(status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _deliveryStatusColor(status),
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.isNotEmpty)
              Text('Customer: $customer',
                  style: TextStyle(color: Colors.grey[700])),
            Text(
              'Total: LAK ${total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
        children: [
          if (phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(phone, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
          if (orderNote.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customer Note:\n$orderNote',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (place.isNotEmpty || address.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (place.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(place,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(address,
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                  if (!isHistory && hasValidCoordinates && (status == 'on_the_way' || status == 'arrived')) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: Text(AppLocalizations.of(context)?.navigateInApp ?? (AppLocalizations.of(context)?.navigateInApp ?? 'Navigate (In App)')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1,
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
                    ),
                  ],
                  if (mapsUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Text(AppLocalizations.of(context)?.openInGoogleMapsApp ?? (AppLocalizations.of(context)?.openInGoogleMapsApp ?? 'Open in Google Maps App'),
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Divider(),
          ...lines.map((line) {
            final lineNote = line['note']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bilingualName(
                            line,
                            fallback:
                                AppLocalizations.of(context)?.item ?? 'Item',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text('x${line['qty']}',
                          style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(width: 12),
                      Text(
                        'LAK ${(line['subtotal'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (lineNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 8),
                      child: Text(
                        '- $lineNote',
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            );
          }),
          if (order['id'] != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(isHistory ? (AppLocalizations.of(context)?.viewChatHistory ?? 'View Chat History') : (AppLocalizations.of(context)?.chatWithCustomer ?? 'Chat with Customer')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
            ),
          ],
          if (!isHistory && (status == 'on_the_way' || status == 'arrived')) ...[
            const SizedBox(height: 12),
            const Divider(),
            Row(
              children: [
                if (status == 'on_the_way')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAction(order['id'], 'arrived'),
                      icon: const Icon(Icons.location_on, size: 18),
                      label: Text(AppLocalizations.of(context)?.statusArrived ?? (AppLocalizations.of(context)?.statusArrived ?? 'Arrived')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                if (status == 'on_the_way') const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleAction(order['id'], 'complete'),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text(AppLocalizations.of(context)?.statusComplete ?? (AppLocalizations.of(context)?.statusComplete ?? 'Complete')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dashboardCard(
            icon: Icons.delivery_dining,
            title: AppLocalizations.of(context)?.totalOrders ?? (AppLocalizations.of(context)?.totalOrders ?? 'Total Orders'),
            value: '$totalOrders',
            color: _navy,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dashboardCard(
                  icon: Icons.timer,
                  title: AppLocalizations.of(context)?.active ?? (AppLocalizations.of(context)?.active ?? 'Active'),
                  value: '$activeOrders',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dashboardCard(
                  icon: Icons.check_circle,
                  title: AppLocalizations.of(context)?.completed ?? (AppLocalizations.of(context)?.completed ?? 'Completed'),
                  value: '$completedOrders',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dashboardCard(
            icon: Icons.attach_money,
            title: AppLocalizations.of(context)?.totalRevenue ?? (AppLocalizations.of(context)?.totalRevenue ?? 'Total Revenue'),
            value: 'LAK ${totalRevenue.toStringAsFixed(0)}',
            color: Colors.teal,
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context)?.ordersByStatus ?? (AppLocalizations.of(context)?.ordersByStatus ?? 'Orders by Status'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildStatusRow(Icons.hourglass_empty, 'Pending', pendingCount, Colors.orange),
          ..._buildStatusRow(Icons.coffee, 'Preparing', preparingCount, Colors.orange),
          ..._buildStatusRow(Icons.delivery_dining, 'On The Way', onTheWayCount, Colors.blue),
          ..._buildStatusRow(Icons.location_on, 'Arrived', arrivedCount, Colors.teal),
          ..._buildStatusRow(Icons.check_circle, 'Delivered', completedOrders, Colors.green),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusRow(IconData icon, String label, int count, Color color) {
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _navy,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildBottomNav() {
    return Theme(
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
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: _navy.withOpacity(0.5)),
            selectedIcon: const Icon(Icons.receipt_long, color: _navy),
            label: AppLocalizations.of(context)?.order ?? (AppLocalizations.of(context)?.order ?? 'Order'),
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, color: _navy.withOpacity(0.5)),
            selectedIcon: const Icon(Icons.history, color: _navy),
            label: AppLocalizations.of(context)?.navHistory ?? (AppLocalizations.of(context)?.navHistory ?? 'History'),
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: _navy.withOpacity(0.5)),
            selectedIcon: const Icon(Icons.dashboard, color: _navy),
            label: AppLocalizations.of(context)?.dashboard ?? (AppLocalizations.of(context)?.dashboard ?? 'Dashboard'),
          ),
        ],
      ),
    );
  }
}
