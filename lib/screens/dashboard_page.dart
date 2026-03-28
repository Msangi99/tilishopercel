import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/services/api_service.dart';
import 'package:t_percel/screens/my_parcels_page.dart';
import 'package:t_percel/screens/new_parcel_page.dart';
import 'package:t_percel/screens/profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String _userName = 'Staff';
  String _userRole = 'staff';
  String? _busPlate;
  int _todayCount = 0;
  double _todayAmount = 0;
  int _weekCount = 0;
  double _weekAmount = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load user info and dashboard stats in parallel
      final results = await Future.wait([
        ApiService.getUser(),
        ApiService.getDashboardStats(),
      ]);

      final userData = results[0];
      final statsData = results[1];

      if (mounted) {
        setState(() {
          _userName = userData['user']['name'] ?? 'Staff';
          _userRole = userData['user']['role'] ?? 'staff';
          _isAdmin = userData['user']['is_admin'] ?? false;
          
          // SECURITY CHECK: Verify this is a staff account
          if (_userRole.toLowerCase() != 'staff' || _isAdmin) {
            // This is an admin account - should not have access
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This dashboard is for staff only. Please sign in with a staff account.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
            // Redirect to login after showing message
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            });
            return;
          }
          
          if (userData['assigned_bus'] != null) {
            _busPlate = userData['assigned_bus']['plate_number'];
          }
          _todayCount = statsData['today_count'] ?? 0;
          _todayAmount = (statsData['today_amount'] ?? 0).toDouble();
          _weekCount = statsData['week_count'] ?? 0;
          _weekAmount = (statsData['week_amount'] ?? 0).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        if (message.contains('Session expired') || message.contains('sign in again')) {
          // Token expired, go back to login
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showDashboardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
          left: 20,
          right: 20,
          top: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Karibu, $_userName!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (_busPlate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Bus: $_busPlate',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSheetStat('Leo Parcels', _todayCount.toString(), Icons.local_shipping, Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSheetStat('Leo Mapato', 'TZS ${_formatAmount(_todayAmount)}', Icons.attach_money, Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSheetStat('Wiki Parcels', _weekCount.toString(), Icons.inventory, AppColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSheetStat('Wiki Mapato', 'TZS ${_formatAmount(_weekAmount)}', Icons.trending_up, Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      _loadData();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleLogout();
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.redBar,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.redBar,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                  children: [
                    // Red header: logo (white bg) + slogan, downward radius
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.redBar,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: topPadding),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'asset/logo.webp',
                                    height: 64,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Text(
                                      'TILISHO PARCEL',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.redBar,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Comfort in Every Mile , Because You Deserve It.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content: three rows
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        children: [
                          // First row: View my dashboard button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showDashboardSheet(context),
                              icon: const Icon(Icons.dashboard, size: 20),
                              label: Text(
                                'View my dashboard',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                side: BorderSide(color: AppColors.primaryBlue),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Second row: two cards – My Parcel | New Parcel
                          Row(
                            children: [
                              Expanded(
                                child: _buildMenuCard(
                                  title: 'My Parcel',
                                  icon: Icons.inventory_2,
                                  color: AppColors.primaryBlue,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const MyParcelsPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMenuCard(
                                  title: 'New Parcel',
                                  icon: Icons.add_box,
                                  color: Colors.green.shade700,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const NewParcelPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Third row: QR code actions – View | Assign
                          Row(
                            children: [
                              Expanded(
                                child: _buildMenuCard(
                                  title: 'View QR code',
                                  icon: Icons.qr_code_2,
                                  color: Colors.orange.shade700,
                                  onTap: () {
                                    Navigator.pushNamed(context, '/scan-qr');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMenuCard(
                                  title: 'Assign QR code',
                                  icon: Icons.qr_code,
                                  color: Colors.teal.shade700,
                                  onTap: () {
                                    Navigator.pushNamed(context, '/assign-qr');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Fourth row: Logout | Profile
                          Row(
                            children: [
                              Expanded(
                                child: _buildMenuCard(
                                  title: 'Logout',
                                  icon: Icons.logout,
                                  color: AppColors.redBar,
                                  onTap: () async {
                                    await _handleLogout();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMenuCard(
                                  title: 'Profile',
                                  icon: Icons.person,
                                  color: AppColors.primaryBlue,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ProfilePage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            );
        },
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
