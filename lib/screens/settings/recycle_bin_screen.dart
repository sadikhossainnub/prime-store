import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'product', 'customer', 'sale', 'purchase', 'supplier'

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await DatabaseHelper.instance.getRecycleBinItems();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedFilter == 'all') return _items;
    return _items.where((i) => i['item_type'] == _selectedFilter).toList();
  }

  Future<void> _restoreItem(Map<String, dynamic> item) async {
    final binId = item['id'] as int;
    final title = item['title'] as String;

    final success = await DatabaseHelper.instance.restoreFromRecycleBin(binId);

    if (mounted) {
      if (success) {
        await _refreshAllProviders();
        await _loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ "$title" সফলভাবে পুনঃরুদ্ধার করা হয়েছে!'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('পুনরুদ্ধার করতে ব্যর্থ হয়েছে!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteItem(Map<String, dynamic> item) async {
    final binId = item['id'] as int;
    final title = item['title'] as String;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('স্থায়ীভাবে মুছবেন?'),
          ],
        ),
        content: Text('"$title" স্থায়ীভাবে মুছে ফেলা হবে। এটি আর কখনই ফিরে পাওয়া যাবে না।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.deleteFromRecycleBin(binId);
              await _loadItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$title" স্থায়ীভাবে মুছে ফেলা হয়েছে'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('স্থায়ীভাবে ডিলিট করুন'),
          ),
        ],
      ),
    );
  }

  Future<void> _emptyBin() async {
    if (_items.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('রিসাইকেল বিন খালি করবেন?'),
          ],
        ),
        content: const Text('রিসাইকেল বিনের সবকটি আইটেম স্থায়ীভাবে মুছে ফেলা হবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.emptyRecycleBin();
              await _loadItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('রিসাইকেল বিন খালি করা হয়েছে'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('হ্যাঁ, সব ডিলিট করুন'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAllProviders() async {
    context.read<InventoryProvider>().fetchProducts();
    context.read<CustomerProvider>().fetchCustomers();
    context.read<SalesProvider>().fetchSales();
    context.read<PurchaseProvider>().fetchPurchases();
    context.read<SupplierProvider>().fetchSuppliers();
    context.read<DashboardProvider>().fetchStats();
  }

  IconData _getItemIcon(String type) {
    switch (type) {
      case 'product':
        return Icons.inventory_2_rounded;
      case 'customer':
        return Icons.person_rounded;
      case 'sale':
        return Icons.point_of_sale_rounded;
      case 'purchase':
        return Icons.shopping_bag_rounded;
      case 'supplier':
        return Icons.store_rounded;
      default:
        return Icons.delete_outline_rounded;
    }
  }

  Color _getItemColor(String type) {
    switch (type) {
      case 'product':
        return AppColors.primary;
      case 'customer':
        return AppColors.accent;
      case 'sale':
        return Colors.green;
      case 'purchase':
        return Colors.orange;
      case 'supplier':
        return Colors.purpleAccent;
      default:
        return Colors.white54;
    }
  }

  String _getItemTypeName(String type) {
    switch (type) {
      case 'product':
        return 'পণ্য';
      case 'customer':
        return 'কাস্টমার';
      case 'sale':
        return 'বিক্রয়';
      case 'purchase':
        return 'ক্রয়';
      case 'supplier':
        return 'ডিলার';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('রিসাইকেল বিন (Admin)'),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              tooltip: 'বিন খালি করুন',
              onPressed: _emptyBin,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            // Filter Chips
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _filterChip('সব (${_items.length})', 'all'),
                  _filterChip('পণ্য', 'product'),
                  _filterChip('কাস্টমার', 'customer'),
                  _filterChip('বিক্রয়', 'sale'),
                  _filterChip('ক্রয়', 'purchase'),
                  _filterChip('ডিলার', 'supplier'),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Item List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_delete_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              const Text('রিসাইকেল বিন খালি আছে', style: TextStyle(color: Colors.white54, fontSize: 16)),
                              const SizedBox(height: 6),
                              const Text('মুছে ফেলা যেকোনো আইটেম এখানে থাকবে', style: TextStyle(color: Colors.white30, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final type = item['item_type'] as String;
                            final title = item['title'] as String;
                            final subtitle = item['subtitle'] as String?;
                            final deletedAtStr = item['deleted_at'] as String;
                            final deletedAt = DateTime.tryParse(deletedAtStr);
                            final color = _getItemColor(type);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: const EdgeInsets.all(14),
                                opacity: 0.06,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(_getItemIcon(type), color: color, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: color.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      _getItemTypeName(type),
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (deletedAt != null)
                                                    Text(
                                                      DateFormat('dd MMM yyyy, hh:mm a').format(deletedAt),
                                                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                title,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              if (subtitle != null && subtitle.isNotEmpty)
                                                Text(
                                                  subtitle,
                                                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(color: Colors.white12, height: 1),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _permanentlyDeleteItem(item),
                                          icon: const Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.error),
                                          label: const Text('স্থায়ীভাবে মুছুন', style: TextStyle(fontSize: 12, color: AppColors.error)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppColors.error),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () => _restoreItem(item),
                                          icon: const Icon(Icons.restore_rounded, size: 16),
                                          label: const Text('পুনরুদ্ধার করুন', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) => setState(() => _selectedFilter = value),
      ),
    );
  }
}
