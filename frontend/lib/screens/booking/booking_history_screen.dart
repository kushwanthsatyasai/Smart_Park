import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_confirmation_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() => _isLoading = true);
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final response = await _supabase
          .from('parking_bookings')
          .select('''
            *,
            parking_lots:parking_id(*),
            parking_slots:slot_id(*)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('Raw response: $response'); // Debug print

      setState(() {
        _bookings = List<Map<String, dynamic>>.from(response);
      });

      // Detailed debug printing
      print('Loaded ${_bookings.length} bookings');
      for (var booking in _bookings) {
        print('Booking ID: ${booking['id']}');
        print('Status: ${booking['status']}');
        print('Parking Lot Data: ${booking['parking_lots']}');
        print('Slot Data: ${booking['parking_slots']}');
        print('---');
      }

    } catch (e) {
      print('Error loading bookings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(
                  child: Text(
                    'No bookings found',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final booking = _bookings[index];
                      return _buildBookingCard(booking);
                    },
                  ),
                ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    // Add null checks and provide default values
    final parkingLot = booking['parking_lots'] ?? {};
    final slot = booking['parking_slots'] ?? {};
    final isVerified = booking['is_verified'] ?? false;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        onTap: () {
          // Only navigate if we have valid parking lot and slot data
          if (parkingLot.isNotEmpty && slot.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingConfirmationScreen(
                  bookingDetails: booking,
                  parkingLot: parkingLot,
                  assignedSlot: slot,
                ),
              ),
            );
          }
        },
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                parkingLot['name']?.toString() ?? 'Unknown Location',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isVerified ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isVerified ? 'VERIFIED' : 'PENDING',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Slot: ${slot['slot_number']?.toString() ?? 'Unknown'}'),
            if (booking['booking_time'] != null)
              Text('Booked: ${DateTime.parse(booking['booking_time']).toLocal().toString().split('.')[0]}'),
            if (booking['entry_time'] != null)
              Text('Entry: ${DateTime.parse(booking['entry_time']).toLocal().toString().split('.')[0]}'),
            if (booking['exit_time'] != null)
              Text('Exit: ${DateTime.parse(booking['exit_time']).toLocal().toString().split('.')[0]}'),
            Text(
              'Status: ${(booking['status'] ?? 'Unknown').toString().toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(booking['status']?.toString() ?? ''),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${booking['total_fee']?.toString() ?? '0'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (!isVerified && booking['verification_code'] != null)
              Text(
                'Code: ${booking['verification_code']}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 