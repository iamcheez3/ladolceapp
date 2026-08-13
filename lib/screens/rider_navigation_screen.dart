import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/http_client_wrapper.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class RiderNavigationScreen extends StatefulWidget {
  final int orderId;
  final String orderRef;
  final String customerName;
  final String customerPhone;
  final String deliveryPlace;
  final String deliveryAddress;
  final double destinationLat;
  final double destinationLng;
  final String mapsUrl;
  final String initialStatus;

  const RiderNavigationScreen({
    super.key,
    required this.orderId,
    required this.orderRef,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryPlace,
    required this.deliveryAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.mapsUrl,
    required this.initialStatus,
  });

  @override
  State<RiderNavigationScreen> createState() => _RiderNavigationScreenState();
}

class _RiderNavigationScreenState extends State<RiderNavigationScreen> {
  final ApiService _apiService = ApiService();
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;

  double _riderLat = 0;
  double _riderLng = 0;
  bool _hasRiderLocation = false;
  bool _isActionLoading = false;
  String _currentStatus = '';
  double _distanceKm = 0.0;
  bool _isSendingLocation = false;

  // Directions API variables
  List<LatLng> _routePoints = [];
  String? _apiDurationText;
  String? _apiDistanceText;
  LatLng? _lastRouteFetchedLatLng;
  bool _isFetchingRoute = false;

  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _accentBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    // 1. Get initial position and send it immediately
    Position? initPos;
    try {
      initPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint(
        "[Rider Nav] Initial getCurrentPosition failed: $e. Trying last known position...",
      );
      try {
        initPos = await Geolocator.getLastKnownPosition();
      } catch (err) {
        debugPrint("[Rider Nav] Initial getLastKnownPosition failed: $err");
      }
    }

    if (initPos != null && mounted) {
      final lat = initPos.latitude;
      final lng = initPos.longitude;
      setState(() {
        _riderLat = lat;
        _riderLng = lng;
        _hasRiderLocation = true;
        _calculateDistance();
      });
      _sendLocationUpdate(initPos.latitude, initPos.longitude);
      _fetchRoute();
      _zoomToIncludeMarkers();
    }

    // 2. Subscribe to location changes for real-time map marker movement
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Update when moving 3+ meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (!mounted) return;
            final lat = position.latitude;
            final lng = position.longitude;
            setState(() {
              _riderLat = lat;
              _riderLng = lng;
              _hasRiderLocation = true;
              _calculateDistance();
            });
            _sendLocationUpdate(lat, lng);

            // Smart route fetch: if we haven't fetched yet, or if we moved > 150 meters
            if (_lastRouteFetchedLatLng == null) {
              _fetchRoute();
            } else {
              final double distanceMoved = Geolocator.distanceBetween(
                lat,
                lng,
                _lastRouteFetchedLatLng!.latitude,
                _lastRouteFetchedLatLng!.longitude,
              );
              if (distanceMoved > 150.0) {
                _fetchRoute();
              }
            }

