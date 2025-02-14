import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _aadhaarController = TextEditingController();
  
  String _selectedVehicleType = 'Car'; // Default selection
  bool _isLoading = false;
  bool _isLogin = true;

  final List<String> _vehicleTypes = ['Car', 'Bike', 'Bus', 'Truck', 'Other'];

  Future<void> _handleAuthAction() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty ||
        (!_isLogin && (_nameController.text.isEmpty || _phoneController.text.isEmpty ||
        _ageController.text.isEmpty || _aadhaarController.text.isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      if (_isLogin) {
        final res = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (res.user != null) {
          print("Login successful! Navigating to Home...");
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } else {
        final res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'age': int.parse(_ageController.text.trim()),
            'aadhaar': _aadhaarController.text.trim(),
            'vehicle_type': _selectedVehicleType,
          },
        );

        if (res.user != null) {
          await supabase.from('profiles').insert({
            'id': res.user!.id,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'age': int.parse(_ageController.text.trim()),
            'aadhaar': _aadhaarController.text.trim(),
            'vehicle_type': _selectedVehicleType,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please verify your email.'),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            _isLogin = true;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }
  // Helper method to create input decorations for text fields
InputDecoration _buildInputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.blue.shade900],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_parking_rounded, size: 100, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    'Smart Parking',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 5, blurRadius: 15),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isLogin ? 'Welcome Back' : 'Create Account',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Registration Fields
                        if (!_isLogin) ...[
                          _buildTextField(_nameController, 'Full Name', Icons.person),
                          const SizedBox(height: 16),
                          _buildTextField(_ageController, 'Age', Icons.calendar_today, keyboardType: TextInputType.number),
                          const SizedBox(height: 16),
                          _buildTextField(_phoneController, 'Phone Number', Icons.phone),
                          const SizedBox(height: 16),
                          _buildTextField(_aadhaarController, 'Aadhaar Number', Icons.credit_card, keyboardType: TextInputType.number),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedVehicleType,
                            decoration: _buildInputDecoration('Vehicle Type', Icons.directions_car),
                            items: _vehicleTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedVehicleType = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        _buildTextField(_passwordController, 'Password', Icons.lock, obscureText: true),
                        const SizedBox(height: 24),

                        CustomButton(
                          text: _isLoading ? 'Please wait...' : (_isLogin ? 'Login' : 'Register'),
                          onPressed: _isLoading ? () {} : _handleAuthAction,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _emailController.clear();
                                    _passwordController.clear();
                                  });
                                },
                          child: Text(_isLogin ? 'Don\'t have an account? Register' : 'Already have an account? Login'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }
}
