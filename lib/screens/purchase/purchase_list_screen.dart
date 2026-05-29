import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/purchase_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'add_purchase_screen.dart';
import 'purchase_detail_screen.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().fetchPurchases();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ক্রয় তালিকা')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _buildList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
        ).then((_) => context.read<PurchaseProvider>().fetchPurchases()),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('নতুন ক্রয়'),
      ),
    );
  }

  Widget _buildList() {
    final provider = context.watch<PurchaseProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (provider.purchases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('কোনো ক্রয় নেই', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.purchases.length,
      itemBuilder: (context, index) {
        final p = provider.purchases[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchase: p)),
            ),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              opacity: 0.05,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.supplierName ?? 'নগদ ক্রয়',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy', 'bn_BD').format(p.date),
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                        if (p.invoiceNo != null)
                          Text('চালান: ${p.invoiceNo}',
                              style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_format.format(p.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (p.dueAmount > 0)
                        Text('বকেয়া: ${_format.format(p.dueAmount)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.error)),
                      if (p.dueAmount <= 0)
                        const Text('পরিশোধিত',
                            style: TextStyle(fontSize: 11, color: AppColors.primary)),
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
