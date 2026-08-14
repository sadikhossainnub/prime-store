import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/sales_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'add_sale_screen.dart';
import 'sale_detail_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().fetchSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('বিক্রয় তালিকা')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _buildList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSaleScreen()),
        ).then((_) {
          if (!context.mounted) return;
          context.read<SalesProvider>().fetchSales();
          context.read<DashboardProvider>().fetchStats();
        }),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('নতুন বিক্রয়'),
      ),
    );
  }

  Widget _buildList() {
    final provider = context.watch<SalesProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (provider.sales.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('কোনো বিক্রয় নেই', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.sales.length,
      itemBuilder: (context, index) {
        final s = provider.sales[index];
        final typeColor = s.saleType == 'cash'
            ? AppColors.primary
            : s.saleType == 'baki'
                ? AppColors.error
                : AppColors.accent;
        final typeLabel = s.saleType == 'cash'
            ? 'নগদ'
            : s.saleType == 'baki'
                ? 'বাকি'
                : 'আংশিক';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: s)),
            ).then((_) {
              if (!context.mounted) return;
              context.read<SalesProvider>().fetchSales();
              context.read<DashboardProvider>().fetchStats();
            }),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              opacity: 0.05,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.point_of_sale_outlined, color: typeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.customerName ?? 'নগদ বিক্রয়',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy', 'bn_BD').format(s.date),
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_format.format(s.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(typeLabel,
                            style: TextStyle(fontSize: 11, color: typeColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
