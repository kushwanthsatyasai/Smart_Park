import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_button.dart';
import '../booking/booking_confirmation_screen.dart';

class ParkingBookingScreen extends StatefulWidget {
  final String parkingLotId;
  final String parkingLotName;
  final String? slotId;
  final String? slotNumber;

  const ParkingBookingScreen({
    Key? key, 
    required this.parkingLotId, 
    required this.parkingLotName,
    this.slotId,
    this.slotNumber,
  }) : super(key: key);

  @override
  State<ParkingBookingScreen> createState() => _ParkingBookingScreenState();
}

class _ParkingBookingScreenState extends State<ParkingBookingScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isBooking = false;
  Map<String, dynamic>? _parkingLot;
  List<Map<String, dynamic>> _availableSlots = [];
  Map<String, dynamic>? _selectedSlot;
  List<Map<String, dynamic>> _userVehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  String? _verificationCode;

  final TextEditingController _durationController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load parking lot details
      final parkingLotResponse = await _supabase
          .from('parking_lots')
          .select('*, parking_slots(*)')
          .eq('id', widget.parkingLotId)
          .single();

      // Load user vehicles
      final vehiclesResponse = await _supabase
          .from('vehicles')
          .select('*')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      setState(() {
        _parkingLot = parkingLotResponse;
        _userVehicles = List<Map<String, dynamic>>.from(vehiclesResponse);
        
        // Extract available slots
        final allSlots = List<Map<String, dynamic>>.from(parkingLotResponse['parking_slots']);
        _availableSlots = allSlots.where((slot) => !slot['is_occupied']).toList();
        
        // If we're coming from a parking slot QR, pre-select that slot
        if (widget.slotId != null) {
          _selectedSlot = _availableSlots.firstWhere(
            (slot) => slot['id'] == widget.slotId,
            orElse: () => _availableSlots.isNotEmpty ? _availableSlots.first : null,
          );
        } else if (_availableSlots.isNotEmpty) {
          _selectedSlot = _availableSlots.first;
        }

        // Select first vehicle by default
        if (_userVehicles.isNotEmpty) {
          _selectedVehicle = _userVehicles.first;
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading parking data: $e');
    }
  }

  Future<void> _bookSlot() async {
    if (_selectedSlot == null || _selectedVehicle == null) {
      _showError('Please select a slot and vehicle');
      return;
    }

    // Parse duration
    int duration;
    try {
      duration = int.parse(_durationController.text);
      if (duration <= 0) throw FormatException('Duration must be positive');
    } catch (e) {
      _showError('Please enter a valid duration');
      return;
    }

    setState(() => _isBooking = true);

    try {
      // Generate a verification code
      _verificationCode = _generateVerificationCode();

      // Create booking in the database
      final bookingResponse = await _supabase
          .from('parking_bookings')
          .insert({
            'user_id': _supabase.auth.currentUser!.id,
            'parking_lot_id': widget.parkingLotId,
            'vehicle_id': _selectedVehicle!['id'],
            'assigned_slot_id': _selectedSlot!['id'],
            'status': 'active',
            'duration_hours': duration,
            'verification_code': _verificationCode,
            'booking_time': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      // Navigate to confirmation screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmationScreen(
              bookingDetails: bookingResponse,
              parkingLot: _parkingLot!,
              assignedSlot: _selectedSlot!,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isBooking = false);
      _showError('Booking failed: $e');
    }
  }

  String _generateVerificationCode() {
    // Generate a 6-digit verification code
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = DateTime.now().microsecondsSinceEpoch % 1000000;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[random % chars.length];
    }
    return code;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Parking: ${widget.parkingLotName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBookingForm(),
    );
  }

  Widget _buildBookingForm() {
    if (_availableSlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'No available slots at ${widget.parkingLotName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again later or choose another parking lot',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );
    }

    if (_userVehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'No vehicles found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add a vehicle to your profile before booking a parking slot',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/vehicles'),
              child: const Text('Add Vehicle'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parking details card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.parkingLotName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Location: ${_parkingLot?['location'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available Slots: ${_availableSlots.length} / ${_parkingLot?['total_slots'] ?? 0}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rate: ₹${_selectedSlot?['rate_per_hour'] ?? _parkingLot?['base_rate'] ?? 0}/hour',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Slot selection
          const Text(
            'Select Parking Slot',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Map<String, dynamic>>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedSlot,
            items: _availableSlots.map((slot) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: slot,
                child: Text('Slot ${slot['slot_number']}${slot['slot_type'] != null ? ' - ${slot['slot_type']}' : ''}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSlot = value;
              });
            },
          ),
          const SizedBox(height: 24),

          // Vehicle selection
          const Text(
            'Select Vehicle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Map<String, dynamic>>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedVehicle,
            items: _userVehicles.map((vehicle) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: vehicle,
                child: Text('${vehicle['license_plate']} - ${vehicle['brand']} ${vehicle['model']}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedVehicle = value;
              });
            },
          ),
          const SizedBox(height: 24),

          // Duration selection
          const Text(
            'Duration (hours)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _durationController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: 'Enter parking duration in hours',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          // Payment summary
          Card(
            elevation: 2,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentRow(
                    'Rate',
                    '₹${_selectedSlot?['rate_per_hour'] ?? _parkingLot?['base_rate'] ?? 0}/hour',
                  ),
                  _buildPaymentRow(
                    'Duration',
                    '${_durationController.text} hours',
                  ),
                  const Divider(),
                  _buildPaymentRow(
                    'Estimated Total',
                    '₹${_calculateEstimatedTotal()}',
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Note: Final charges will be calculated based on actual parking duration',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Book button
          CustomButton(
            text: 'Book Now',
            onPressed: _bookSlot,
            isLoading: _isBooking,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isBold = false}) {
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text(value, style: textStyle),
        ],
      ),
    );
  }

  String _calculateEstimatedTotal() {
    final ratePerHour = _selectedSlot?['rate_per_hour'] ?? _parkingLot?['base_rate'] ?? 0;
    final duration = int.tryParse(_durationController.text) ?? 1;
    final total = ratePerHour * duration;
    return total.toStringAsFixed(2);
  }
} 