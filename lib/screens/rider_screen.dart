import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'rider_navigation_screen.dart';

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
  List<Map<String, dynamic>> _orders = [];
  String? _errorMessage;
  Timer? _locationTimer;
  bool _locationPermissionGranted = false;
  bool _isSendingLocation = false;

  Map<String, double>? _parseLatLngFromUrl(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      // Check query parameters like 'q' or 'query'
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

      // Check path for patterns like @18.0123,102.6123
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

  static const Color _navy = Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
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
    for (final order in _orders) {
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
        for (final order in _orders) {
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
          _orders = List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _deliveryStatusLabel(String? status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'preparing': return 'Preparing';
      case 'on_the_way': return 'On The Way';
      case 'arrived': return 'Arrived';
      case 'delivered': return 'Delivered';
      default: return status ?? 'Unknown';
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
        title: const Text('Rider Dashboard'),
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
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _orders.isEmpty
                  ? _buildEmpty()
                  : _buildOrderList(),
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
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No delivery orders yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here once assigned',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final lines = List<Map<String, dynamic>>.from(order['lines'] ?? []);
    final total = (order['amount_total'] as num?)?.toDouble() ?? 0.0;
    final ref = order['order_reference'] ?? '';
    final customer = order['customer_name'] ?? '';
    final phone = order['customer_phone'] ?? '';
    final place = order['delivery_place_name'] ?? '';
    final address = order['delivery_place_address'] ?? '';
    final status = order['delivery_status']?.toString() ?? 'none';
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
                  if (hasValidCoordinates && (status == 'on_the_way' || status == 'arrived')) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: const Text('Navigate (In App)'),
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
                            Text(
                              'Open in Google Maps App',
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
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line['product_name'] ?? 'Item',
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
              )),
          if (status == 'on_the_way' || status == 'arrived') ...[
            const SizedBox(height: 12),
            const Divider(),
            Row(
              children: [
                if (status == 'on_the_way')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAction(order['id'], 'arrived'),
                      icon: const Icon(Icons.location_on, size: 18),
                      label: const Text('Arrived'),
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
                    label: const Text('Complete'),
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
}
