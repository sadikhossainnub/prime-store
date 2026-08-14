import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/import_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ImportProductsScreen extends StatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends State<ImportProductsScreen>
    with SingleTickerProviderStateMixin {
  // Category state
  ImportCategory _selectedCategory = ImportCategory.product;

  // States
  bool _isPicking = false;
  bool _isParsing = false;
  bool _isImporting = false;
  String? _fileName;
  PlatformFile? _pickedFile;
  String? _errorMessage;
  List<ParsedItem> _items = [];
  ImportResult? _result;

  // Field Mapping State
  List<String> _fileHeaders = [];
  Map<String, String?> _fieldMapping = {};
  bool _showFieldMapping = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
      _items = [];
      _result = null;
      _fileName = null;
      _pickedFile = null;
      _fileHeaders = [];
      _fieldMapping = {};
      _showFieldMapping = false;
    });

    try {
      final file = await ImportService.pickFile();
      if (file == null) {
        setState(() => _isPicking = false);
        return;
      }

      _pickedFile = file;
      _fileName = file.name;
      _fileHeaders = await ImportService.extractHeaders(file);
      _fieldMapping = ImportService.autoMatchFields(_selectedCategory, _fileHeaders);

      setState(() {
        _isPicking = false;
        _showFieldMapping = _fileHeaders.isNotEmpty;
      });

      await _processFile();
    } catch (e) {
      setState(() {
        _isPicking = false;
        _isParsing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _processFile() async {
    if (_pickedFile == null) return;
    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _items = [];
      _result = null;
    });

    try {
      final parsed = await ImportService.parseFile(
        _pickedFile!,
        _selectedCategory,
        customMapping: _fieldMapping,
      );
      setState(() {
        _isParsing = false;
        _items = parsed;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _isParsing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _importData() async {
    final selectedCount = _items.where((p) => p.selected).length;
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('কোনো আইটেম নির্বাচন করা হয়নি'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${_selectedCategory.label} ইমপোর্ট করবেন?'),
        content: Text('$selectedCount টি ${_selectedCategory.label} ডেটাবেসে যোগ করা হবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('ইমপোর্ট করুন'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isImporting = true);
    final result = await ImportService.importData(_items, _selectedCategory);
    setState(() {
      _isImporting = false;
      _result = result;
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final p in _items) {
        p.selected = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('পণ্য ও ক্যাটালগ ইমপোর্ট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.accent),
            tooltip: 'ফরম্যাট গাইড',
            onPressed: _showFormatGuide,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _result != null ? _buildResultView() : _buildMainView(),
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        // Category Selector Chips
        _buildCategorySelector(),

        // File picker area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildFilePickerCard(),
        ),

        // Interactive Field Mapping Section
        if (_showFieldMapping && _fileHeaders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildFieldMappingAccordion(),
          ),

        // Error message
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              opacity: 0.08,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Parsed items info bar
        if (_items.isNotEmpty) _buildInfoBar(),

        // Items list
        if (_items.isNotEmpty)
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildItemsList(),
            ),
          ),

        // Empty state - format instructions
        if (_items.isEmpty && _errorMessage == null && !_isParsing)
          Expanded(child: _buildEmptyState()),

        // Import button
        if (_items.isNotEmpty && _result == null)
          _buildImportButton(),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: ImportCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                cat.icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.white60,
              ),
              label: Text(cat.label),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.white12,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              onSelected: (selected) {
                if (selected && _selectedCategory != cat) {
                  setState(() {
                    _selectedCategory = cat;
                    if (_fileHeaders.isNotEmpty) {
                      _fieldMapping = ImportService.autoMatchFields(cat, _fileHeaders);
                    }
                  });
                  if (_pickedFile != null) {
                    _processFile();
                  }
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilePickerCard() {
    return GestureDetector(
      onTap: (_isPicking || _isParsing || _isImporting) ? null : _pickFile,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        opacity: 0.06,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _fileName != null ? AppColors.primary.withValues(alpha: 0.5) : Colors.white12,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            children: [
              if (_isPicking || _isParsing)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _fileName != null
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _fileName != null ? Icons.description_rounded : Icons.upload_file_rounded,
                    color: _fileName != null ? AppColors.primary : Colors.white54,
                    size: 24,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _isParsing
                    ? 'ফাইল পার্স করা হচ্ছে...'
                    : _isPicking
                        ? 'ফাইল খোঁজা হচ্ছে...'
                        : _fileName ?? '${_selectedCategory.label} এর Excel বা CSV ফাইল নির্বাচন করুন',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _fileName != null ? FontWeight.bold : FontWeight.normal,
                  color: _fileName != null ? Colors.white : Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              if (_fileName == null && !_isPicking && !_isParsing)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '.xlsx, .xls, .csv ফরম্যাট সাপোর্টেড',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
              if (_fileName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_items.length} টি ${_selectedCategory.label} পাওয়া গেছে • অন্য ফাইল বেছে নিতে ট্যাপ করুন',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldMappingAccordion() {
    final fields = ImportService.getFieldsForCategory(_selectedCategory);

    return ExpansionTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.surface.withValues(alpha: 0.8),
      collapsedBackgroundColor: Colors.white.withValues(alpha: 0.05),
      leading: const Icon(Icons.alt_route_rounded, color: AppColors.accent, size: 20),
      title: const Text(
        'কলাম ফিল্ড ম্যাপিং (Field Mapping)',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        ...fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Text(
                          f.label,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        if (f.isRequired)
                          const Text(' *', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _fieldMapping[f.key] != null ? AppColors.primary.withValues(alpha: 0.5) : Colors.white12,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _fileHeaders.contains(_fieldMapping[f.key]) ? _fieldMapping[f.key] : null,
                          hint: const Text('-- স্কিপ করুন --', style: TextStyle(fontSize: 11, color: Colors.white38)),
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('-- স্কিপ করুন --', style: TextStyle(color: Colors.white38)),
                            ),
                            ..._fileHeaders.map((h) => DropdownMenuItem<String?>(
                                  value: h,
                                  child: Text(h, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _fieldMapping[f.key] = val;
                            });
                            _processFile();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildInfoBar() {
    final selectedCount = _items.where((p) => p.selected).length;
    final allSelected = selectedCount == _items.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleAll(!allSelected),
            child: Row(
              children: [
                Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  allSelected ? 'সব বাদ দিন' : 'সব নির্বাচন করুন',
                  style: const TextStyle(fontSize: 13, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$selectedCount / ${_items.length} নির্বাচিত',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: EdgeInsets.zero,
            opacity: item.selected ? 0.06 : 0.02,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: GestureDetector(
                onTap: () => setState(() => item.selected = !item.selected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.selected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.selected ? AppColors.primary : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: item.selected
                      ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
                      : null,
                ),
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: item.selected ? Colors.white : Colors.white38,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              trailing: item.detail != null
                  ? Text(
                      item.detail!,
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportButton() {
    final selectedCount = _items.where((p) => p.selected).length;
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: (_isImporting || selectedCount == 0) ? null : _importData,
          icon: _isImporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded),
          label: Text(
            _isImporting
                ? 'ইমপোর্ট হচ্ছে...'
                : '$selectedCount টি ${_selectedCategory.label} ইমপোর্ট করুন',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_selectedCategory.icon, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Excel / CSV থেকে ${_selectedCategory.label} ইমপোর্ট করুন',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'আপনার ফাইলে প্রথম সারিতে নিচের কলামগুলো থাকতে পারে:',
                style: TextStyle(fontSize: 12, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ..._getGuideRowsForCategory(_selectedCategory),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _getGuideRowsForCategory(ImportCategory cat) {
    final fields = ImportService.getFieldsForCategory(cat);
    return fields.map((f) => _formatRow(f.label, f.isRequired ? 'আবশ্যক' : 'ঐচ্ছিক', f.isRequired)).toList();
  }

  Widget _formatRow(String name, String tag, bool required) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            required ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: required ? AppColors.primary : Colors.white24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: required
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                color: required ? AppColors.primary : Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;
    final isSuccess = result.successCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isSuccess ? AppColors.primary : AppColors.error).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isSuccess ? AppColors.primary : AppColors.error,
                size: 46,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSuccess ? 'ইমপোর্ট সফল হয়েছে!' : 'ইমপোর্ট ব্যর্থ হয়েছে',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            GlassCard(
              padding: const EdgeInsets.all(16),
              opacity: 0.06,
              child: Column(
                children: [
                  _statRow('মোট ডেটা', '${result.totalRows} টি', Icons.list_rounded),
                  const Divider(color: Colors.white12, height: 16),
                  _statRow('সফল', '${result.successCount} টি', Icons.check_circle_outline,
                      color: AppColors.primary),
                  if (result.skipCount > 0) ...[
                    const Divider(color: Colors.white12, height: 16),
                    _statRow('ব্যর্থ/স্কিপ', '${result.skipCount} টি', Icons.cancel_outlined,
                        color: AppColors.error),
                  ],
                ],
              ),
            ),

            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(12),
                opacity: 0.05,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                        SizedBox(width: 8),
                        Text('ত্রুটি বিবরণ:', style: TextStyle(fontSize: 13, color: AppColors.warning)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...result.errors.take(4).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $e', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        )),
                    if (result.errors.length > 4)
                      Text(
                        '...এবং আরো ${result.errors.length - 4} টি ত্রুটি',
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _items = [];
                        _result = null;
                        _fileName = null;
                        _pickedFile = null;
                        _fileHeaders = [];
                        _fieldMapping = {};
                        _showFieldMapping = false;
                      });
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('আরো ইমপোর্ট'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('সম্পন্ন'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
      ],
    );
  }

  void _showFormatGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.85,
        initialChildSize: 0.6,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${_selectedCategory.label} ইমপোর্ট কলাম গাইড',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'ফাইলের ১ম সারিতে কলামের নাম থাকতে হবে। বাংলা ও ইংরেজি দুটোই গ্রহণযোগ্য:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ..._getDetailedGuideForCategory(_selectedCategory),
          ],
        ),
      ),
    );
  }

  List<Widget> _getDetailedGuideForCategory(ImportCategory cat) {
    final fields = ImportService.getFieldsForCategory(cat);
    return fields.map((f) => _guideRow(f.label, f.defaultKeywords.join(', '))).toList();
  }

  Widget _guideRow(String field, String aliases) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(field, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const Text('→ ', style: TextStyle(color: AppColors.primary, fontSize: 12)),
          Expanded(
            child: Text(aliases, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
