import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _barcodeController = TextEditingController();
  String _selectedUnit = 'pcs';
  String? _photoPath;

  final List<String> _units = ['pcs', 'kg', 'liter', 'dozen', 'bag', 'box', 'packet', 'gram'];
  final List<String> _categories = [
    'চাল', 'ডাল', 'তেল', 'মশলা', 'আটা', 'চিনি', 'লবণ', 'সাবান', 'পানীয়', 'অন্যান্য'
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
      _barcodeController.text = p.barcode ?? '';
      _selectedUnit = p.unit;
      _photoPath = p.photoPath;
    } else {
      _minStockController.text = '5';
      _stockController.text = '0';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomCategoriesAndUnits();
    });
  }

  Future<void> _loadCustomCategoriesAndUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final customCats = prefs.getStringList('custom_categories') ?? [];
    final customUnits = prefs.getStringList('custom_units') ?? [];

    final provider = context.read<InventoryProvider>();
    final dbProducts = provider.products;

    final dbCats = dbProducts.map((p) => p.category).whereType<String>().toList();
    final dbUnits = dbProducts.map((p) => p.unit).toList();

    setState(() {
      for (final cat in [...customCats, ...dbCats]) {
        if (cat.trim().isNotEmpty && !_categories.contains(cat.trim())) {
          _categories.add(cat.trim());
        }
      }
      for (final unit in [...customUnits, ...dbUnits]) {
        if (unit.trim().isNotEmpty && !_units.contains(unit.trim())) {
          _units.add(unit.trim());
        }
      }
      if (_isEdit && widget.product != null) {
        if (widget.product!.category != null && !_categories.contains(widget.product!.category)) {
          _categories.add(widget.product!.category!);
        }
        if (!_units.contains(widget.product!.unit)) {
          _units.add(widget.product!.unit);
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  // ─── Photo Picker ──────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _photoPath = picked.path);
      await _scanPhotoText(picked.path);
    }
  }

  Future<void> _scanPhotoText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.trim().isEmpty) return;

      final lines = recognizedText.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.length >= 2)
          .toList();

      if (lines.isEmpty) return;

      bool detectedName = false;
      bool detectedCategory = false;
      bool detectedUnit = false;

      // 1. Auto-fill Product Name if name field is empty
      if (_nameController.text.trim().isEmpty) {
        String candidate = lines.first;
        for (final l in lines) {
          if (l.length > candidate.length && !RegExp(r'^\d+$').hasMatch(l)) {
            candidate = l;
          }
        }
        candidate = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9\sঅ-ঔক-হা-ৌ্যংঃঁ]'), ' ').trim();
        if (candidate.isNotEmpty) {
          _nameController.text = candidate;
          detectedName = true;
        }
      }

      final fullText = recognizedText.text.toLowerCase();

      // 2. Auto-detect Category if empty
      if (_categoryController.text.trim().isEmpty) {
        final catMap = {
          'চাল': ['rice', 'miniket', 'najirshail', 'চাল', 'চাউল'],
          'ডাল': ['dal', 'lentil', 'moog', 'masoor', 'ডাল'],
          'তেল': ['oil', 'soyabean', 'mustard', 'sunflower', 'তেল'],
          'মশলা': ['spice', 'masala', 'turmeric', 'chilli', 'cumin', 'coriander', 'মশলা'],
          'আটা': ['flour', 'atta', 'maida', 'suji', 'আটা', 'ময়দা'],
          'চিনি': ['sugar', 'চিনি'],
          'লবণ': ['salt', 'লবণ', 'লবন'],
          'সাবান': ['soap', 'lux', 'dettol', 'lifebuoy', 'rin', 'wheel', 'surf', 'vim', 'savlon', 'সাবান'],
          'পানীয়': ['drink', 'cola', 'pepsi', '7up', 'sprite', 'water', 'juice', 'mojo', 'clemon', 'পানীয়'],
        };

        for (final entry in catMap.entries) {
          if (entry.value.any((k) => fullText.contains(k))) {
            _categoryController.text = entry.key;
            if (!_categories.contains(entry.key)) {
              _categories.add(entry.key);
            }
            detectedCategory = true;
            break;
          }
        }
      }

      // 3. Auto-detect Unit
      if (fullText.contains('kg') || fullText.contains('কেজি') || fullText.contains('kilo')) {
        _selectedUnit = 'kg';
        detectedUnit = true;
      } else if (fullText.contains('liter') || fullText.contains('litre') || fullText.contains('লিটার') || fullText.contains('ltr')) {
        _selectedUnit = 'liter';
        detectedUnit = true;
      } else if (fullText.contains('gm') || fullText.contains('gram') || fullText.contains('গ্রাম')) {
        _selectedUnit = 'gram';
        detectedUnit = true;
      }

      setState(() {});

      if (mounted && (detectedName || detectedCategory || detectedUnit)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ ফটো থেকে পণ্যের নাম ও তথ্য সংগৃহীত হয়েছে!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      // Ignore OCR errors silently
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ফটো যোগ করুন',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageSourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'ক্যামেরা',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _imageSourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'গ্যালারি',
                  color: AppColors.secondary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_photoPath != null)
                  _imageSourceButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'মুছুন',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _photoPath = null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ─── Barcode Scanner ──────────────────────────────────────────────────

  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('বারকোড স্ক্যান করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        setState(() => _barcodeController.text = code);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('বারকোড স্ক্যান হয়েছে: $code'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
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

  // ─── Build ─────────────────────────────────────────────────────────────

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
              // ─ Product Photo ─
              _buildPhotoSection(),
              const SizedBox(height: 20),

              // ─ Name ─
              _field('পণ্যের নাম *', _nameController, hint: 'যেমন: মিনিকেট চাল'),
              const SizedBox(height: 14),

              // ─ Category ─
              _buildCategoryField(),
              const SizedBox(height: 14),

              // ─ Barcode ─
              _buildBarcodeField(),
              const SizedBox(height: 14),

              // ─ Unit ─
              _buildUnitSelector(),
              const SizedBox(height: 14),

              // ─ Prices ─
              Row(
                children: [
                  Expanded(child: _field('ক্রয় মূল্য (৳)', _buyPriceController, hint: '0', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('বিক্রয় মূল্য (৳)', _sellPriceController, hint: '0', isNumber: true)),
                ],
              ),
              const SizedBox(height: 14),

              // ─ Stock ─
              Row(
                children: [
                  Expanded(child: _field('বর্তমান স্টক', _stockController, hint: '0', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('সর্বনিম্ন স্টক সতর্কতা', _minStockController, hint: '5', isNumber: true)),
                ],
              ),
              const SizedBox(height: 32),

              // ─ Save Button ─
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: Icon(_isEdit ? Icons.check : Icons.save_rounded),
                  label: Text(
                    _isEdit ? 'আপডেট করুন' : 'সংরক্ষণ করুন',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Photo Section ─────────────────────────────────────────────────────

  Widget _buildPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _showImageSourceSheet,
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _photoPath != null ? AppColors.primary : Colors.white24,
              width: 2,
            ),
          ),
          child: _photoPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(_photoPath!),
                    fit: BoxFit.cover,
                    width: 130,
                    height: 130,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      size: 40,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'পণ্যের ফটো',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Barcode Field ─────────────────────────────────────────────────────

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('বারকোড (ঐচ্ছিক)', style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          opacity: 0.08,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'বারকোড নম্বর',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.accent),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                tooltip: 'বারকোড স্ক্যান করুন',
                onPressed: _openBarcodeScanner,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Helper Widgets ────────────────────────────────────────────────────

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
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
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

  void _showAddCategoryDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('নতুন ক্যাটাগরি যোগ করুন'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'যেমন: স্ন্যাক্স, কসমেটিকস...',
            prefixIcon: Icon(Icons.add_box_rounded, color: AppColors.accent),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                if (!_categories.contains(val)) {
                  setState(() {
                    _categories.add(val);
                    _categoryController.text = val;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  final saved = prefs.getStringList('custom_categories') ?? [];
                  if (!saved.contains(val)) {
                    saved.add(val);
                    await prefs.setStringList('custom_categories', saved);
                  }
                } else {
                  setState(() => _categoryController.text = val);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }

  void _showAddUnitDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.straighten_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('নতুন একক (Unit) যোগ করুন'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'যেমন: হালি, বস্তা, গজ, মিটার...',
            prefixIcon: Icon(Icons.add_box_rounded, color: AppColors.accent),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                if (!_units.contains(val)) {
                  setState(() {
                    _units.add(val);
                    _selectedUnit = val;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  final saved = prefs.getStringList('custom_units') ?? [];
                  if (!saved.contains(val)) {
                    saved.add(val);
                    await prefs.setStringList('custom_units', saved);
                  }
                } else {
                  setState(() => _selectedUnit = val);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ক্যাটাগরি', style: TextStyle(fontSize: 14, color: Colors.white70)),
            GestureDetector(
              onTap: _showAddCategoryDialog,
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('নতুন ক্যাটাগরি', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
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
              items: [
                ..._categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(c)))),
                const DropdownMenuItem(
                  value: '__ADD_NEW__',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.add, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('+ নতুন ক্যাটাগরি যোগ করুন', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == '__ADD_NEW__') {
                  _showAddCategoryDialog();
                } else {
                  setState(() => _categoryController.text = v ?? '');
                }
              },
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('একক (Unit)', style: TextStyle(fontSize: 14, color: Colors.white70)),
            GestureDetector(
              onTap: _showAddUnitDialog,
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('নতুন একক', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._units.map((unit) {
              final selected = _selectedUnit == unit;
              return GestureDetector(
                onTap: () => setState(() => _selectedUnit = unit),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: _showAddUnitDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'নতুন একক',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Save ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('পণ্যের নাম আবশ্যক'), backgroundColor: AppColors.error),
      );
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
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      photoPath: _photoPath,
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