            _animateCameraToRider();
          },
          onError: (e) {
            debugPrint("[Rider Nav] Location stream error: $e");
          },
        );

    // 3. Heartbeat update (every 8 seconds) to guarantee posting location even if stationary
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_hasRiderLocation) {
        _sendLocationUpdate(_riderLat, _riderLng);
      }
    });
  }

  void _calculateDistance() {
    if (!_hasRiderLocation) return;
    final distMeters = Geolocator.distanceBetween(
      _riderLat,
      _riderLng,
      widget.destinationLat,
      widget.destinationLng,
    );
    _distanceKm = distMeters / 1000.0;
  }

  Future<void> _fetchRoute() async {
    if (_isFetchingRoute) return;
    if (!_hasRiderLocation) return;

    final apiKey = (dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '').trim();
    if (apiKey.isEmpty) {
      debugPrint(
        "[Rider Nav] GOOGLE_MAPS_API_KEY is empty. Skipping Directions fetch.",
      );
      return;
    }

    setState(() => _isFetchingRoute = true);

    try {
      final currentLatLng = LatLng(_riderLat, _riderLng);
      final url =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
            'origin': '$_riderLat,$_riderLng',
            'destination': '${widget.destinationLat},${widget.destinationLng}',
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
              "[Rider Nav] Successfully fetched route from Directions API.",
            );
            return;
          }
        } else {
          debugPrint(
            "[Rider Nav] Directions API status not OK: ${data['status']}",
          );
        }
      } else {
        debugPrint(
          "[Rider Nav] Directions API HTTP status: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("[Rider Nav] Error fetching Directions API: $e");
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
      debugPrint("[Rider Nav] Error decoding polyline: $e");
    }
    return points;
  }

  Future<void> _sendLocationUpdate(double lat, double lng) async {
    if (_isSendingLocation) return;
    _isSendingLocation = true;
    try {
      await _apiService.riderUpdateLocation(
        orderId: widget.orderId,
        latitude: lat,
        longitude: lng,
      );
      debugPrint("[Rider Nav] Posted location update to server: ($lat, $lng)");
    } catch (e) {
      debugPrint("[Rider Nav] Failed to post location update: $e");
    } finally {
      _isSendingLocation = false;
    }
  }

  void _animateCameraToRider() {
    if (_mapController == null || !_hasRiderLocation) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(_riderLat, _riderLng)),
    );
  }

  void _zoomToIncludeMarkers() {
    if (_mapController == null || !_hasRiderLocation) return;
    final riderLatLng = LatLng(_riderLat, _riderLng);
    final destLatLng = LatLng(widget.destinationLat, widget.destinationLng);

    // Bounds containing both rider and target
    final bounds = LatLngBounds(
      southwest: LatLng(
        riderLatLng.latitude < destLatLng.latitude
            ? riderLatLng.latitude
            : destLatLng.latitude,
        riderLatLng.longitude < destLatLng.longitude
            ? riderLatLng.longitude
            : destLatLng.longitude,
      ),
      northeast: LatLng(
        riderLatLng.latitude > destLatLng.latitude
            ? riderLatLng.latitude
            : destLatLng.latitude,
        riderLatLng.longitude > destLatLng.longitude
            ? riderLatLng.longitude
            : destLatLng.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80.0), // Padding
    );
  }

  Future<void> _makePhoneCall() async {
    if (widget.customerPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: widget.customerPhone);
    try {
      await launchUrl(launchUri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not launch dialer')));
    }
  }

  Future<void> _openExternalMaps() async {
    if (widget.mapsUrl.isEmpty) return;
    final uri = Uri.tryParse(widget.mapsUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch external maps application'),
          ),
        );
      }
    }
  }

  Future<void> _handleStatusAction(String action) async {
    setState(() => _isActionLoading = true);
    try {
      if (action == 'arrived') {
        await _apiService.riderArrived(widget.orderId);
        if (!mounted) return;
        setState(() => _currentStatus = 'arrived');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated to Arrived'),
            backgroundColor: Colors.teal,
          ),
        );
      } else if (action == 'complete') {
        await _apiService.riderComplete(widget.orderId);
        if (!mounted) return;
        setState(() => _currentStatus = 'delivered');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated to Complete / Delivered'),
            backgroundColor: Colors.green,
          ),
        );
        // Automatically pop screen once complete
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  String _formatEta(double distKm) {
    if (distKm < 0.1) return 'Arriving soon';
    final hours = distKm / 40; // Assume average speed of 40 km/h
    final totalMinutes = (hours * 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final destLatLng = LatLng(widget.destinationLat, widget.destinationLng);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('destination'),
        position: destLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.deliveryPlace.isNotEmpty
              ? widget.deliveryPlace
              : 'Delivery Target',
          snippet: widget.deliveryAddress,
        ),
      ),
    };

    if (_hasRiderLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(_riderLat, _riderLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'You (Rider)'),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (_hasRiderLocation) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('navigation_route'),
          points: _routePoints.isNotEmpty
              ? _routePoints
              : [LatLng(_riderLat, _riderLng), destLatLng],
          color: _accentBlue.withOpacity(0.8),
          width: 6,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate: ${widget.orderRef}'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isFetchingRoute
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh route',
            onPressed: _isFetchingRoute ? null : _fetchRoute,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Fit route on screen',
            onPressed: _zoomToIncludeMarkers,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map Widget
          GoogleMap(
            initialCameraPosition: CameraPosition(target: destLatLng, zoom: 15),
            markers: markers,
            polylines: polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            onMapCreated: (controller) {
              _mapController = controller;
              if (_hasRiderLocation) {
                _zoomToIncludeMarkers();
              }
            },
          ),

          // Floating recenter button
          if (_hasRiderLocation)
            Positioned(
              right: 16,
              top: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: _navy,
                onPressed: _animateCameraToRider,
                child: const Icon(Icons.my_location),
              ),
            ),

          // Loading overlay for actions
          if (_isActionLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Navigation bottom panel
          Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    String etaText = 'Calculating…';
    String distanceText = '…';

    if (_hasRiderLocation) {
      if (_apiDurationText != null && _apiDistanceText != null) {
        etaText = _apiDurationText!;
        distanceText = _apiDistanceText!;
      } else {
        etaText = _formatEta(_distanceKm);
        distanceText = '${_distanceKm.toStringAsFixed(1)} km';
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ETA and Distance Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: _accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          etaText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _accentBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.navigation_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Active Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _currentStatus == 'arrived'
                          ? Colors.teal.withOpacity(0.15)
                          : _currentStatus == 'delivered'
                          ? Colors.green.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _currentStatus == 'arrived'
                          ? 'Arrived'
                          : _currentStatus == 'delivered'
                          ? 'Delivered'
                          : 'On The Way',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _currentStatus == 'arrived'
                            ? Colors.teal
                            : _currentStatus == 'delivered'
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer name & Delivery Details
              Text(
                widget.customerName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (widget.deliveryPlace.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.deliveryPlace,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                widget.deliveryAddress,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              // Action buttons row
              Row(
                children: [
                  // Call button
                  if (widget.customerPhone.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.phone_in_talk,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _makePhoneCall,
                      tooltip: 'Call Customer',
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Fallback External Maps launcher button
                  if (widget.mapsUrl.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.directions, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _openExternalMaps,
                      tooltip: 'Open in External Google Maps app',
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Arrived / Complete Actions
                  Expanded(
                    child: Row(
                      children: [
                        if (_currentStatus == 'on_the_way')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleStatusAction('arrived'),
                              icon: const Icon(Icons.location_on, size: 18),
                              label: const Text('Arrived'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (_currentStatus == 'on_the_way')
                          const SizedBox(width: 10),
                        if (_currentStatus == 'on_the_way' ||
                            _currentStatus == 'arrived')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleStatusAction('complete'),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Complete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
