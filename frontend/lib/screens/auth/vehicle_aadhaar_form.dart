import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';

class VehicleAadhaarForm extends StatefulWidget {
  final String userId;
  final String? email;
  final String? name;

  const VehicleAadhaarForm({
    super.key, 
    required this.userId,
    this.email,
    this.name,
  });

  @override
  State<VehicleAadhaarForm> createState() => _VehicleAadhaarFormState();
}

class _VehicleAadhaarFormState extends State<VehicleAadhaarForm> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _aadhaarController = TextEditingController();
  String _selectedVehicleType = 'Car';
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // Create or update profile
      await supabase.from('profiles').upsert({
        'id': widget.userId,
        'email': widget.email,
        'name': widget.name,
        'vehicle_type': _selectedVehicleType,
        'vehicle_number': _selectedVehicleType == 'Cycle' ? null : _vehicleNumberController.text.trim(),
        'aadhaar_number': _aadhaarController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home screen
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
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
        title: const Text('Vehicle Details'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: {
                  'Cycle': Icons.pedal_bike,
                  'Bike': Icons.motorcycle,
                  'Car': Icons.directions_car,
                  'Bus': Icons.directions_bus,
                }.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value),
                        const SizedBox(width: 10),
                        Text(entry.key),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedVehicleType = newValue!);
                },
                validator: (value) => value == null ? 'Please select vehicle type' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedVehicleType != 'Cycle')
                TextFormField(
                  controller: _vehicleNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (value) => _selectedVehicleType != 'Cycle' && 
                      (value?.isEmpty ?? true) ? 'Please enter vehicle number' : null,
                  textCapitalization: TextCapitalization.characters,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aadhaarController,
                decoration: const InputDecoration(
                  labelText: 'Aadhaar Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                maxLength: 12,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter Aadhaar number';
                  if (value!.length != 12) return 'Aadhaar number must be 12 digits';
                  if (!RegExp(r'^[0-9]{12}$').hasMatch(value)) {
                    return 'Invalid Aadhaar number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Submit',
                onPressed: _isLoading ? null : _submitForm,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }
}