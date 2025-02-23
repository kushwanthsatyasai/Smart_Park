import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import '../../utils/map_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final supabase = Supabase.instance.client;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _parkingLots = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }

      await _fetchNearbyParkingLots();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchNearbyParkingLots() async {
    if (_currentPosition == null) return;

    try {
      final response = await supabase
          .from('parking_lots')
          .select('*, parking_slots(*)')
          .execute();

      if (response == null || response.data == null) {
        throw 'Failed to fetch parking lots';
      }

      List<Map<String, dynamic>> lots = List<Map<String, dynamic>>.from(response.data);
      
      // Calculate distances and filter nearby lots (within 5km)
      lots = lots.where((lot) {
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lot['latitude'],
          lot['longitude'],
        );
        lot['distance'] = distance;
        return distance <= 5000; // 5km radius
      }).toList();

      // Sort by distance
      lots.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() {
        _parkingLots = lots;
        _updateMarkers();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching parking lots: $e')),
        );
      }
    }
  }

  void _updateMarkers() {
    Set<Marker> newMarkers = {};

    for (var lot in _parkingLots) {
      int availableSlots = (lot['parking_slots'] as List)
          .where((slot) => slot['is_available'] == true)
          .length;

      newMarkers.add(
        Marker(
          markerId: MarkerId(lot['id'].toString()),
          position: LatLng(
            lot['latitude'],
            lot['longitude'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            availableSlots > 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed
          ),
          infoWindow: InfoWindow(
            title: lot['name'],
            snippet: 'Available: $availableSlots | ${(lot['distance'] / 1000).toStringAsFixed(2)}km',
          ),
          onTap: () => _showParkingLotDetails(lot, availableSlots),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _showParkingLotDetails(Map<String, dynamic> lot, int availableSlots) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lot['name'],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Distance: ${(lot['distance'] / 1000).toStringAsFixed(2)} km',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Available Slots: $availableSlots',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Price: ₹${lot['price_per_hour']}/hour',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showRoute(lot),
                  icon: const Icon(Icons.directions),
                  label: const Text('Show Route'),
                ),
                ElevatedButton.icon(
                  onPressed: availableSlots > 0
                      ? () => Navigator.pushNamed(
                            context,
                            '/booking-details',
                            arguments: {
                              'parking_lot': lot,
                              'distance': lot['distance'],
                            },
                          )
                      : null,
                  icon: const Icon(Icons.local_parking),
                  label: const Text('Book Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoute(Map<String, dynamic> lot) async {
    if (_currentPosition == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&destination=${lot['latitude']},${lot['longitude']}'
      '&travelmode=driving'
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Parking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(20.5937, 78.9629), // Default to India's center
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              setState(() {
                _mapController = controller;
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                    ),
                  );
                }
              });
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            circles: _currentPosition != null
                ? {
                    Circle(
                      circleId: const CircleId('currentLocation'),
                      center: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      radius: 50, // 50 meters radius
                      fillColor: Colors.blue.withOpacity(0.2),
                      strokeColor: Colors.blue,
                      strokeWidth: 2,
                    ),
                  }
                : {},
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeLocation,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class ParkingSpot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final int totalSpots;
  final int availableSpots;
  final double pricePerHour;

  ParkingSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.totalSpots,
    required this.availableSpots,
    required this.pricePerHour,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json) {
    return ParkingSpot(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      totalSpots: json['total_spots'],
      availableSpots: json['available_spots'],
      pricePerHour: json['price_per_hour'],
    );
  }
}

class ParkingDetailsSheet extends StatelessWidget {
  final ParkingSpot spot;
  final Position? userLocation;
  final VoidCallback onBookingPressed;

  const ParkingDetailsSheet({
    Key? key,
    required this.spot,
    this.userLocation,
    required this.onBookingPressed,
  }) : super(key: key);

  String _calculateDistance() {
    if (userLocation == null) return 'N/A';
    
    final distanceInMeters = Geolocator.distanceBetween(
      userLocation!.latitude,
      userLocation!.longitude,
      spot.latitude,
      spot.longitude,
    );
    
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spot.name,
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
                  Text('${spot.availableSpots}/${spot.totalSpots}'),
                  const Text('Available'),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.location_on),
                  Text(_calculateDistance()),
                  const Text('Distance'),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.currency_rupee),
                  Text('${spot.pricePerHour}'),
                  const Text('Per Hour'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            spot.address,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Book Now',
            onPressed: onBookingPressed,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 