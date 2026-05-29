import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/supplier.dart';
import '../../models/purchase.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  List<Purchase> _purchases = [];
  bool _isLoading = true;
  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _purchases = await DatabaseHelper.instance.getPurchasesBySupplier(widget.supplier.id!);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.supplier.name)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            _buildHeader(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('ক্রয়ের ইতিহাস',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(child: _buildPurchaseList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              child: Text(widget.supplier.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 22, color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.supplier.phone,
                      style: const TextStyle(color: Colors.white70)),
                  if (widget.supplier.address != null)
                    Text(widget.supplier.address!,
                        style: const TextStyle(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 6),
                  const Text('মোট বকেয়া', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  Text(
                    _format.format(widget.supplier.totalDue),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.supplier.totalDue > 0 ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_purchases.isEmpty) {
      return const Center(
          child: Text('কোনো ক্রয় নেই', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _purchases.length,
      itemBuilder: (context, index) {
        final p = _purchases[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            opacity: 0.05,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy', 'bn_BD').format(p.date),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (p.invoiceNo != null)
                        Text('চালান: ${p.invoiceNo}',
                            style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      Text(
                        'পরিশোধ: ${_format.format(p.paidAmount)} / ${_format.format(p.totalAmount)}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_format.format(p.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (p.dueAmount > 0)
                      Text('বকেয়া: ${_format.format(p.dueAmount)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.error)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
