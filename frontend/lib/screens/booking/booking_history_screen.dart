import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_confirmation_screen.dart';
import 'package:intl/intl.dart';

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

      if (response != null) {
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(response);
      });
      } else {
        setState(() {
          _bookings = [];
        });
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

  String _getStatusText(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase() ?? '';
    final createdAt = booking['created_at'] != null 
        ? DateTime.parse(booking['created_at'])
        : null;
    final entryTime = booking['entry_time'] != null
        ? DateTime.parse(booking['entry_time'])
        : null;
    
    // Check if pending booking is expired (older than 10 minutes)
    if (status == 'pending' && createdAt != null) {
      final expirationTime = createdAt.add(const Duration(minutes: 10));
      if (DateTime.now().isAfter(expirationTime)) {
        return 'EXPIRED';
      }
    }
    
    // Check if active booking has entry time
    if (status == 'active' && entryTime == null) {
      return 'PENDING';
    }
    
    return status.toUpperCase();
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
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final parkingLot = booking['parking_lots'] ?? {};
    final slot = booking['parking_slots'] ?? {};
    final status = _getStatusText(booking);
    final isExpired = status == 'EXPIRED';
    final isVerified = booking['is_verified'] ?? false;
    final entryTime = booking['entry_time'];
    final exitTime = booking['exit_time'];
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        onTap: () {
          // Only navigate if booking is not expired and has valid data
          if (!isExpired && parkingLot.isNotEmpty && slot.isNotEmpty) {
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
          } else if (isExpired) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This booking has expired and cannot be used'),
                backgroundColor: Colors.red,
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
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
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
            Text('Booked: ${_formatDateTime(booking['booking_time'])}'),
            if (entryTime != null)
              Text('Entry: ${_formatDateTime(entryTime)}'),
            if (exitTime != null)
              Text('Exit: ${_formatDateTime(exitTime)}'),
            if (isExpired)
              const Text(
                'Booking expired due to no entry within 10 minutes',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (status == 'ACTIVE' && entryTime != null)
              Text(
                'Duration: ${_calculateDuration(entryTime, DateTime.now())}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
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
            if (!isExpired && !isVerified && booking['verification_code'] != null)
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

  String _calculateDuration(String entryTime, DateTime now) {
    try {
      final entry = DateTime.parse(entryTime);
      final duration = now.difference(entry);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '$hours hours $minutes minutes';
    } catch (e) {
      return 'Invalid duration';
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

  Future<List<Map<String, dynamic>>> _fetchBookingHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
  
      // Fetch bookings with proper join relationship
      final response = await Supabase.instance.client
          .from('parking_bookings')
          .select('''
            *,
            parking_lots(*),
            profiles!inner(*)
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
  
      return response;
    } catch (e) {
      print('Error fetching booking history: $e');
      rethrow;
    }
  }
}