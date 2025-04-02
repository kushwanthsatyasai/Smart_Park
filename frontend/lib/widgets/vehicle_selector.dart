import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/profile/vehicle_management_screen.dart';

class UserVehicle {
  final String id;
  final String type;
  final String number;
  final String nickname;

  UserVehicle({
    required this.id,
    required this.type,
    required this.number,
    required this.nickname,
  });

  factory UserVehicle.fromJson(Map<String, dynamic> json) {
    return UserVehicle(
      id: json['id'],
      type: json['vehicle_type'],
      number: json['vehicle_number'],
      nickname: json['nickname'] ?? 'My Vehicle',
    );
  }
}

class VehicleSelector extends StatefulWidget {
  final Function(UserVehicle) onVehicleSelected;
  final UserVehicle? initialVehicle;
  final bool isCompact;

  const VehicleSelector({
    Key? key,
    required this.onVehicleSelected,
    this.initialVehicle,
    this.isCompact = false,
  }) : super(key: key);

  @override
  State<VehicleSelector> createState() => _VehicleSelectorState();
}

class _VehicleSelectorState extends State<VehicleSelector> {
  final _supabase = Supabase.instance.client;
  List<UserVehicle> _userVehicles = [];
  UserVehicle? _selectedVehicle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.initialVehicle;
    _loadUserVehicles();
  }

  Future<void> _loadUserVehicles() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_vehicles')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      if (mounted) {
        setState(() {
          _userVehicles = (response as List)
              .map((vehicle) => UserVehicle.fromJson(vehicle))
              .toList();
          
          if (_selectedVehicle == null && _userVehicles.isNotEmpty) {
            _selectedVehicle = _userVehicles.first;
            widget.onVehicleSelected(_userVehicles.first);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user vehicles: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.motorcycle;
      case 'bus':
        return Icons.directions_bus;
      case 'cycle':
        return Icons.pedal_bike;
      default:
        return Icons.directions_car;
    }
  }

  void _showAddVehicleDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VehicleManagementScreen(),
      ),
    );
    
    if (result == true) {
      _loadUserVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: widget.isCompact ? 40 : 48,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userVehicles.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: _showAddVehicleDialog,
        tooltip: 'Add Vehicle',
      );
    }

    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: () => _showVehicleSelector(context),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getVehicleIcon(_selectedVehicle?.type ?? 'car'),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedVehicle?.nickname ?? 'Select Vehicle',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showVehicleSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getVehicleIcon(_selectedVehicle?.type ?? 'car'),
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedVehicle?.nickname ?? 'Select Vehicle',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showVehicleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Vehicle',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddVehicleDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Vehicle'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _userVehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _userVehicles[index];
                final isSelected = _selectedVehicle?.id == vehicle.id;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getVehicleIcon(vehicle.type),
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                    ),
                  ),
                  title: Text(
                    vehicle.nickname,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  subtitle: Text(vehicle.number),
                  selected: isSelected,
                  trailing: isSelected ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                  ) : null,
                  onTap: () {
                    setState(() => _selectedVehicle = vehicle);
                    widget.onVehicleSelected(vehicle);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 