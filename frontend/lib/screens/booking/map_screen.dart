import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import '../../utils/map_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  ParkingSpot? _selectedSpot;
  bool _mapInitialized = false;

  // Default camera position (you can set this to your city's coordinates)
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(17.3850, 78.4867), // Hyderabad coordinates
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await MapUtils.initializeMap();
      setState(() => _mapInitialized = true);
      await _getCurrentLocation();
      await _loadParkingSpots();
    } catch (e) {
      print('Error initializing map: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      final GoogleMapController controller = await _mapController!;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadParkingSpots() async {
    try {
      final supabase = Supabase.instance.client;
      final spots = await supabase.from('parking_spots').select();
      
      if (mounted) {
        setState(() {
          _markers = spots.map<Marker>((spot) {
            return Marker(
              markerId: MarkerId(spot['id'].toString()),
              position: LatLng(
                double.parse(spot['latitude'].toString()),
                double.parse(spot['longitude'].toString()),
              ),
              infoWindow: InfoWindow(title: spot['name']),
              onTap: () => _showParkingDetails(ParkingSpot.fromJson(spot)),
            );
          }).toSet();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading parking spots: $e')),
        );
      }
    }
  }

  void _showParkingDetails(ParkingSpot spot) {
    setState(() => _selectedSpot = spot);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ParkingDetailsSheet(
        spot: spot,
        userLocation: _currentPosition,
        onBookingPressed: () => _navigateToBooking(spot),
      ),
    );
  }

  void _navigateToBooking(ParkingSpot spot) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.pushNamed(
      context,
      '/booking-details',
      arguments: spot,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Parking'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading || !_mapInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _defaultLocation,
                  onMapCreated: (GoogleMapController controller) {
                    if (mounted) {
                      setState(() {
                        _mapController = controller;
                        _isLoading = false;
                      });
                    }
                  },
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true,
                  zoomGesturesEnabled: true,
                  compassEnabled: true,
                ),
                if (_selectedSpot != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedSpot!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Available: ${_selectedSpot!.availableSpots}'),
                          Text('Price: ₹${_selectedSpot!.pricePerHour}/hour'),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Book Now',
                            onPressed: () => _navigateToBooking(_selectedSpot!),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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