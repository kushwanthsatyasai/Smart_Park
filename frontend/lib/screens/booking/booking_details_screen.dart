import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import 'map_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  final ParkingSpot spot;

  const BookingDetailsScreen({
    Key? key,
    required this.spot,
  }) : super(key: key);

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  int _durationHours = 1;
  bool _isLoading = false;

  double get _totalPrice => widget.spot.pricePerHour * _durationHours;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _processBooking() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // Create booking
      final booking = await supabase.from('bookings').insert({
        'user_id': supabase.auth.currentUser!.id,
        'parking_spot_id': widget.spot.id,
        'date': _selectedDate.toIso8601String(),
        'start_time': '${_startTime.hour}:${_startTime.minute}',
        'duration_hours': _durationHours,
        'total_amount': _totalPrice,
        'status': 'pending',
      }).select().single();

      // Navigate to payment screen
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/payment',
          arguments: {
            'booking': booking,
            'amount': _totalPrice,
          },
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.spot.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.spot.address),
                    const SizedBox(height: 8),
                    Text(
                      'Price: ₹${widget.spot.pricePerHour}/hour',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Date & Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_startTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Duration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_durationHours > 1) {
                      setState(() => _durationHours--);
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_durationHours hours',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _durationHours++);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${_totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isLoading ? 'Processing...' : 'Proceed to Payment',
                onPressed: _isLoading ? null : _processBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 