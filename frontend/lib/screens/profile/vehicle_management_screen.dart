import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      setState(() => _isLoading = true);
      
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('user_vehicles')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vehicles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addEditVehicle([Map<String, dynamic>? existingVehicle]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddEditVehicleDialog(vehicle: existingVehicle),
    );

    if (result != null) {
      try {
        final userId = _supabase.auth.currentUser!.id;
        if (existingVehicle == null) {
          // Adding new vehicle
          await _supabase.from('user_vehicles').insert({
            'user_id': userId,
            'vehicle_type': result['vehicle_type'],
            'vehicle_number': result['vehicle_number'],
            'nickname': result['nickname'],
            'created_at': DateTime.now().toIso8601String(),
          });
        } else {
          // Updating existing vehicle
          await _supabase
              .from('user_vehicles')
              .update({
                'vehicle_type': result['vehicle_type'],
                'vehicle_number': result['vehicle_number'],
                'nickname': result['nickname'],
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingVehicle['id']);
        }
        
        await _loadVehicles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(existingVehicle == null
                  ? 'Vehicle added successfully'
                  : 'Vehicle updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Return true to indicate changes were made
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ${existingVehicle == null ? 'adding' : 'updating'} vehicle: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteVehicle(Map<String, dynamic> vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Are you sure you want to delete ${vehicle['nickname'] ?? 'this vehicle'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase
            .from('user_vehicles')
            .delete()
            .eq('id', vehicle['id']);
        
        await _loadVehicles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Return true to indicate changes were made
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting vehicle: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return true to indicate whether changes were made
        Navigator.pop(context, _vehicles.isNotEmpty);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Vehicles'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Return true to indicate whether changes were made
              Navigator.pop(context, _vehicles.isNotEmpty);
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _vehicles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No vehicles added yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _addEditVehicle(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Vehicle'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: Icon(
                            vehicle['vehicle_type'] == 'car'
                                ? Icons.directions_car
                                : vehicle['vehicle_type'] == 'bike'
                                    ? Icons.motorcycle
                                    : vehicle['vehicle_type'] == 'bus'
                                        ? Icons.directions_bus
                                        : Icons.pedal_bike,
                            color: Theme.of(context).primaryColor,
                            size: 32,
                          ),
                          title: Text(
                            vehicle['nickname'] ?? 'My Vehicle',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${vehicle['vehicle_type'].toString().toUpperCase()} - ${vehicle['vehicle_number']}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _addEditVehicle(vehicle),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteVehicle(vehicle),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: _vehicles.isNotEmpty
            ? FloatingActionButton(
                onPressed: () => _addEditVehicle(),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}

class AddEditVehicleDialog extends StatefulWidget {
  final Map<String, dynamic>? vehicle;

  const AddEditVehicleDialog({
    super.key,
    this.vehicle,
  });

  @override
  State<AddEditVehicleDialog> createState() => _AddEditVehicleDialogState();
}

class _AddEditVehicleDialogState extends State<AddEditVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _vehicleType;
  final _vehicleNumberController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.vehicle?['vehicle_type'] ?? 'car';
    _vehicleNumberController.text = widget.vehicle?['vehicle_number'] ?? '';
    _nicknameController.text = widget.vehicle?['nickname'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'car',
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car),
                        const SizedBox(width: 8),
                        const Text('Car'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'bike',
                    child: Row(
                      children: [
                        const Icon(Icons.motorcycle),
                        const SizedBox(width: 8),
                        const Text('Bike'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'bus',
                    child: Row(
                      children: [
                        const Icon(Icons.directions_bus),
                        const SizedBox(width: 8),
                        const Text('Bus'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'cycle',
                    child: Row(
                      children: [
                        const Icon(Icons.pedal_bike),
                        const SizedBox(width: 8),
                        const Text('Cycle'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _vehicleType = value!);
                },
              ),
              const SizedBox(height: 16),
              if (_vehicleType != 'cycle')
                TextFormField(
                  controller: _vehicleNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_vehicleType != 'cycle' &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter vehicle number';
                    }
                    return null;
                  },
                ),
              if (_vehicleType != 'cycle') const SizedBox(height: 16),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Nickname (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. My Car, Office Bike',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'vehicle_type': _vehicleType,
                'vehicle_number': _vehicleNumberController.text,
                'nickname': _nicknameController.text,
              });
            }
          },
          child: Text(widget.vehicle == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }
} 