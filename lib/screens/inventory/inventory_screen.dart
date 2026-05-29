import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'add_product_screen.dart';
import 'stock_adjustment_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all'; // 'all', 'low'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ইনভেন্টরি'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _openAddProduct(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            _buildSearchAndFilter(),
            Expanded(child: _buildProductList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          GlassCard(
            padding: EdgeInsets.zero,
            opacity: 0.1,
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'পণ্য খুঁজুন...',
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _filterChip('সব পণ্য', 'all'),
              const SizedBox(width: 8),
              _filterChip('কম স্টক', 'low'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildProductList() {
    final provider = context.watch<InventoryProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final products = _filter == 'low'
        ? provider.lowStockProducts
        : provider.searchProducts(_searchQuery);

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              _filter == 'low' ? 'কম স্টকের পণ্য নেই' : 'কোনো পণ্য পাওয়া যায়নি',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add),
              label: const Text('পণ্য যোগ করুন'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    final format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            opacity: 0.05,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: product.isLowStock
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: product.isLowStock ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          if (product.isLowStock)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('কম স্টক',
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.error)),
                            ),
                        ],
                      ),
                      if (product.category != null)
                        Text(product.category!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white54)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'স্টক: ${product.currentStock} ${product.unit}',
                            style: TextStyle(
                              fontSize: 13,
                              color: product.isLowStock
                                  ? AppColors.error
                                  : Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'বিক্রয়: ${format.format(product.sellPrice)}',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppColors.surface,
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  onSelected: (value) {
                    if (value == 'edit') _openAddProduct(product: product);
                    if (value == 'adjust') _openStockAdjust(product);
                    if (value == 'delete') _confirmDelete(product);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('সম্পাদনা')
                        ])),
                    const PopupMenuItem(
                        value: 'adjust',
                        child: Row(children: [
                          Icon(Icons.tune, color: AppColors.accent, size: 18),
                          SizedBox(width: 8),
                          Text('স্টক সমন্বয়')
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text('মুছুন')
                        ])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAddProduct({Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductScreen(product: product)),
    ).then((_) => context.read<InventoryProvider>().fetchProducts());
  }

  void _openStockAdjust(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: product)),
    ).then((_) => context.read<InventoryProvider>().fetchProducts());
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('পণ্য মুছবেন?'),
        content: Text('${product.name} মুছে ফেলা হবে।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await context.read<InventoryProvider>().deleteProduct(product.id!);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
  }
}
