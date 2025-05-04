import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingMonitorService {
  final _supabase = Supabase.instance.client;
  Timer? _monitorTimer;
  static const int EXPIRATION_MINUTES = 10;

  void startMonitoring() {
    // Check every minute for expired bookings
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkExpiredBookings();
    });
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<void> _checkExpiredBookings() async {
    try {
      // Get pending bookings that are older than 10 minutes
      final DateTime expirationThreshold = DateTime.now().subtract(
        const Duration(minutes: EXPIRATION_MINUTES),
      );

      final response = await _supabase
          .from('parking_bookings')
          .select('id, slot_id, created_at')
          .eq('status', 'pending')
          .lt('created_at', expirationThreshold.toIso8601String());

      final expiredBookings = List<Map<String, dynamic>>.from(response);

      for (final booking in expiredBookings) {
        await _handleExpiredBooking(booking);
      }
    } catch (e) {
      print('Error checking expired bookings: $e');
    }
  }

  Future<void> _handleExpiredBooking(Map<String, dynamic> booking) async {
    try {
      // Start a transaction
      await _supabase.rpc('handle_expired_booking', params: {
        'booking_id': booking['id'],
        'slot_id': booking['slot_id'],
      });
    } catch (e) {
      print('Error handling expired booking: $e');
    }
  }

  // Call this when a booking is completed
  Future<void> handleCompletedBooking(String bookingId, String slotId) async {
    try {
      await _supabase.rpc('handle_completed_booking', params: {
        'booking_id': bookingId,
        'slot_id': slotId,
      });
    } catch (e) {
      print('Error handling completed booking: $e');
    }
  }
} 