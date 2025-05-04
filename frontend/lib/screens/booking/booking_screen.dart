import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/parking_space_grid.dart';
import '../../theme/app_theme.dart';
import 'booking_confirmation_screen.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../profile/vehicle_management_screen.dart';
import '../../widgets/vehicle_selector.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/booking_monitor_service.dart';

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
  final _bookingMonitor = BookingMonitorService();
  bool _isLoading = false;
  Map<String, dynamic>? _assignedSlot;
  TimeOfDay? _selectedTime;
  int _selectedDuration = 1;
  int _selectedFloor = 0;
  List<Map<String, dynamic>> _parkingSlots = [];
  DateTime? _bookingStartTime;

  @override
  void initState() {
    super.initState();
    _loadParkingSlots();
    _bookingMonitor.startMonitoring();
  }

  @override
  void dispose() {
    _bookingMonitor.stopMonitoring();
    super.dispose();
  }

  Future<void> _loadParkingSlots() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('parking_slots')
          .select()
          .eq('parking_lot_id', widget.parkingData['id']);
      setState(() {
        _parkingSlots = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading slots: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectSlot(Map<String, dynamic> slot) {
    setState(() {
      _assignedSlot = slot;
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: AppTheme.darkTheme,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        final now = TimeOfDay.now();
        int selectedMinutes = picked.hour * 60 + picked.minute;
        int currentMinutes = now.hour * 60 + now.minute;
        int durationMinutes = selectedMinutes - currentMinutes;
        if (durationMinutes <= 0) {
          durationMinutes += 24 * 60;
        }
        _selectedDuration = (durationMinutes / 60).ceil();
      });
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
      _bookingStartTime = now;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the parking lot within 10 minutes, or your booking will expire.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );

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

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
      appBar: AppBar(
          title: const Text('Select Space'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (int i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Floor ${i + 1}'),
                                selected: _selectedFloor == i,
                                onSelected: (selected) {
                                  setState(() => _selectedFloor = i);
                                },
                                selectedColor: AppTheme.primaryBlue,
                                backgroundColor: AppTheme.cardBackground,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Parking Space',
                            style: Theme.of(context).textTheme.titleLarge,
                            ),
                          const SizedBox(height: 16),
                          ParkingSpaceGrid(
                            slots: _parkingSlots,
                            selectedSlotId: _assignedSlot?['id'],
                            onSlotSelected: _selectSlot,
                          ),
                          if (_assignedSlot != null) ...[
                            const SizedBox(height: 24),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                            Text(
                                      'Booking Details',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Rate per hour',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                            Text(
                                          '₹${_assignedSlot!['rate_per_hour']}',
                                          style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                      ],
                            ),
                                    const SizedBox(height: 8),
                            InkWell(
                              onTap: _selectTime,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                          color: AppTheme.darkSurface,
                                          borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                              'Duration',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    Row(
                                      children: [
                                                Icon(
                                                  Icons.access_time,
                                                  color: AppTheme.primaryBlue,
                                                  size: 20,
                                                ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedTime != null
                                              ? 'Until ${_selectedTime!.format(context)}'
                                              : 'Select Time',
                                          style: TextStyle(
                                                    color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                                    if (_selectedTime != null) ...[
                            const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                              Text(
                                            'Total Amount',
                                            style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                            '₹${(_assignedSlot!['rate_per_hour'] * _selectedDuration).toStringAsFixed(2)}',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              color: AppTheme.primaryBlue,
                                    ),
                              ),
                            ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: _assignedSlot != null
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                    ),
                child: SafeArea(
                  child: CustomButton(
                      text: 'Confirm Booking',
                      onPressed: (_isLoading || _selectedTime == null) ? null : _bookSlot,
                      isLoading: _isLoading,
                    ),
              ),
              )
            : null,
            ),
    );
  }
}

