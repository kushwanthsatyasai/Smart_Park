import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './admin_analytics_screen.dart';
import '../auth/login_screen.dart';
import './qr_scanner_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      // Check if user is admin based on email
      final email = user.email?.toLowerCase() ?? '';
      final isAdmin = email.contains('admin') || email.contains('administrator');

      if (isAdmin) {
        setState(() => _isAdmin = true);
        _loadDashboardStats();
      } else {
        _redirectToLogin();
      }
    } catch (e) {
      print('Error checking admin access: $e');
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _isLoading = true);
    try {
      // Get total parking lots
      final lotsResponse = await _supabase
          .from('parking_lots')
          .select('id');

      // Get total bookings
      final bookingsResponse = await _supabase
          .from('bookings')
          .select('id');

      // Get total users (excluding admins)
      final usersResponse = await _supabase
          .from('profiles')
          .select('id')
          .neq('role', 'admin');

      setState(() {
        _stats = {
          'totalLots': lotsResponse.length,
          'totalBookings': bookingsResponse.length,
          'totalUsers': usersResponse.length,
        };
      });
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
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
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Smart Parking System',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.add_location),
              title: const Text('Register Parking Lot'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/register-parking');
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Generate QR Codes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/generate-qr');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics & Slot Management'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAnalyticsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _supabase.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildStatCard(
                          'Total Parking Lots',
                          _stats['totalLots']?.toString() ?? '0',
                          Icons.local_parking,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Total Bookings',
                          _stats['totalBookings']?.toString() ?? '0',
                          Icons.book_online,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Total Users',
                          _stats['totalUsers']?.toString() ?? '0',
                          Icons.people,
                          Colors.orange,
                        ),
                        _buildActionCard(
                          'Add Parking Lot',
                          Icons.add_location,
                          Colors.purple,
                          () => Navigator.pushNamed(
                              context, '/admin/register-parking'),
                        ),
                        _buildDashboardCard(
                          title: 'Scan Entry QR',
                          icon: Icons.qr_code_scanner,
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QRScannerScreen(isEntry: true),
                            ),
                          ),
                        ),
                        _buildDashboardCard(
                          title: 'Scan Exit QR',
                          icon: Icons.qr_code_2,
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QRScannerScreen(isEntry: false),
                            ),
                          ),
                        ),
                        _buildDashboardCard(
                          title: 'View Active Sessions',
                          icon: Icons.access_time,
                          color: Colors.orange,
                          onTap: () {
                            // TODO: Implement active sessions view
                          },
                        ),
                        _buildDashboardCard(
                          title: 'Reports',
                          icon: Icons.analytics,
                          color: Colors.purple,
                          onTap: () {
                            // TODO: Implement reports view
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.8),
                color,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
