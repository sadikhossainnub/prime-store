import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../models/sale.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class PosCartItem {
  final Product product;
  double quantity;
  double sellPrice;
  double discount;

  PosCartItem({
    required this.product,
    this.quantity = 1.0,
    required this.sellPrice,
    this.discount = 0.0,
  });

  double get totalPrice => (sellPrice * quantity) - discount;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'সব';
  final List<PosCartItem> _cart = [];
  
  // Checkout state
  Customer? _selectedCustomer;
  String _saleType = 'cash'; // 'cash', 'baki', 'partial'
  bool _isSubmittingSale = false;
  final TextEditingController _paidCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().fetchProducts();
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + (item.sellPrice * item.quantity));
  double get _totalDiscount => double.tryParse(_discountCtrl.text) ?? 0.0;
  double get _total => (_subtotal - _totalDiscount).clamp(0, double.infinity);
  double get _paidAmount => double.tryParse(_paidCtrl.text) ?? 0.0;
  double get _bakiAmount => (_total - _paidAmount).clamp(0, double.infinity);
  double get _changeAmount => (_paidAmount - _total).clamp(0, double.infinity);
  int get _totalCartItems => _cart.fold(0, (sum, item) => sum + item.quantity.toInt());

  void _addToCart(Product product, [double qty = 1.0]) {
    if (product.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('পণ্যটি স্টক আউট!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final index = _cart.indexWhere((item) => item.product.id == product.id);
    setState(() {
      if (index >= 0) {
        if (_cart[index].quantity + qty <= product.currentStock) {
          _cart[index].quantity += qty;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('পর্যাপ্ত স্টক নেই!'), backgroundColor: AppColors.warning),
          );
        }
      } else {
        _cart.add(PosCartItem(product: product, sellPrice: product.sellPrice, quantity: qty));
      }
    });
  }

  void _showAddQuantityDialog(Product product) {
    if (product.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('পণ্যটি স্টক আউট!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final u = product.unit.toLowerCase().trim();
    final isKg = u == 'kg' || u == 'কেজি';
    final isLiter = u == 'liter' || u == 'লিটার' || u == 'ltr';

    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    final initialQty = existingIndex >= 0 ? _cart[existingIndex].quantity : 1.0;

    final gramCtrl = TextEditingController(
      text: (isKg || isLiter) && initialQty < 1.0 ? (initialQty * 1000).toInt().toString() : '',
    );
    final unitCtrl = TextEditingController(
      text: initialQty % 1 == 0 ? initialQty.toInt().toString() : initialQty.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'বর্তমান স্টক: ${product.currentStock} ${product.unit}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isKg || isLiter) ...[
              const Text('দ্রুত বিক্রয়ের পরিমাণ:', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _newWeightChip('১ কেজি', 1.0, unitCtrl, gramCtrl),
                  _newWeightChip('৭৫০ গ্রাম', 0.75, unitCtrl, gramCtrl),
                  _newWeightChip('৫০ গ্রাম', 0.5, unitCtrl, gramCtrl),
                  _newWeightChip('২৫০ গ্রাম', 0.25, unitCtrl, gramCtrl),
                  _newWeightChip('১০০ গ্রাম', 0.1, unitCtrl, gramCtrl),
                  _newWeightChip('৫০ গ্রাম', 0.05, unitCtrl, gramCtrl),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gramCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isKg ? 'গ্রাম-এ লিখুন (যেমন: 500 = 0.5 kg)' : 'মি.লি.-এ লিখুন (যেমন: 500 = 0.5 liter)',
                  suffixText: isKg ? 'গ্রাম' : 'মি.লি.',
                  prefixIcon: const Icon(Icons.fitness_center_rounded, color: AppColors.primary),
                ),
                onChanged: (val) {
                  final g = double.tryParse(val) ?? 0;
                  if (g > 0) {
                    unitCtrl.text = (g / 1000).toString();
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: unitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: !isKg && !isLiter,
              decoration: InputDecoration(
                labelText: 'বিক্রয়ের পরিমাণ (${product.unit})',
                suffixText: product.unit,
                prefixIcon: const Icon(Icons.numbers_rounded, color: AppColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final qty = double.tryParse(unitCtrl.text) ?? 0.0;
              if (qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('সঠিক পরিমাণ লিখুন!'), backgroundColor: AppColors.warning),
                );
                return;
              }
              if (qty > product.currentStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('পর্যাপ্ত স্টক নেই! সর্বোচ্চ: ${product.currentStock} ${product.unit}'), backgroundColor: AppColors.warning),
                );
                return;
              }

              setState(() {
                if (existingIndex >= 0) {
                  _cart[existingIndex].quantity = qty;
                } else {
                  _cart.add(PosCartItem(product: product, sellPrice: product.sellPrice, quantity: qty));
                }
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} (${_formatQuantity(qty, product.unit)}) কার্টে যোগ হয়েছে'),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            label: const Text('কার্টে যোগ করুন'),
          ),
        ],
      ),
    );
  }

  Widget _newWeightChip(String label, double value, TextEditingController unitCtrl, TextEditingController gramCtrl) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: const TextStyle(color: Colors.white),
      onPressed: () {
        unitCtrl.text = value % 1 == 0 ? value.toInt().toString() : value.toString();
        if (value < 1.0) {
          gramCtrl.text = (value * 1000).toInt().toString();
        } else {
          gramCtrl.clear();
        }
      },
    );
  }

  void _updateCartQuantity(int index, double delta) {
    setState(() {
      final newQty = _cart[index].quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else if (newQty <= _cart[index].product.currentStock) {
        _cart[index].quantity = newQty;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('পর্যাপ্ত স্টক নেই!'), backgroundColor: AppColors.warning),
        );
      }
    });
  }

  String _formatQuantity(double quantity, String unit) {
    final u = unit.toLowerCase().trim();
    if (u == 'kg' || u == 'কেজি') {
      if (quantity < 1.0) {
        final grams = (quantity * 1000).round();
        return '$grams গ্রাম';
      } else {
        final formatted = quantity % 1 == 0
            ? quantity.toInt().toString()
            : quantity.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        return '$formatted কেজি';
      }
    } else if (u == 'liter' || u == 'লিটার' || u == 'ltr') {
      if (quantity < 1.0) {
        final ml = (quantity * 1000).round();
        return '$ml মি.লি.';
      } else {
        final formatted = quantity % 1 == 0
            ? quantity.toInt().toString()
            : quantity.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        return '$formatted লিটার';
      }
    } else {
      final formatted = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
      return '$formatted $unit';
    }
  }

  void _showEditQuantityDialog(int index, [VoidCallback? onUpdateModal]) {
    final item = _cart[index];
    final u = item.product.unit.toLowerCase().trim();
    final isKg = u == 'kg' || u == 'কেজি';
    final isLiter = u == 'liter' || u == 'লিটার' || u == 'ltr';

    final gramCtrl = TextEditingController(
      text: (isKg || isLiter) && item.quantity < 1.0 ? (item.quantity * 1000).toInt().toString() : '',
    );
    final unitCtrl = TextEditingController(text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.scale_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${item.product.name} (${item.product.unit})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isKg || isLiter) ...[
              const Text('দ্রুত ওজন নির্বাচন করুন:', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _weightChip(ctx, '১ কেজি', 1.0, item, unitCtrl, gramCtrl),
                  _weightChip(ctx, '৭৫০ গ্রাম', 0.75, item, unitCtrl, gramCtrl),
                  _weightChip(ctx, '৫০০ গ্রাম', 0.5, item, unitCtrl, gramCtrl),
                  _weightChip(ctx, '২৫০ গ্রাম', 0.25, item, unitCtrl, gramCtrl),
                  _weightChip(ctx, '১০০ গ্রাম', 0.1, item, unitCtrl, gramCtrl),
                  _weightChip(ctx, '৫০ গ্রাম', 0.05, item, unitCtrl, gramCtrl),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gramCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isKg ? 'গ্রাম-এ লিখুন (যেমন: 500 = 0.5 kg)' : 'মি.লি.-এ লিখুন (যেমন: 500 = 0.5 liter)',
                  suffixText: isKg ? 'গ্রাম' : 'মি.লি.',
                  prefixIcon: const Icon(Icons.fitness_center_rounded, color: AppColors.primary),
                ),
                onChanged: (val) {
                  final g = double.tryParse(val) ?? 0;
                  if (g > 0) {
                    unitCtrl.text = (g / 1000).toString();
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: unitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'পরিমাণ (${item.product.unit})',
                suffixText: item.product.unit,
                prefixIcon: const Icon(Icons.numbers_rounded, color: AppColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(unitCtrl.text) ?? 0.0;
              if (newQty <= 0) {
                setState(() => _cart.removeAt(index));
              } else if (newQty <= item.product.currentStock) {
                setState(() => _cart[index].quantity = newQty);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('পর্যাপ্ত স্টক নেই!'), backgroundColor: AppColors.warning),
                );
                return;
              }
              Navigator.pop(ctx);
              if (onUpdateModal != null) onUpdateModal();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  Widget _weightChip(BuildContext ctx, String label, double value, PosCartItem item, TextEditingController unitCtrl, TextEditingController gramCtrl) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: const TextStyle(color: Colors.white),
      onPressed: () {
        unitCtrl.text = value % 1 == 0 ? value.toInt().toString() : value.toString();
        if (value < 1.0) {
          gramCtrl.text = (value * 1000).toInt().toString();
        } else {
          gramCtrl.clear();
        }
      },
    );
  }

  void _openPosScan() {
    final inventory = context.read<InventoryProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('বারকোড স্ক্যান করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('পণ্যের বারকোড ক্যামেরার সামনে ধরুন', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code = barcodes.first.rawValue;
                      if (code != null && code.isNotEmpty) {
                        Navigator.pop(ctx);
                        final match = inventory.products.where((p) => p.barcode == code).firstOrNull;
                        if (match != null) {
                          _showAddQuantityDialog(match);
                        } else {
                          setState(() => _searchCtrl.text = code);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('বারকোড: $code - মিল পাওয়া যায়নি'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white54),
                label: const Text('বাতিল করুন', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _saleType = 'cash';
      _paidCtrl.clear();
      _discountCtrl.clear();
      _noteCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final products = inventory.products;

    // Categories
    final categories = ['সব', ...products.map((p) => p.category ?? 'অন্যান্য').toSet()];

    // Filter products
    final filteredProducts = products.where((p) {
      final matchesQuery = _searchCtrl.text.isEmpty ||
          p.name.toLowerCase().contains(_searchCtrl.text.toLowerCase()) ||
          (p.barcode != null && p.barcode!.contains(_searchCtrl.text));
      final matchesCategory = _selectedCategory == 'সব' ||
          (p.category ?? 'অন্যান্য') == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS বিক্রয় (Point of Sale)'),
        actions: [
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: 'কার্ট খালি করুন',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('কার্ট খালি করবেন?'),
                    content: const Text('কার্টের সমস্ত পণ্য মুছে ফেলা হবে।'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('না', style: TextStyle(color: Colors.white54)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _clearCart();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        child: const Text('হ্যাঁ, ডিলিট করুন'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            // Search & Filter Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                opacity: 0.08,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'পণ্য খুঁজুন...',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      ),
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                        tooltip: 'বারকোড স্ক্যান',
                        onPressed: _openPosScan,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Category Horizontal List
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Product Grid
            Expanded(
              child: inventory.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'কোনো পণ্য পাওয়া যায়নি',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            final cartItemIndex = _cart.indexWhere((i) => i.product.id == product.id);
                            final inCartQty = cartItemIndex >= 0 ? _cart[cartItemIndex].quantity : 0.0;

                            return _buildProductCard(product, inCartQty);
                          },
                        ),
            ),
          ],
        ),
      ),

      // Bottom Cart Checkout Bar
      bottomSheet: _cart.isNotEmpty ? _buildCartBanner() : null,
    );
  }

  Widget _buildProductCard(Product product, double inCartQty) {
    final isOut = product.currentStock <= 0;
    final isLow = product.isLowStock;

    return InkWell(
      onTap: isOut ? null : () => _showAddQuantityDialog(product),
      borderRadius: BorderRadius.circular(20),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        opacity: 0.06,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isOut
                      ? AppColors.error.withValues(alpha: 0.2)
                      : isLow
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOut ? 'আউট অব স্টক' : 'স্টক: ${product.currentStock.toStringAsFixed(0)} ${product.unit}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOut ? AppColors.error : isLow ? AppColors.warning : AppColors.primary,
                  ),
                ),
              ),
              if (inCartQty > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatQuantity(inCartQty, product.unit),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Product photo or icon
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.photoPath != null && File(product.photoPath!).existsSync()
                  ? Image.file(
                      File(product.photoPath!),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 36,
                        color: isOut ? Colors.white12 : Colors.white24,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            product.category ?? 'সাধারণ',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format.format(product.sellPrice),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.accent),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isOut ? Colors.white10 : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildCartBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_rounded, color: AppColors.primary, size: 30),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.error,
                    child: Text(
                      '$_totalCartItems',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('সর্বমোট মূল্য', style: TextStyle(fontSize: 11, color: Colors.white54)),
                Text(
                  _format.format(_subtotal),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showCheckoutModal,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('বিলিং (Checkout)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutModal() {
    // Sync default paid controller
    if (_paidCtrl.text.isEmpty && _saleType == 'cash') {
      _paidCtrl.text = _total.toStringAsFixed(0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final customers = context.watch<CustomerProvider>().customers;

          void updateModal() => setModalState(() {});

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'অর্ডার সারসংক্ষেপ ও বিলিং',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    children: [
                      // Cart Item List
                      const Text('পণ্য তালিকা:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 8),
                      ..._cart.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      '${_format.format(item.sellPrice)} / ${item.product.unit}',
                                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 22),
                                    onPressed: () {
                                      _updateCartQuantity(idx, -1);
                                      updateModal();
                                    },
                                  ),
                                  InkWell(
                                    onTap: () => _showEditQuantityDialog(idx, updateModal),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatQuantity(item.quantity, item.product.unit),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                                    onPressed: () {
                                      _updateCartQuantity(idx, 1);
                                      updateModal();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _format.format(item.totalPrice),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Customer Selection
                      const Text('কাস্টমার নির্বাচন:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Customer?>(
                            value: _selectedCustomer,
                            hint: const Text('নগদ খদ্দের (Cash Customer)', style: TextStyle(color: Colors.white70)),
                            dropdownColor: AppColors.surface,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<Customer?>(
                                value: null,
                                child: Text('নগদ খদ্দের (Cash Customer)', style: TextStyle(color: Colors.white)),
                              ),
                              ...customers.map((c) => DropdownMenuItem<Customer?>(
                                    value: c,
                                    child: Text('${c.name} (${c.phone})', style: const TextStyle(color: Colors.white)),
                                  )),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                _selectedCustomer = val;
                                if (val != null && _saleType == 'cash') {
                                  _saleType = 'baki';
                                }
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sale Type Selector
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('নগদ (Cash)')),
                              selected: _saleType == 'cash',
                              selectedColor: AppColors.primary,
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() {
                                    _saleType = 'cash';
                                    _paidCtrl.text = _total.toStringAsFixed(0);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('বাকি (Baki)')),
                              selected: _saleType == 'baki',
                              selectedColor: AppColors.warning,
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() {
                                    _saleType = 'baki';
                                    _paidCtrl.text = '0';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('আংশিক (Partial)')),
                              selected: _saleType == 'partial',
                              selectedColor: AppColors.secondary,
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() {
                                    _saleType = 'partial';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Payment Calculations
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => updateModal(),
                              decoration: const InputDecoration(
                                labelText: 'ডিসকাউন্ট (৳)',
                                prefixIcon: Icon(Icons.discount_outlined, color: AppColors.accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _paidCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => updateModal(),
                              decoration: const InputDecoration(
                                labelText: 'জমা টাকা (৳)',
                                prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('মোট মূল্য:', style: TextStyle(color: Colors.white70)),
                                Text(_format.format(_subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (_totalDiscount > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ডিসকাউন্ট:', style: TextStyle(color: AppColors.accent)),
                                  Text('- ${_format.format(_totalDiscount)}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            const Divider(color: Colors.white24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('সর্বমোট প্রদেয়:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(_format.format(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent)),
                              ],
                            ),
                            if (_bakiAmount > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('বাকি থাকবে:', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                  Text(_format.format(_bakiAmount), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            if (_changeAmount > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ফেরত দিতে হবে:', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                  Text(_format.format(_changeAmount), style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmittingSale ? null : () => _processCheckout(ctx, setModalState),
                    icon: _isSubmittingSale
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _isSubmittingSale ? 'প্রসেসিং হচ্ছে...' : 'বিক্রি নিশ্চিত করুন',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _processCheckout(BuildContext modalContext, StateSetter setModalState) async {
    if (_cart.isEmpty || _isSubmittingSale) return;

    if ((_saleType == 'baki' || _bakiAmount > 0) && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বাকি বিক্রয়ের জন্য কাস্টমার নির্বাচন করুন!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmittingSale = true);
    setModalState(() {});

    final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final sale = Sale(
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      saleType: _saleType,
      totalAmount: _total,
      paidAmount: _paidAmount,
      bakiAmount: _bakiAmount,
      invoiceNo: invoiceNo,
      date: DateTime.now(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    final saleItems = _cart.map((i) => SaleItem(
      saleId: 0,
      productId: i.product.id!,
      productName: i.product.name,
      productUnit: i.product.unit,
      quantity: i.quantity,
      sellPrice: i.sellPrice,
      discount: i.discount,
      totalPrice: i.totalPrice,
    )).toList();

    try {
      final salesProvider = context.read<SalesProvider>();
      final inventoryProvider = context.read<InventoryProvider>();
      final dashboardProvider = context.read<DashboardProvider>();

      await salesProvider.addSale(sale, saleItems);
      await inventoryProvider.fetchProducts();
      await dashboardProvider.fetchStats();

      if (mounted) {
        if (Navigator.of(modalContext).canPop()) {
          Navigator.of(modalContext).pop();
        }
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) {
          _clearCart();
          _showReceiptDialog(sale, saleItems, invoiceNo);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('বিক্রি সেভ করতে ব্যর্থ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingSale = false);
      }
    }
  }

  void _showReceiptDialog(Sale sale, List<SaleItem> items, String invoiceNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: AppColors.primary, size: 50),
            const SizedBox(height: 8),
            const Text('বিক্রি সফল হয়েছে! ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('ইনভয়েস: $invoiceNo', style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white12),
            if (sale.customerName != null)
              Text('কাস্টমার: ${sale.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('তারিখ: ${DateFormat('dd MMM yyyy, hh:mm a').format(sale.date)}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 12),
            const Text('পণ্যসমূহ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ...items.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${i.productName} (${_formatQuantity(i.quantity, i.productUnit ?? 'pcs')})'),
                  Text(_format.format(i.totalPrice)),
                ],
              ),
            )),
            const Divider(color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('সর্বমোট প্রদেয়:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_format.format(sale.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
              ],
            ),
            if (sale.bakiAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('বাকি পরিমাণ:', style: TextStyle(color: AppColors.error)),
                  Text(_format.format(sale.bakiAmount), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final shareText = '''
🧾 আমের দোকান - বিক্রয় রশিদ
ইনভয়েস: $invoiceNo
তারিখ: ${DateFormat('dd MMM yyyy').format(sale.date)}
কাস্টমার: ${sale.customerName ?? 'নগদ খদ্দের'}
মোট টাকা: ${_format.format(sale.totalAmount)}
জমা: ${_format.format(sale.paidAmount)}
বাকি: ${_format.format(sale.bakiAmount)}
ধন্যবাদ আবার আসবেন!
''';
              Share.share(shareText);
            },
            icon: const Icon(Icons.share, color: AppColors.primary),
            label: const Text('শেয়ার করুন', style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }
}
