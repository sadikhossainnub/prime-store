import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'customers/customer_list_screen.dart';
import 'sales/sales_list_screen.dart';
import 'inventory/inventory_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import 'pos/pos_screen.dart';
import 'settings/recycle_bin_screen.dart';
import '../services/update_checker.dart';
import '../services/admin_auth_service.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdate(context);
    });
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CustomerListScreen(),
    const SalesListScreen(),
    const InventoryScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            if (index == 0) {
              context.read<DashboardProvider>().fetchStats();
            }
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'ড্যাশবোর্ড',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              label: 'কাস্টমার',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_rounded),
              label: 'বিক্রয়',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              label: 'ইনভেন্টরি',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              label: 'রিপোর্ট',
            ),
          ],
        ),
      ),
      // Settings accessible via drawer
      drawer: _buildDrawer(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.store_rounded, color: AppColors.primary, size: 32),
                  SizedBox(width: 12),
                  Text('আমের দোকান',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.point_of_sale_rounded, color: AppColors.accent),
              title: const Text('POS বিক্রয় (Point of Sale)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const PosScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.accent),
              title: const Text('রিসাইকেল বিন (Admin)'),
              onTap: () async {
                Navigator.pop(context);
                final verified = await AdminAuthService.verifyAdmin(context);
                if (verified && mounted) {
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded, color: AppColors.primary),
              title: const Text('সেটিংস'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
