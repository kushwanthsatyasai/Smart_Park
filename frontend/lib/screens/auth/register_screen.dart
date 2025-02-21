import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import './vehicle_aadhaar_form.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for all fields
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Vehicle type dropdown
  String? _selectedVehicleType;
  final List<String> _vehicleTypes = ['Cycle', 'Bike', 'Car', 'Bus'];

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _passwordMatchError;

  // Add these boolean state variables
  bool _isPasswordValid = false;
  bool _passwordsMatch = true;
  String? _passwordError;

  bool _validatePassword(String password) {
    RegExp passwordRegex = RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
    );
    return passwordRegex.hasMatch(password);
  }

  void _checkPasswordMatch(String value) {
    setState(() {
      _passwordsMatch = value == _passwordController.text;
    });
  }

  void _validatePasswordMatch(String value) {
    setState(() {
      if (_passwordController.text != value) {
        _passwordMatchError = 'Passwords don\'t match';
      } else {
        _passwordMatchError = null;
      }
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // First create the user with email confirmation and user metadata
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {  // Add user metadata here
          'name': _nameController.text,
          'age': int.parse(_ageController.text),
          'phone_number': _phoneController.text,
          'vehicle_type': _selectedVehicleType,
          'vehicle_number': _selectedVehicleType == 'Cycle' ? null : _vehicleNumberController.text,
          'aadhaar_number': _aadhaarController.text,
        },
        emailRedirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );

      if (authResponse.user != null) {
        // Create profile after successful signup
        await supabase.from('profiles').insert({
          'id': authResponse.user!.id,
          'email': _emailController.text.trim(),
          'name': _nameController.text,
          'age': int.parse(_ageController.text),
          'vehicle_type': _selectedVehicleType,
          'vehicle_number': _selectedVehicleType == 'Cycle' ? null : _vehicleNumberController.text,
          'aadhaar_number': _aadhaarController.text,
          'phone_number': _phoneController.text,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).execute();

        // Also update auth.users metadata
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              'name': _nameController.text,
              'age': int.parse(_ageController.text),
              'phone_number': _phoneController.text,
              'vehicle_type': _selectedVehicleType,
              'vehicle_number': _selectedVehicleType == 'Cycle' ? null : _vehicleNumberController.text,
              'aadhaar_number': _aadhaarController.text,
            },
          ),
        );

        if (mounted) {
          // Show verification dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Verification Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please check your email to verify your account. After verification, you can login.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text(
                      'OK',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacementNamed(context, '/');
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database Error: ${error.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        String errorMessage = error.message;
        if (error.message.contains('rate limit')) {
          errorMessage = 'Please wait a few minutes before trying again';
        } else if (error.message.contains('already registered')) {
          errorMessage = 'This email is already registered. Please try logging in.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final response = await Supabase.instance.client.auth.signInWithOAuth(
        Provider.google,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
        queryParams: {
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );
      
      if (response) {
        if (mounted) {
          // Get user data after successful sign in
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            // Create or update profile
            await Supabase.instance.client.from('profiles').upsert({
              'id': user.id,
              'email': user.email,
              'name': user.userMetadata?['full_name'],
              'updated_at': DateTime.now().toIso8601String(),
            });
            
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create an account ✨',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Welcome! Please enter your details.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _ageController,
                        label: 'Age',
                        prefixIcon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(),
                      const SizedBox(height: 16),
                      if (_selectedVehicleType != null && _selectedVehicleType != 'Cycle')
                        _buildTextField(
                          controller: _vehicleNumberController,
                          label: 'Vehicle Number',
                          prefixIcon: Icons.directions_car_outlined,
                        ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _aadhaarController,
                        label: 'Aadhaar Number',
                        prefixIcon: Icons.credit_card_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 16),
                      _buildConfirmPasswordField(),
                      const SizedBox(height: 32),
                      _buildRegisterButton(),
                      const SizedBox(height: 24),
                      _buildSocialLoginSection(),
                      const SizedBox(height: 16),
                      _buildLoginLink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(prefixIcon, color: Colors.blue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedVehicleType,
        decoration: InputDecoration(
          labelText: 'Vehicle Type',
          prefixIcon: const Icon(Icons.directions_bike_outlined, color: Colors.blue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: _vehicleTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedVehicleType = newValue;
          });
        },
      ),
    );
  }

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordController,
      label: 'Password',
      prefixIcon: Icons.lock_outline,
      isPassword: true,
    );
  }

  Widget _buildConfirmPasswordField() {
    return _buildTextField(
      controller: _confirmPasswordController,
      label: 'Confirm Password',
      prefixIcon: Icons.lock_outline,
      isPassword: true,
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading 
          ? null 
          : () async {
              if (_isLoading) return;
              
              // Disable button for 30 seconds after click
              setState(() => _isLoading = true);
              await _handleRegister();
              if (mounted) {
                await Future.delayed(const Duration(seconds: 30));
                setState(() => _isLoading = false);
              }
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialLoginSection() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or sign up with',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _signInWithGoogle,
          icon: Icon(Icons.g_mobiledata, size: 24, color: Colors.blue.shade700),
          label: const Text(
            'Continue with Google',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account?'),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Log in',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleNumberController.dispose();
    _aadhaarController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}