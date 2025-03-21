import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_drawer.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? existingProfile;

  const CompleteProfileScreen({
    super.key,
    required this.userId,
    this.existingProfile,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _aadhaarController = TextEditingController();
  String? _selectedVehicleType = 'Car';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingProfile != null) {
      _nameController.text = widget.existingProfile!['name'] ?? '';
      _ageController.text = widget.existingProfile!['age']?.toString() ?? '';
      _vehicleNumberController.text =
          widget.existingProfile!['vehicle_number'] ?? '';
      _aadhaarController.text = widget.existingProfile!['aadhaar_number'] ?? '';
      _phoneController.text = widget.existingProfile!['phone_number'] ?? '';
      _selectedVehicleType = widget.existingProfile!['vehicle_type'];
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    IconData? prefixIcon,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          counterText: '',
        ),
        validator: validator,
        maxLength: maxLength,
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
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
          setState(() {
            _selectedVehicleType = newValue;
            if (newValue == 'Cycle') {
              _vehicleNumberController.clear();
            }
          });
        },
        validator: (value) =>
            value == null ? 'Please select vehicle type' : null,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) throw 'User not found';

      await supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'name': _nameController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'phone_number': _phoneController.text.trim(),
        'vehicle_type': _selectedVehicleType,
        'vehicle_number': _selectedVehicleType == 'Cycle'
            ? null
            : _vehicleNumberController.text.trim(),
        'aadhaar_number': _aadhaarController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
        title: const Text('Complete Profile'),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                label: 'Full Name',
                controller: _nameController,
                prefixIcon: Icons.person,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your name' : null,
              ),
              _buildTextField(
                label: 'Age',
                controller: _ageController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.calendar_today,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your age' : null,
              ),
              _buildTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone,
                maxLength: 10,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter phone number';
                  }
                  if (value!.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  return null;
                },
              ),
              _buildDropdownField(),
              if (_selectedVehicleType != 'Cycle')
                _buildTextField(
                  label: 'Vehicle Number',
                  controller: _vehicleNumberController,
                  prefixIcon: Icons.numbers,
                  validator: (value) => _selectedVehicleType != 'Cycle' &&
                          (value?.isEmpty ?? true)
                      ? 'Please enter vehicle number'
                      : null,
                ),
              _buildTextField(
                label: 'Aadhaar Number',
                controller: _aadhaarController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.credit_card,
                maxLength: 12,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter Aadhaar number';
                  }
                  if (value!.length != 12) {
                    return 'Aadhaar number must be 12 digits';
                  }
                  if (!RegExp(r'^[0-9]{12}$').hasMatch(value)) {
                    return 'Invalid Aadhaar number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Save Profile',
                onPressed: _isLoading ? null : _saveProfile,
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
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _vehicleNumberController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }
}
