import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import './booking_screen.dart';
import '../qr_display_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isMapReady = false;
  List<Map<String, dynamic>> _parkingLots = [];
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  double _searchRadius = 2000; // Default radius 2km in meters
  List<Map<String, dynamic>> _allParkingLots = []; // Store all parking lots

  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(20.5937, 78.9629), // Default to India's center
    zoom: 5,
  );

  // Add radius options
  final List<Map<String, dynamic>> _radiusOptions = [
    {'label': '100 m', 'value': 100.0},
    {'label': '200 m', 'value': 200.0},
    {'label': '300 m', 'value': 300.0},
    {'label': '500 m', 'value': 500.0},
    {'label': '1 km', 'value': 1000.0},
    {'label': '2 km', 'value': 2000.0},
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);
    try {
      // Request location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied';
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isMapReady = true;
      });

      // Load nearby parking lots
      await _loadNearbyParkingLots();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyParkingLots() async {
    if (_currentPosition == null) return;

    try {
      final response = await _supabase.from('parking_lots').select('''
            *,
            parking_slots (
              id,
              slot_number,
              vehicle_type,
              is_available,
              rate_per_hour
            )
          ''');

      final lots = List<Map<String, dynamic>>.from(response);
      _allParkingLots = lots; // Store all parking lots

      // Filter lots within selected radius
      final nearbyLots = lots.where((lot) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          double.parse(lot['latitude'].toString()),
          double.parse(lot['longitude'].toString()),
        );
        return distance <= _searchRadius;
      }).toList();

      setState(() {
        _parkingLots = nearbyLots;
        _updateMarkers();
      });

      // Show radius adjustment dialog if no parking lots found
      if (nearbyLots.isEmpty && mounted) {
        _showFilterBottomSheet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parking lots: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showParkingDetails(Map<String, dynamic> lot) {
    final slots = lot['parking_slots'] as List;
    final availableSlots =
        slots.where((slot) => slot['is_available'] == true).length;

    // Get the minimum rate from available slots
    final availableSlotsList =
        slots.where((slot) => slot['is_available'] == true).toList();
    final minRate = availableSlotsList.isEmpty
        ? 0.0
        : availableSlotsList
            .map((slot) => slot['rate_per_hour'] as num)
            .reduce((a, b) => a < b ? a : b);

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      double.parse(lot['latitude'].toString()),
      double.parse(lot['longitude'].toString()),
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lot['name'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.local_parking),
                    Text('$availableSlots/${slots.length}'),
                    const Text('Available'),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.currency_rupee),
                    Text(
                      '₹${minRate.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text('per hour'),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.location_on),
                    Text(
                      distance < 1000
                          ? '${distance.toStringAsFixed(0)}m'
                          : '${(distance / 1000).toStringAsFixed(1)}km',
                    ),
                    const Text('Distance'),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.timer),
                    Text(
                      '${(distance / 400).ceil()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('min walk'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openDirections(lot),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: availableSlots > 0
                        ? () => _navigateToBooking(lot)
                        : null,
                    icon: const Icon(Icons.book_online),
                    label: const Text('Book Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(Map<String, dynamic> lot) async {
    final lat = double.parse(lot['latitude'].toString());
    final lng = double.parse(lot['longitude'].toString());
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open directions')),
        );
      }
    }
  }

  void _navigateToBooking(Map<String, dynamic> lot) async {
    Navigator.pop(context); // Close bottom sheet
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(parkingData: lot),
      ),
    );

    if (result != null && result['success'] == true) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRDisplayScreen(
              booking: result['booking_details'],
              parkingLotName: lot['name'],
              slotNumber: result['assigned_slot']['slot_number'],
              bookingTime: DateTime.parse(result['booking_details']['booking_time']),
              duration: result['booking_details']['duration'],
              totalFee: result['booking_details']['total_fee'].toString(),
            ),
          ),
        );
      }
    }
  }

  void _updateMarkers() {
    if (_currentPosition == null) return;

    final Set<Marker> markers = {};
    final Set<Circle> circles = {};

    // Add current location circle (solid blue)
    circles.add(
      Circle(
        circleId: const CircleId('current_location'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: 20, // 20 meters radius for current location
        fillColor: Colors.blue.withOpacity(0.3),
        strokeColor: Colors.white,
        strokeWidth: 2,
      ),
    );

    // Add search radius circle (transparent blue)
    circles.add(
      Circle(
        circleId: const CircleId('search_area'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: _searchRadius,
        fillColor: Colors.blue.withOpacity(0.1),
        strokeColor: Colors.blue,
        strokeWidth: 1,
      ),
    );

    // Add parking lot markers with custom colors based on availability
    for (final lot in _parkingLots) {
      final slots = lot['parking_slots'] as List;
      final availableSlots = slots.where((slot) => slot['is_available'] == true).length;
      final totalSlots = slots.length;
      
      // Determine marker color based on availability percentage
      double hue;
      if (availableSlots == 0) {
        hue = BitmapDescriptor.hueRed; // No slots available
      } else if (availableSlots == totalSlots) {
        hue = BitmapDescriptor.hueGreen; // All slots available
      } else {
        hue = BitmapDescriptor.hueYellow; // Some slots available
      }
      
      markers.add(
        Marker(
          markerId: MarkerId('lot_${lot['id']}'),
          position: LatLng(
            double.parse(lot['latitude'].toString()),
            double.parse(lot['longitude'].toString()),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () => _showParkingDetails(lot),
          infoWindow: InfoWindow(
            title: lot['name'],
            snippet: '$availableSlots/$totalSlots slots available',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  // Add this method to show the filter bottom sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search Radius',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Quick select buttons in a grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: _radiusOptions.map((option) {
                  final bool isSelected = _searchRadius == option['value'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _searchRadius = option['value'];
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        option['label'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateParkingLotsWithNewRadius();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Apply Filter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Parking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeMap,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isMapReady)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            GoogleMap(
              initialCameraPosition: _currentPosition != null
                  ? CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 15,
                    )
                  : const CameraPosition(
                      target: LatLng(20.5937, 78.9629),
                      zoom: 5,
                    ),
              myLocationEnabled: false, // Using custom marker for location
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              markers: _markers,
              circles: _circles,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _controllerCompleter.complete(controller);
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      15,
                    ),
                  );
                }
                _updateMarkers();
              },
            ),
          // Search radius indicator
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: _showFilterBottomSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt),
                      const SizedBox(width: 8),
                      Text(
                        'Search Radius: ${_searchRadius < 1000 ? '${_searchRadius.toInt()} m' : '${(_searchRadius / 1000).toStringAsFixed(1)} km'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_parkingLots.length} found',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              if (_currentPosition != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    15,
                  ),
                );
              }
            },
            heroTag: 'location',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _initializeMap,
            heroTag: 'refresh',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // Update the _updateParkingLotsWithNewRadius method
  void _updateParkingLotsWithNewRadius() {
    if (_currentPosition == null) return;

    final nearbyLots = _allParkingLots.where((lot) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        double.parse(lot['latitude'].toString()),
        double.parse(lot['longitude'].toString()),
      );
      return distance <= _searchRadius;
    }).toList();

    setState(() {
      _parkingLots = nearbyLots;
      _updateMarkers();
    });

    // Adjust map zoom based on radius
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          _getZoomLevel(_searchRadius),
        ),
      );
    }

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Found ${nearbyLots.length} parking lots within ${(_searchRadius / 1000).toStringAsFixed(1)} km',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Helper method to calculate appropriate zoom level
  double _getZoomLevel(double radius) {
    if (radius <= 100) return 18.0;
    if (radius <= 200) return 17.0;
    if (radius <= 300) return 16.5;
    if (radius <= 500) return 16.0;
    if (radius <= 1000) return 15.0;
    return 14.0; // for 2km
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<int> _getAvailableSlots(String lotId) async {
    try {
      final response = await _supabase
          .from('parking_slots')
          .select()
          .eq('parking_lot_id', lotId)
          .eq('is_available', true);
      
      return (response as List).length;
    } catch (e) {
      print('Error getting available slots: $e');
      return 0;
    }
  }

  Future<int> _getTotalSlots(String lotId) async {
    try {
      final response = await _supabase
          .from('parking_slots')
          .select()
          .eq('parking_lot_id', lotId);
      
      return (response as List).length;
    } catch (e) {
      print('Error getting total slots: $e');
      return 0;
    }
  }
}

Future<List<Map<String, dynamic>>> _fetchParkingLots() async {
  try {
    final response = await Supabase.instance.client
        .from('parking_lots')
        .select()
        .eq('is_active', true); // Remove .execute()

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    print('Error fetching parking lots: $e');
    return [];
  }
}
