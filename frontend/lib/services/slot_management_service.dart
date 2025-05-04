import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class SlotManagementService {
  final _supabase = Supabase.instance.client;
  Timer? _bookingExpirationTimer;
  Timer? _slotAvailabilityTimer;
  final int _bookingExpirationMinutes = 5; // Configurable expiration time

  SlotManagementService() {
    startServices();
  }

  void startServices() {
    // Check for expired bookings every minute
    _bookingExpirationTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => checkAndExpireBookings());
    
    // Check for slots that need to be freed up every 2 minutes
    _slotAvailabilityTimer = Timer.periodic(
        const Duration(minutes: 2), (_) => updateSlotAvailability());
  }

  void stopServices() {
    _bookingExpirationTimer?.cancel();
    _slotAvailabilityTimer?.cancel();
  }

  Future<void> checkAndExpireBookings() async {
    try {
      // Get current time
      final now = DateTime.now().toUtc();
      
      // Calculate the cutoff time (5 minutes ago)
      final cutoffTime = now.subtract(Duration(minutes: _bookingExpirationMinutes));
      final cutoffTimeStr = cutoffTime.toIso8601String();
      
      // Find pending bookings that haven't been verified within the time limit
      final expiredBookings = await _supabase
          .from('parking_bookings')
          .select('id, assigned_slot_id, slot_id, parking_id')
          .eq('status', 'pending')
          .eq('is_verified', false)
          .lte('created_at', cutoffTimeStr);
      
      // Process each expired booking
      for (var booking in expiredBookings) {
        // Update booking status to expired
        await _supabase
            .from('parking_bookings')
            .update({
              'status': 'expired',
              'updated_at': now.toIso8601String()
            })
            .eq('id', booking['id']);
        
        // Free up the assigned slot
        final slotId = booking['slot_id'] ?? booking['assigned_slot_id'];
        if (slotId != null) {
          await _supabase
              .from('parking_slots')
              .update({'is_available': true})
              .eq('id', slotId);
        }
      }
      
      print('Checked for expired bookings: ${expiredBookings.length} bookings expired');
    } catch (e) {
      print('Error checking for expired bookings: $e');
    }
  }

  Future<void> updateSlotAvailability() async {
    try {
      // Get completed bookings where the slot hasn't been freed up
      final completedBookings = await _supabase
          .from('parking_bookings')
          .select('id, assigned_slot_id, slot_id, parking_id')
          .eq('status', 'completed')
          .not('exit_time', 'is', null);
      
      // Free up slots for completed bookings
      for (var booking in completedBookings) {
        final slotId = booking['slot_id'] ?? booking['assigned_slot_id'];
        if (slotId != null) {
          await _supabase
              .from('parking_slots')
              .update({'is_available': true})
              .eq('id', slotId);
        }
      }
      
      print('Updated availability for ${completedBookings.length} slots');
    } catch (e) {
      print('Error updating slot availability: $e');
    }
  }

  // Method to manually free up a slot
  Future<void> freeUpSlot(String slotId) async {
    try {
      await _supabase
          .from('parking_slots')
          .update({'is_available': true})
          .eq('id', slotId);
    } catch (e) {
      print('Error freeing up slot: $e');
      rethrow;
    }
  }

  // Method to manually expire a booking
  Future<void> expireBooking(String bookingId) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Get the booking details
      final bookingResponse = await _supabase
          .from('parking_bookings')
          .select('slot_id, assigned_slot_id')
          .eq('id', bookingId)
          .single();
      
      // Update booking status
      await _supabase
          .from('parking_bookings')
          .update({
            'status': 'expired',
            'updated_at': now.toIso8601String()
          })
          .eq('id', bookingId);
      
      // Free up the slot
      final slotId = bookingResponse['slot_id'] ?? bookingResponse['assigned_slot_id'];
      if (slotId != null) {
        await _supabase
            .from('parking_slots')
            .update({'is_available': true})
            .eq('id', slotId);
      }
    } catch (e) {
      print('Error expiring booking: $e');
      rethrow;
    }
  }
} 