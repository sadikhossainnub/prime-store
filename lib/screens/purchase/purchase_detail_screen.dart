import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/purchase.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final Purchase purchase;
  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  List<PurchaseItem> _items = [];
  bool _isLoading = true;
  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await context.read<PurchaseProvider>().getPurchaseItems(widget.purchase.id!);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ক্রয়ের বিবরণ'),
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
                        _row('সরবরাহকারী', p.supplierName ?? 'নগদ ক্রয়'),
                        _row('তারিখ', DateFormat('dd MMM yyyy', 'bn_BD').format(p.date)),
                        if (p.invoiceNo != null) _row('চালান নম্বর', p.invoiceNo!),
                        if (p.note != null) _row('নোট', p.note!),
                        const Divider(color: Colors.white12),
                        _row('মোট', _format.format(p.totalAmount), bold: true),
                        _row('পরিশোধিত', _format.format(p.paidAmount),
                            color: AppColors.primary),
                        _row('বকেয়া', _format.format(p.dueAmount),
                            color: p.dueAmount > 0 ? AppColors.error : AppColors.primary),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      '${item.quantity} ${item.productUnit ?? ''} × ${_format.format(item.buyPrice)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                              Text(_format.format(item.totalPrice),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: AppColors.accent)),
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
        title: const Text('ক্রয় মুছবেন?'),
        content: const Text('এই ক্রয় রিসাইকেল বিন-এ স্থানান্তর করা হবে এবং পণ্য স্টক এডজাস্ট হবে। এডমিন পরবর্তীতে তা পুনঃরুদ্ধার করতে পারবেন।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await context.read<PurchaseProvider>().deletePurchase(widget.purchase.id!);
              await context.read<InventoryProvider>().fetchProducts();
              if (!ctx.mounted) return;
              context.read<DashboardProvider>().fetchStats();
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
