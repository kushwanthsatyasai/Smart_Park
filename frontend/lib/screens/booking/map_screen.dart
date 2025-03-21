import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
            if (lot['description'] != null) ...[
              Text(
                lot['description'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                        ? () => _navigateToBooking(lot, distance)
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

  void _navigateToBooking(Map<String, dynamic> lot, double distance) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.pushNamed(
      context,
      '/booking',
      arguments: {
        'parking_lot': lot,
        'distance': distance,
      },
    );
  }

  void _updateMarkers() {
    final markers = _parkingLots.map((lot) {
      final slots = lot['parking_slots'] as List;
      final availableSlots =
          slots.where((slot) => slot['is_available'] == true).length;

      return Marker(
        markerId: MarkerId(lot['id'].toString()),
        position: LatLng(
          double.parse(lot['latitude'].toString()),
          double.parse(lot['longitude'].toString()),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(availableSlots > 0
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed),
        onTap: () => _showParkingDetails(lot),
      );
    }).toSet();

    setState(() {
      _markers = markers;
      _updateCircleRadius(); // Update the circle when markers are updated
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

  // Update the build method to add a prominent filter button
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
        ],
      ),
      body: Stack(
        children: [
          if (_isMapReady)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      )
                    : const LatLng(20.5937, 78.9629),
                zoom: 15,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controllerCompleter.complete(controller);
                _mapController = controller;
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(
                      LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                    ),
                  );
                }
              },
              markers: _markers,
              circles: _circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              compassEnabled: true,
            ),
          // Radius indicator and filter button
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
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeMap,
        child: const Icon(Icons.my_location),
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
      _updateCircleRadius();
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

  // Add this method to the _MapScreenState class
  void _updateCircleRadius() {
    if (_currentPosition == null) return;

    final circles = {
      Circle(
        circleId: const CircleId('searchRadius'),
        center: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        radius: _searchRadius,
        fillColor: Colors.blue.withOpacity(0.1),
        strokeColor: Colors.blue.withOpacity(0.3),
        strokeWidth: 1,
      ),
      Circle(
        circleId: const CircleId('userLocation'),
        center: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        radius: 10,
        fillColor: Colors.blue,
        strokeColor: Colors.white,
        strokeWidth: 2,
      ),
    };

    setState(() {
      _circles = circles;
    });

    // Adjust map camera to show the entire search radius
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          _getZoomLevel(_searchRadius),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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
