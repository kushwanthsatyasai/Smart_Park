import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/vehicle_selector.dart';

class VehicleProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  UserVehicle? _selectedVehicle;

  UserVehicle? get selectedVehicle => _selectedVehicle;

  Future<void> loadDefaultVehicle() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_vehicles')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _selectedVehicle = UserVehicle(
          id: response['id'],
          type: response['vehicle_type'],
          number: response['vehicle_number'],
          nickname: response['nickname'],
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error loading default vehicle: $e');
    }
  }

  void setSelectedVehicle(UserVehicle? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }
} 