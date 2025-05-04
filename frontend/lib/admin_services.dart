import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminServices {
  final SupabaseClient _supabase;
  
  // Singleton pattern
  static final AdminServices _instance = AdminServices._internal();
  factory AdminServices() => _instance;
  
  AdminServices._internal() : _supabase = Supabase.instance.client;
  
  // Timeout durations
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration shortTimeout = Duration(seconds: 5);
  
  // Retry settings
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // Handle connection errors with retries
  Future<T> _withRetry<T>(Future<T> Function() operation, {int retries = maxRetries}) async {
    try {
      return await operation().timeout(defaultTimeout);
    } catch (e) {
      if (retries > 0) {
        await Future.delayed(retryDelay);
        return _withRetry(operation, retries: retries - 1);
      }
      rethrow;
    }
  }
  
  // Check if current user is admin
  Future<bool> checkAdminAccess() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      
      final response = await _withRetry(() => 
        _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single()
      );
      
      final role = response['role'] as String? ?? 'customer';
      return role.toLowerCase() == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
  
  // Load dashboard stats with error handling
  Future<Map<String, dynamic>> loadDashboardStats() async {
    try {
      final stats = <String, dynamic>{};
      
      // Run these requests in parallel
      final results = await Future.wait([
        _withRetry(() => _supabase.from('parking_lots').select('id')),
        _withRetry(() => _supabase.from('parking_bookings').select('id')),
        _withRetry(() => _supabase.from('profiles').select('id').neq('role', 'admin')),
      ]);
      
      stats['totalLots'] = results[0].length;
      stats['totalBookings'] = results[1].length;
      stats['totalUsers'] = results[2].length;
      
      return stats;
    } catch (e) {
      print('Error loading stats: $e');
      // Return empty stats instead of throwing
      return {
        'totalLots': 0,
        'totalBookings': 0,
        'totalUsers': 0,
        'error': e.toString(),
      };
    }
  }
  
  // Check QR server connectivity
  Future<Map<String, dynamic>> checkServerConnection(String serverUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/health'),
      ).timeout(shortTimeout);
      
      return {
        'isConnected': response.statusCode == 200,
        'status': response.statusCode == 200 ? 'Connected' : 'Error: Status ${response.statusCode}',
        'error': null,
      };
    } catch (e) {
      return {
        'isConnected': false,
        'status': 'Error: ${e.toString().split('\n')[0]}',
        'error': e.toString(),
      };
    }
  }
  
  // Get parking lots for current user
  Future<List<Map<String, dynamic>>> getParkingLots() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];
      
      final response = await _withRetry(() => 
        _supabase
          .from('parking_lots')
          .select('id, name, location, total_slots')
          .eq('owner_id', user.id)
      );
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching parking lots: $e');
      return [];
    }
  }
  
  // Get active bookings
  Future<List<Map<String, dynamic>>> getActiveBookings() async {
    try {
      final response = await _withRetry(() => 
        _supabase
          .from('parking_bookings')
          .select('''
            id, 
            booking_time, 
            status, 
            verification_code,
            entry_time,
            exit_time,
            assigned_slot_id,
            parking_lots(name),
            vehicles!inner(license_plate, brand, model, color),
            profiles!inner(full_name, phone_number)
          ''')
          .eq('status', 'active')
          .order('booking_time', ascending: false)
      );
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching active bookings: $e');
      return [];
    }
  }
  
  // Get parking history
  Future<List<Map<String, dynamic>>> getParkingHistory() async {
    try {
      final response = await _withRetry(() => 
        _supabase
          .from('parking_bookings')
          .select('''
            id, 
            booking_time, 
            status, 
            entry_time,
            exit_time,
            assigned_slot_id,
            total_fee,
            parking_lots(name),
            vehicles!inner(license_plate, brand, model),
            profiles!inner(full_name)
          ''')
          .or('status.eq.completed,status.eq.expired')
          .order('booking_time', ascending: false)
          .limit(20)
      );
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching parking history: $e');
      return [];
    }
  }
  
  // Verify booking and open gate by calling server
  Future<Map<String, dynamic>> verifyBookingAndOpenGate(
    String bookingId, 
    Map<String, dynamic> bookingData,
    String serverUrl
  ) async {
    try {
      // First update the database
      await _withRetry(() => 
        _supabase
          .from('parking_bookings')
          .update({
            'entry_time': DateTime.now().toUtc().toIso8601String(),
            'status': 'active',
            'is_verified': true
          })
          .eq('id', bookingId)
      );
      
      // Then try to open the gate via server
      final qrData = {
        "booking_id": bookingId,
        "verification_code": bookingData['verification_code'],
        "assigned_slot_id": bookingData['assigned_slot_id'],
        "parking_lot_id": bookingData['parking_lot_id'] ?? bookingData['parking_lots']['id'],
      };
      
      try {
        final response = await http.post(
          Uri.parse('$serverUrl/verify_booking'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(qrData),
        ).timeout(shortTimeout);
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          return {
            'success': result['open_gate'] == true,
            'message': result['message'] ?? 'Gate opened successfully',
            'error': null,
          };
        } else {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
            'error': response.body,
          };
        }
      } catch (e) {
        // If server communication fails, at least the database was updated
        return {
          'success': true,
          'message': 'Database updated, but gate server unreachable',
          'error': e.toString(),
        };
      }
    } catch (e) {
      print('Error verifying booking: $e');
      return {
        'success': false,
        'message': 'Verification failed',
        'error': e.toString(),
      };
    }
  }
  
  // Mark vehicle exit
  Future<bool> markVehicleExit(String bookingId) async {
    try {
      await _withRetry(() => 
        _supabase
          .from('parking_bookings')
          .update({
            'exit_time': DateTime.now().toUtc().toIso8601String(),
            'status': 'completed',
          })
          .eq('id', bookingId)
      );
      return true;
    } catch (e) {
      print('Error marking exit: $e');
      return false;
    }
  }
} 