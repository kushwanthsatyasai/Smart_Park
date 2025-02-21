import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';

class VehicleAadhaarForm extends StatefulWidget {
  final String userId;

  const VehicleAadhaarForm({super.key, required this.userId});

  @override
  State<VehicleAadhaarForm> createState() => _VehicleAadhaarFormState();
}

class _VehicleAadhaarFormState extends State<VehicleAadhaarForm> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _aadhaarController = TextEditingController();
  String _selectedVehicleType = 'Car';
  bool _isLoading = false;

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
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Submit',
                onPressed: _isLoading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  
                  setState(() => _isLoading = true);
                  try {
                    await Supabase.instance.client.from('profiles').upsert({
                      'id': widget.userId,
                      'vehicle_type': _selectedVehicleType,
                      'vehicle_number': _selectedVehicleType == 'Cycle' ? null : _vehicleNumberController.text,
                      'aadhaar_number': _aadhaarController.text,
                    });
                    
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${error.toString()}')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}