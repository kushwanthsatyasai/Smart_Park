import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import 'booking_confirmation_screen.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../profile/vehicle_management_screen.dart';

// Extension to add capitalize method to String
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> parkingData;

  const BookingScreen({
    super.key,
    required this.parkingData,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _userVehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  Map<String, dynamic>? _assignedSlot;
  TimeOfDay? _selectedTime;
  int _selectedDuration = 1;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);
      
      final userId = _supabase.auth.currentUser!.id;
      
      // Get profile data first
      final profileResponse = await _supabase
          .from('profiles')
          .select('vehicle_type, vehicle_number')
          .eq('id', userId)
          .single();
      
      // Load existing vehicles
      final vehiclesResponse = await _supabase
          .from('user_vehicles')
          .select()
          .eq('user_id', userId);
      
      List<Map<String, dynamic>> vehicles = List<Map<String, dynamic>>.from(vehiclesResponse);
      
      // If profile has vehicle data and it's not in user_vehicles, add it
      if (profileResponse != null && 
          profileResponse['vehicle_type'] != null && 
          profileResponse['vehicle_number'] != null &&
          profileResponse['vehicle_number'].toString().trim().isNotEmpty) {
        
        // Ensure vehicle type is one of the allowed values
        String vehicleType = profileResponse['vehicle_type'].toString().toLowerCase();
        if (!['car', 'bike', 'bus', 'cycle'].contains(vehicleType)) {
          vehicleType = 'car'; // Default to car if invalid type
        }
        
        bool vehicleExists = vehicles.any((v) => 
          v['vehicle_number'].toString().toLowerCase() == 
          profileResponse['vehicle_number'].toString().toLowerCase());
        
        if (!vehicleExists) {
          try {
            final newVehicle = await _supabase
                .from('user_vehicles')
                .insert({
                  'user_id': userId,
                  'vehicle_type': vehicleType,
                  'vehicle_number': profileResponse['vehicle_number'].toString().toUpperCase(),
                  'nickname': 'My ${vehicleType.capitalize()}',
                  'created_at': DateTime.now().toIso8601String(),
                })
                .select()
                .single();
            
            vehicles.insert(0, newVehicle);
          } catch (e) {
            print('Error adding profile vehicle: $e');
          }
        }
      }
      
      setState(() {
        _userVehicles = vehicles;
        if (vehicles.isNotEmpty) {
          _selectedVehicle = vehicles.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading vehicles: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddVehicleDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VehicleManagementScreen(),
      ),
    );
    
    if (result == true) {
      _loadInitialData();
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: Colors.blue,
              dayPeriodTextColor: Colors.blue,
              dialHandColor: Colors.blue,
              dialBackgroundColor: Colors.grey.shade200,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        // Calculate duration based on current time and selected time
        final now = TimeOfDay.now();
        int selectedMinutes = picked.hour * 60 + picked.minute;
        int currentMinutes = now.hour * 60 + now.minute;
        int durationMinutes = selectedMinutes - currentMinutes;
        if (durationMinutes <= 0) {
          // If selected time is earlier than current time, assume it's for next day
          durationMinutes += 24 * 60;
        }
        _selectedDuration = (durationMinutes / 60).ceil();
      });
    }
  }

  Future<void> _getAvailableSlot() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      print('Searching for slots with vehicle type: ${_selectedVehicle!['vehicle_type']}');
      
      // Get all available slots for the vehicle type with all necessary fields
      final response = await _supabase
          .from('parking_slots')
          .select('''
            id,
            slot_number,
            vehicle_type,
            is_available,
            rate_per_hour,
            parking_lot_id
          ''')
          .eq('parking_lot_id', widget.parkingData['id'])
          .eq('vehicle_type', _selectedVehicle!['vehicle_type'].toString().toLowerCase())
          .eq('is_available', true);

      final slots = List<Map<String, dynamic>>.from(response);
      
      print('Found ${slots.length} available slots');
      if (slots.isEmpty) {
        print('No slots found. Debugging info:');
        print('Parking lot ID: ${widget.parkingData['id']}');
        print('Vehicle type: ${_selectedVehicle!['vehicle_type']}');
        
        // Let's check all slots to debug
        final allSlots = await _supabase
            .from('parking_slots')
            .select()
            .eq('parking_lot_id', widget.parkingData['id']);
        print('Total slots in parking lot: ${allSlots.length}');
        print('Available slots: ${allSlots.where((slot) => slot['is_available'] == true).length}');
        print('Slots for vehicle type: ${allSlots.where((slot) => slot['vehicle_type'].toString().toLowerCase() == _selectedVehicle!['vehicle_type'].toString().toLowerCase()).length}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No available slots found for this vehicle type'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Randomly select one available slot
      final random = Random();
      final selectedSlot = slots[random.nextInt(slots.length)];

      setState(() {
        _assignedSlot = selectedSlot;
      });
    } catch (e) {
      print('Error getting available slot: $e');
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

  Future<void> _bookSlot() async {
    if (_assignedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign a slot first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final verificationCode = (100000 + Random().nextInt(900000)).toString();
      
      final now = DateTime.now();
      final totalFee = _assignedSlot!['rate_per_hour'] * _selectedDuration.toDouble();

      // Create booking
      final bookingResponse = await _supabase
          .from('parking_bookings')
          .insert({
            'parking_lot_id': widget.parkingData['id'],
            'parking_id': widget.parkingData['id'],
            'slot_id': _assignedSlot!['id'],
            'assigned_slot_id': _assignedSlot!['id'],
            'user_id': userId,
            'booking_time': now.toIso8601String(),
            'entry_time': null,
            'exit_time': null,
            'amount': _assignedSlot!['rate_per_hour'],
            'duration': _selectedDuration,
            'total_fee': totalFee,
            'status': 'pending',
            'verification_code': verificationCode,
            'is_verified': false,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select()
          .single();

      // Update slot availability
      await _supabase
          .from('parking_slots')
          .update({'is_available': false})
          .eq('id', _assignedSlot!['id']);

      // Get user details
      final userResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      // Prepare booking details for QR screen
      final bookingDetails = {
        ...bookingResponse,
        'user_name': userResponse['name'],
        'phone_number': userResponse['phone_number'],
        'vehicle_number': _selectedVehicle!['vehicle_number'],
      };

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'booking_details': bookingDetails,
          'parking_lot': widget.parkingData,
          'assigned_slot': _assignedSlot,
        });
      }
    } catch (e) {
      print('Error booking slot: $e');
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

  Future<void> _openDirections() async {
    final lat = double.parse(widget.parkingData['latitude'].toString());
    final lng = double.parse(widget.parkingData['longitude'].toString());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: _showAddVehicleDialog,
            tooltip: 'Manage Vehicles',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vehicle Selection
                  if (_userVehicles.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Vehicle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _userVehicles.length,
                                itemBuilder: (context, index) {
                                  final vehicle = _userVehicles[index];
                                  final isSelected = _selectedVehicle == vehicle;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedVehicle = vehicle;
                                          _assignedSlot = null;
                                        });
                                      },
                                      child: Container(
                                        width: 120,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.1)
                                              : Colors.grey[100],
                                          border: Border.all(
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[300]!,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              vehicle['vehicle_type'] == 'car'
                                                  ? Icons.directions_car
                                                  : vehicle['vehicle_type'] ==
                                                          'bike'
                                                      ? Icons.motorcycle
                                                      : vehicle['vehicle_type'] ==
                                                              'bus'
                                                          ? Icons.directions_bus
                                                          : Icons.pedal_bike,
                                              color: isSelected
                                                  ? Theme.of(context).primaryColor
                                                  : Colors.grey[600],
                                              size: 32,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              vehicle['nickname'] ?? 'My Vehicle',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'No vehicles found',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddVehicleDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Vehicle'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Parking Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parking Lot: ${widget.parkingData['name']}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_assignedSlot != null) ...[
                            Text(
                              'Rate: ₹${_assignedSlot!['rate_per_hour']}/hour',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Assigned Slot: ${_assignedSlot!['slot_number']}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.green,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _selectTime,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Select Parking Duration',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedTime != null
                                              ? 'Until ${_selectedTime!.format(context)}'
                                              : 'Select Time',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_selectedTime != null) ...[
                              Text(
                                'Duration: $_selectedDuration hour${_selectedDuration > 1 ? 's' : ''}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total Fee: ₹${(_assignedSlot!['rate_per_hour'] * _selectedDuration).toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_selectedVehicle != null && _assignedSlot == null)
                    CustomButton(
                      text: 'Assign Slot',
                      onPressed: _isLoading ? null : _getAvailableSlot,
                      isLoading: _isLoading,
                    )
                  else if (_assignedSlot != null) ...[
                    CustomButton(
                      text: 'Get Directions',
                      onPressed: _isLoading ? null : _openDirections,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Confirm Booking',
                      onPressed: (_isLoading || _selectedTime == null) ? null : _bookSlot,
                      isLoading: _isLoading,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

