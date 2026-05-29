import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;
  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  String _selectedUnit = 'pcs';

  final List<String> _units = ['pcs', 'kg', 'liter', 'dozen', 'bag', 'box', 'packet'];
  final List<String> _categories = [
    'চাল', 'ডাল', 'তেল', 'মশলা', 'আটা', 'চিনি', 'লবণ', 'সাবান', 'অন্যান্য'
  ];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      _nameController.text = p.name;
      _categoryController.text = p.category ?? '';
      _buyPriceController.text = p.buyPrice.toString();
      _sellPriceController.text = p.sellPrice.toString();
      _stockController.text = p.currentStock.toString();
      _minStockController.text = p.minStockAlert.toString();
      _selectedUnit = p.unit;
    } else {
      _minStockController.text = '5';
      _stockController.text = '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'পণ্য সম্পাদনা' : 'নতুন পণ্য যোগ করুন')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('পণ্যের নাম *', _nameController, hint: 'যেমন: মিনিকেট চাল'),
              const SizedBox(height: 14),
              _buildCategoryField(),
              const SizedBox(height: 14),
              _buildUnitSelector(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field('ক্রয় মূল্য (৳)', _buyPriceController,
                      hint: '0', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('বিক্রয় মূল্য (৳)', _sellPriceController,
                      hint: '0', isNumber: true)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field('বর্তমান স্টক', _stockController,
                      hint: '0', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('সর্বনিম্ন স্টক সতর্কতা', _minStockController,
                      hint: '5', isNumber: true)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: Icon(_isEdit ? Icons.check : Icons.save),
                  label: Text(_isEdit ? 'আপডেট করুন' : 'সংরক্ষণ করুন',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          opacity: 0.08,
          child: TextField(
            controller: ctrl,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ক্যাটাগরি', style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          opacity: 0.08,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _categories.contains(_categoryController.text)
                  ? _categoryController.text
                  : null,
              isExpanded: true,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('ক্যাটাগরি নির্বাচন করুন'),
              ),
              dropdownColor: AppColors.surface,
              items: _categories
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(c))))
                  .toList(),
              onChanged: (v) => setState(() => _categoryController.text = v ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('একক (Unit)', style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _units.map((unit) {
            final selected = _selectedUnit == unit;
            return GestureDetector(
              onTap: () => setState(() => _selectedUnit = unit),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(unit,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('পণ্যের নাম আবশ্যক'), backgroundColor: AppColors.error));
      return;
    }

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      unit: _selectedUnit,
      buyPrice: double.tryParse(_buyPriceController.text) ?? 0,
      sellPrice: double.tryParse(_sellPriceController.text) ?? 0,
      currentStock: double.tryParse(_stockController.text) ?? 0,
      minStockAlert: double.tryParse(_minStockController.text) ?? 5,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<InventoryProvider>();
    if (_isEdit) {
      await provider.updateProduct(product);
    } else {
      await provider.addProduct(product);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}
