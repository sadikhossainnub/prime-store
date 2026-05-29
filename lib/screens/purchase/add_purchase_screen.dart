import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  Supplier? _selectedSupplier;
  final _invoiceCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_CartItem> _cart = [];
  final _format = NumberFormat.currency(symbol: '৳', decimalDigits: 0, locale: 'bn_BD');

  double get _total => _cart.fold(0, (s, e) => s + e.totalPrice);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().fetchSuppliers();
      context.read<InventoryProvider>().fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন ক্রয়')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSupplierSelector(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(_invoiceCtrl, 'চালান নম্বর (অপশনাল)', Icons.receipt_outlined)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('পণ্য তালিকা', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _showAddItemSheet,
                          icon: const Icon(Icons.add, color: AppColors.primary),
                          label: const Text('পণ্য যোগ করুন', style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_cart.isEmpty)
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        opacity: 0.05,
                        child: const Center(
                          child: Text('পণ্য যোগ করুন', style: TextStyle(color: Colors.white38)),
                        ),
                      )
                    else
                      ..._cart.asMap().entries.map((entry) => _buildCartItem(entry.key, entry.value)),
                    const SizedBox(height: 14),
                    _buildTextField(_noteCtrl, 'নোট (অপশনাল)', Icons.note_outlined),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSelector() {
    final suppliers = context.watch<SupplierProvider>().suppliers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('সরবরাহকারী (অপশনাল)', style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          opacity: 0.08,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Supplier?>(
              value: _selectedSupplier,
              isExpanded: true,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('নগদ ক্রয় (সরবরাহকারী ছাড়া)'),
              ),
              dropdownColor: AppColors.surface,
              items: [
                const DropdownMenuItem<Supplier?>(
                    value: null,
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('নগদ ক্রয়'))),
                ...suppliers.map((s) => DropdownMenuItem<Supplier?>(
                    value: s,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(s.name)))),
              ],
              onChanged: (v) => setState(() => _selectedSupplier = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark(),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        opacity: 0.08,
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(DateFormat('dd MMM yyyy').format(_date),
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon) {
    return GlassCard(
      padding: EdgeInsets.zero,
      opacity: 0.08,
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCartItem(int index, _CartItem item) {
    return Padding(
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
                  Text(item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${item.quantity} ${item.product.unit} × ${_format.format(item.buyPrice)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Text(_format.format(item.totalPrice),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.error, size: 18),
              onPressed: () => setState(() => _cart.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('মোট:', style: TextStyle(fontSize: 16)),
              Text(_format.format(_total),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _paidCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'পরিশোধিত পরিমাণ (৳)',
              prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.background.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ক্রয় সংরক্ষণ করুন',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemSheet() {
    final products = context.read<InventoryProvider>().products;
    Product? selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('পণ্য যোগ করুন',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonHideUnderline(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<Product>(
                      value: selectedProduct,
                      isExpanded: true,
                      hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text('পণ্য নির্বাচন করুন')),
                      dropdownColor: AppColors.surface,
                      items: products
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(p.name))))
                          .toList(),
                      onChanged: (p) {
                        setSheet(() {
                          selectedProduct = p;
                          if (p != null) priceCtrl.text = p.buyPrice.toString();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'পরিমাণ',
                          filled: true,
                          fillColor: AppColors.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'ক্রয় মূল্য (৳)',
                          filled: true,
                          fillColor: AppColors.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedProduct == null) return;
                      final qty = double.tryParse(qtyCtrl.text) ?? 0;
                      final price = double.tryParse(priceCtrl.text) ?? 0;
                      if (qty <= 0 || price <= 0) return;
                      setState(() {
                        _cart.add(_CartItem(
                          product: selectedProduct!,
                          quantity: qty,
                          buyPrice: price,
                        ));
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('যোগ করুন'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('কমপক্ষে একটি পণ্য যোগ করুন'), backgroundColor: AppColors.error));
      return;
    }
    final paid = double.tryParse(_paidCtrl.text) ?? 0;
    final now = DateTime.now();
    final purchase = Purchase(
      supplierId: _selectedSupplier?.id,
      invoiceNo: _invoiceCtrl.text.trim().isEmpty ? null : _invoiceCtrl.text.trim(),
      totalAmount: _total,
      paidAmount: paid.clamp(0, _total),
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: now,
    );
    final items = _cart
        .map((c) => PurchaseItem(
              purchaseId: 0,
              productId: c.product.id!,
              quantity: c.quantity,
              buyPrice: c.buyPrice,
              totalPrice: c.totalPrice,
            ))
        .toList();

    await context.read<PurchaseProvider>().addPurchase(purchase, items);
    await context.read<InventoryProvider>().fetchProducts();
    if (!mounted) return;
    context.read<DashboardProvider>().fetchStats();
    Navigator.pop(context);
  }
}

class _CartItem {
  final Product product;
  final double quantity;
  final double buyPrice;
  double get totalPrice => quantity * buyPrice;

  _CartItem({required this.product, required this.quantity, required this.buyPrice});
}
