class AppConstants {
  // API URLs
  static const String supabaseUrl = 'https://ubqrfmyvutvstgxeubvr.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVicXJmbXl2dXR2c3RneGV1YnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyNzc1MDgsImV4cCI6MjA1NDg1MzUwOH0.3wU-ZJFNSJZIoL2DdrlJjbmb1799ElBtt_IXNwXf-ek';

  // Server URLs
  static const String defaultQrServerUrl = 'http://192.168.137.1:8000';
  static const String localQrServerUrl = 'http://localhost:8000';
  static const String fallbackQrServerUrl = 'http://127.0.0.1:8000';

  // App Settings
  static const String appName = 'Smart Parking';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String serverUrlKey = 'server_url';
  static const String lastSuccessfulServerUrlKey = 'last_successful_server_url';

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String authError = 'Authentication failed. Please try again.';
  static const String serverError = 'Server connection failed. Check server settings.';

  // Success Messages
  static const String loginSuccess = 'Successfully logged in!';
  static const String registrationSuccess = 'Registration successful!';
  static const String bookingSuccess = 'Booking confirmed successfully!';

  // Validation Messages
  static const String emailRequired = 'Email is required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String passwordRequired = 'Password is required';
  static const String passwordLength = 'Password must be at least 6 characters';
  static const String nameRequired = 'Name is required';
  static const String phoneRequired = 'Phone number is required';
  static const String vehicleNumberRequired = 'Vehicle number is required';
} 