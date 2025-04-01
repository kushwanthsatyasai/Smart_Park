import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<bool> isProfileComplete() async {
    final profile = await getUserProfile();
    if (profile == null) return false;

    // Add all required fields here
    final requiredFields = [
      'name',
      'phone_number',
      'vehicle_number',
      'email',
    ];

    return requiredFields.every((field) => 
      profile[field] != null && profile[field].toString().isNotEmpty
    );
  }

  Future<bool> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String vehicleNumber,
    String? email,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      await supabase.from('profiles').upsert({
        'id': user.id,
        'name': fullName,
        'phone_number': phoneNumber,
        'vehicle_number': vehicleNumber,
        'email': email ?? user.email,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }
} 