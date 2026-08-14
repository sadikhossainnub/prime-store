import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;
  const SaleDetailScreen({super.key, required this.sale});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  List<SaleItem> _items = [];
  bool _isLoading = true;
  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await context.read<SalesProvider>().getSaleItems(widget.sale.id!);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    final typeColor = s.saleType == 'cash'
        ? AppColors.primary
        : s.saleType == 'baki'
            ? AppColors.error
            : AppColors.accent;
    final typeLabel =
        s.saleType == 'cash' ? 'নগদ' : s.saleType == 'baki' ? 'বাকি' : 'আংশিক';

    return Scaffold(
      appBar: AppBar(
        title: const Text('বিক্রয়ের বিবরণ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('বিক্রয়ের ধরন',
                                style: TextStyle(color: Colors.white54)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(typeLabel,
                                  style: TextStyle(
                                      color: typeColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _row('কাস্টমার', s.customerName ?? 'নগদ বিক্রয়'),
                        _row('তারিখ',
                            DateFormat('dd MMM yyyy', 'bn_BD').format(s.date)),
                        if (s.invoiceNo != null) _row('চালান নম্বর', s.invoiceNo!),
                        if (s.note != null) _row('নোট', s.note!),
                        const Divider(color: Colors.white12),
                        _row('মোট', _format.format(s.totalAmount), bold: true),
                        _row('নগদ প্রাপ্ত', _format.format(s.paidAmount),
                            color: AppColors.primary),
                        if (s.bakiAmount > 0)
                          _row('বাকি', _format.format(s.bakiAmount),
                              color: AppColors.error),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('পণ্য তালিকা',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ..._items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          opacity: 0.05,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      '${item.quantity} ${item.productUnit ?? ''} × ${_format.format(item.sellPrice)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                              Text(_format.format(item.totalPrice),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? Colors.white,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('বিক্রয় মুছবেন?'),
        content: const Text('এই বিক্রয় রিসাইকেল বিন-এ স্থানান্তর করা হবে এবং পণ্য স্টক ও বাকি এডজাস্ট হবে। এডমিন পরবর্তীতে তা পুনঃরুদ্ধার করতে পারবেন।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await context.read<SalesProvider>().deleteSale(widget.sale.id!);
              if (!ctx.mounted) return;
              await context.read<InventoryProvider>().fetchProducts();
              if (!ctx.mounted) return;
              await context.read<CustomerProvider>().fetchCustomers();
              if (!ctx.mounted) return;
              await context.read<DashboardProvider>().fetchStats();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
  }
}
