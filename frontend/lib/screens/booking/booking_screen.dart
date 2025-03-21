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

  Future<void> _getAvailableSlot(String parkingLotId, String vehicleType) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Get all available slots for the vehicle type
      final response = await supabase
          .from('parking_slots')
          .select()
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
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final verificationCode = (100000 + Random().nextInt(900000)).toString();
      
      final now = DateTime.now();
      final totalFee = _assignedSlot!['rate_per_hour'] * 1.0;

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
            'duration': 1,
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

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmationScreen(
              bookingDetails: bookingResponse,
              parkingLot: widget.parkingData,
              assignedSlot: _assignedSlot!,
            ),
          ),
        );
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
                    Text(
                      'Rate: ₹${widget.parkingData['rate_per_hour']}/hour',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_assignedSlot != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Assigned Slot: ${_assignedSlot!['slot_number']}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.green,
                            ),
                      ),
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
                onPressed: _isLoading ? null : _bookSlot,
                isLoading: _isLoading,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
