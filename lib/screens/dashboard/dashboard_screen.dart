import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'package:intl/intl.dart';
import '../baki/add_baki_screen.dart';
import '../payment/add_payment_screen.dart';
import '../sales/add_sale_screen.dart';
import '../purchase/add_purchase_screen.dart';
import '../settings/settings_screen.dart';
import '../pos/pos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _shopName = 'আমের দোকান';
  String _ownerName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchStats();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final shop = prefs.getString('shop_name') ?? '';
    final owner = prefs.getString('owner_name') ?? '';
    if (mounted) {
      setState(() {
        _shopName = shop.isNotEmpty ? shop : 'আমের দোকান';
        _ownerName = owner;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<DashboardProvider>();
    final currencyFormat =
        NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => stats.fetchStats(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSummaryGrid(stats, currencyFormat),
                const SizedBox(height: 24),
                if (stats.topDefaulters.isNotEmpty) ...[
                  _buildTopDefaulters(stats, currencyFormat),
                  const SizedBox(height: 24),
                ],
                _buildRecentActivityHeader(),
                const SizedBox(height: 10),
                _buildRecentTransactions(stats, currencyFormat),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_shopName 🏪',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            if (_ownerName.isNotEmpty)
              Text('মালিক: $_ownerName',
                  style: Theme.of(context).textTheme.bodyMedium),
            Text(
              DateFormat('EEEE, d MMMM', 'bn_BD').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.point_of_sale_rounded, color: AppColors.accent, size: 26),
              tooltip: 'POS বিক্রয়',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PosScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 26),
              tooltip: 'সেটিংস',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: SvgPicture.asset('assets/images/logo.svg', width: 28, height: 28),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(DashboardProvider stats, NumberFormat format) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.25,
      children: [
        _buildStatCard('মোট বাকি', stats.totalDue, AppColors.error, Icons.money_off),
        _buildStatCard('আজকের বিক্রয়', stats.todaySales, AppColors.primary, Icons.point_of_sale),
        _buildStatCard('আজকের আদায়', stats.todayPaid, Colors.green, Icons.account_balance_wallet),
        _buildStatCard('আজকের ক্রয়', stats.todayPurchases, AppColors.accent, Icons.shopping_bag_outlined),
        _buildStatCard('মোট লাভ', stats.totalProfit, Colors.blue, Icons.trending_up),
        _buildStatCard(
          'কম স্টক',
          stats.lowStockCount.toDouble(),
          stats.lowStockCount > 0 ? AppColors.error : Colors.green,
          Icons.inventory_2_outlined,
          isCount: true,
        ),
        _buildStatCard(
          'সক্রিয় গ্রাহক',
          stats.activeCustomers.toDouble(),
          Colors.teal,
          Icons.people_alt_rounded,
          isCount: true,
          suffix: 'জন',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, double amount, Color color, IconData icon,
      {bool isCount = false, String suffix = 'টি'}) {
    final format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');
    return GlassCard(
      padding: const EdgeInsets.all(12),
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          FittedBox(
            child: Text(
              isCount ? '${amount.toInt()} $suffix' : format.format(amount),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDefaulters(DashboardProvider stats, NumberFormat format) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('শীর্ষ বকেয়াদার',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...stats.topDefaulters.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                opacity: 0.05,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.error.withValues(alpha: 0.15),
                      child: Text(
                        (d['name'] as String)[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(d['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      format.format(d['total_baki']),
                      style: const TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildRecentActivityHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('সাম্প্রতিক লেনদেন',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text('সব দেখুন', style: TextStyle(color: AppColors.primary, fontSize: 13)),
      ],
    );
  }

  Widget _buildRecentTransactions(DashboardProvider stats, NumberFormat format) {
    if (stats.recentTransactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.white24),
              SizedBox(height: 8),
              Text('কোনো লেনদেন নেই', style: TextStyle(color: Colors.white24)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.recentTransactions.length,
      itemBuilder: (context, index) {
        final tx = stats.recentTransactions[index];
        final type = tx['type'] as String;
        final isBaki = type == 'baki';
        final isSale = type == 'sale';
        final color = isBaki
            ? AppColors.error
            : isSale
                ? AppColors.primary
                : Colors.green;
        final icon = isBaki
            ? Icons.remove_circle_outline
            : isSale
                ? Icons.point_of_sale
                : Icons.add_circle_outline;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            opacity: 0.05,
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx['customer_name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        DateFormat('dd MMM, hh:mm a', 'bn_BD')
                            .format(DateTime.parse(tx['date'] as String)),
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Text(
                  format.format(tx['amount']),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _showQuickActionMenu,
      child: const Icon(Icons.add),
    );
  }

  void _showQuickActionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('দ্রুত এন্ট্রি',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _quickAction(
                    icon: Icons.remove_circle_outline,
                    label: 'বাকি যোগ',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AddBakiScreen()))
                          .then((_) {
                        if (!context.mounted) return;
                        context.read<DashboardProvider>().fetchStats();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickAction(
                    icon: Icons.add_circle_outline,
                    label: 'আদায়',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AddPaymentScreen()))
                          .then((_) {
                        if (!context.mounted) return;
                        context.read<DashboardProvider>().fetchStats();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickAction(
                    icon: Icons.point_of_sale,
                    label: 'বিক্রয়',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AddSaleScreen()))
                          .then((_) {
                        if (!context.mounted) return;
                        context.read<DashboardProvider>().fetchStats();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickAction(
                    icon: Icons.shopping_bag_outlined,
                    label: 'ক্রয়',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AddPurchaseScreen()))
                          .then((_) {
                        if (!context.mounted) return;
                        context.read<DashboardProvider>().fetchStats();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const PosScreen()));
                },
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('POS বিক্রয় (Point of Sale)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 18),
        opacity: 0.1,
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
