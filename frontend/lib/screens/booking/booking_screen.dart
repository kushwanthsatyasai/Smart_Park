import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import 'booking_confirmation_screen.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isLoading = false;
  Map<String, dynamic>? _assignedSlot;
  TimeOfDay? _selectedTime;
  int _selectedDuration = 1;

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

  Future<void> _getAvailableSlot(String parkingLotId, String vehicleType) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Get all available slots for the vehicle type with all necessary fields
      final response = await supabase
          .from('parking_slots')
          .select('''
            id,
            slot_number,
            vehicle_type,
            is_available,
            rate_per_hour,
            parking_lot_id
          ''')
          .eq('parking_lot_id', parkingLotId)
          .eq('vehicle_type', vehicleType)
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

      // Debug print to check slot data
      print('Available slots: $slots');

      // Randomly select one available slot
      final random = Random();
      final selectedSlot = slots[random.nextInt(slots.length)];
      
      // Debug print selected slot
      print('Selected slot: $selectedSlot');

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
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final verificationCode = (100000 + Random().nextInt(900000)).toString();
      
      final now = DateTime.now();
      final totalFee = _assignedSlot!['rate_per_hour'] * _selectedDuration.toDouble();

      // Debug print to check values
      print('Inserting booking with:');
      print('parking_id: ${_assignedSlot!['parking_lot_id']}');
      print('slot_id: ${_assignedSlot!['id']}');

      // Create booking with corrected column names
      final bookingResponse = await supabase
          .from('parking_bookings')
          .insert({
            'parking_id': _assignedSlot!['parking_lot_id'],
            'slot_id': _assignedSlot!['id'],
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
      await supabase
          .from('parking_slots')
          .update({'is_available': false})
          .eq('id', _assignedSlot!['id']);

      // Get user details
      final userResponse = await supabase
          .from('profiles')
          .select()
          .eq('id', supabase.auth.currentUser!.id)
          .single();

      // Prepare booking details for QR screen
      final bookingDetails = {
        ...bookingResponse,
        'user_name': userResponse['name'],
        'phone_number': userResponse['phone_number'],
        'vehicle_number': _assignedSlot!['slot_number'],
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            if (_assignedSlot == null)
              CustomButton(
                text: 'Assign Slot',
                onPressed: _isLoading ? null : () => _getAvailableSlot(widget.parkingData['id'], 'car'),
                isLoading: _isLoading,
              )
            else ...[
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
