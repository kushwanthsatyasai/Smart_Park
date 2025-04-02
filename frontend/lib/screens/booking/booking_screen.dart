import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import 'booking_confirmation_screen.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../profile/vehicle_management_screen.dart';
import '../../widgets/vehicle_selector.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';

// Extension to add capitalize method to String
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}

const Color primaryBlue = Color(0xFF1A73E8);
const Color secondaryBlue = Color(0xFF4285F4);
const Color lightBlue = Color(0xFFE8F0FE);

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
  Map<String, dynamic>? _assignedSlot;
  TimeOfDay? _selectedTime;
  int _selectedDuration = 1;

  @override
  void initState() {
    super.initState();
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
    final selectedVehicle = Provider.of<VehicleProvider>(context, listen: false).selectedVehicle;
    
    if (selectedVehicle == null) {
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
          .eq('vehicle_type', selectedVehicle.type.toLowerCase())
          .eq('is_available', true);

      final slots = List<Map<String, dynamic>>.from(response);
      
      if (slots.isEmpty) {
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
    final selectedVehicle = Provider.of<VehicleProvider>(context, listen: false).selectedVehicle;
    
    if (_assignedSlot == null || selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign a slot and select a vehicle first'),
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
            'vehicle_id': selectedVehicle.id,
          })
          .select()
          .single();

      await _supabase
          .from('parking_slots')
          .update({'is_available': false})
          .eq('id', _assignedSlot!['id']);

      final userResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final bookingDetails = {
        ...bookingResponse,
        'user_name': userResponse['name'],
        'phone_number': userResponse['phone_number'],
        'vehicle_number': selectedVehicle.number,
        'vehicle_type': selectedVehicle.type,
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
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final selectedVehicle = vehicleProvider.selectedVehicle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          VehicleSelector(
            onVehicleSelected: (vehicle) {
              setState(() {
                _assignedSlot = null;
              });
              vehicleProvider.setSelectedVehicle(vehicle);
            },
            initialVehicle: selectedVehicle,
            isCompact: true,
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
                  // Parking Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parking Lot: ${widget.parkingData['name']}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: primaryBlue,
                            ),
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
                  if (selectedVehicle != null && _assignedSlot == null)
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

