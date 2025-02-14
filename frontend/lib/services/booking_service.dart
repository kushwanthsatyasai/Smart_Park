import 'package:supabase_flutter/supabase_flutter.dart';

class BookingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createBooking({
    required String slotId,
    required String vehicleId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    
    final response = await _supabase.from('bookings').insert({
      'user_id': userId,
      'slot_id': slotId,
      'vehicle_id': vehicleId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': 'active',
    }).select().single();

    return response;
  }

  Future<List<Map<String, dynamic>>> getAvailableSlots() async {
    final response = await _supabase
        .from('parking_slots')
        .select()
        .eq('is_available', true);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getUserBookings() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('bookings')
        .select('*, parking_slots(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
} 