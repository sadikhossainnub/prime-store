import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/data_import_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  File? _selectedFile;
  String? _fileName;
  String? _fileExtension;
  String _selectedCsvTable = 'customers'; // 'customers', 'transactions', 'payments'
  bool _isImporting = false;
  bool _isLoadingHeaders = false;
  ImportResult? _lastResult;

  // Extracted headers
  List<String> _csvHeaders = [];
  Map<String, List<String>> _excelHeaders = {}; // SheetName -> List of Header strings

  // Field mappings: dbKey -> mappedHeaderName
  Map<String, String?> _csvFieldMapping = {};
  Map<String, Map<String, String?>> _excelFieldMappings = {}; // SheetName -> dbKey -> mappedHeaderName

  final Map<String, String> _csvTableLabels = {
    'customers': 'কাস্টমার তালিকা (Customers)',
    'transactions': 'বাকি হিসাব (Transactions)',
    'payments': 'জমা / পেমেন্ট (Payments)',
  };

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        final path = file.path!;
        final ext = file.extension?.toLowerCase();

        setState(() {
          _selectedFile = File(path);
          _fileName = file.name;
          _fileExtension = ext;
          _lastResult = null;
          _isLoadingHeaders = true;
        });

        await _extractHeadersAndAutoMatch();
      }
    }
  }

  Future<void> _extractHeadersAndAutoMatch() async {
    if (_selectedFile == null) return;

    try {
      if (_fileExtension == 'csv') {
        final headers = await DataImportService.extractCsvHeaders(_selectedFile!);
        final mapping = DataImportService.autoMatchFields(_selectedCsvTable, headers);
        setState(() {
          _csvHeaders = headers;
          _csvFieldMapping = mapping;
          _isLoadingHeaders = false;
        });
      } else {
        final sheetHeadersMap = await DataImportService.extractExcelHeaders(_selectedFile!);
        final excelMappings = <String, Map<String, String?>>{};

        for (final entry in sheetHeadersMap.entries) {
          final sheetName = entry.key;
          final headers = entry.value;
          final tableType = sheetName.toLowerCase().trim();
          final mapping = DataImportService.autoMatchFields(tableType, headers);
          excelMappings[sheetName] = mapping;
        }

        setState(() {
          _excelHeaders = sheetHeadersMap;
          _excelFieldMappings = excelMappings;
          _isLoadingHeaders = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingHeaders = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('হেডার পড়া ব্যর্থ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _startImport() async {
    if (_selectedFile == null) return;

    // Validate required field mappings
    if (_fileExtension == 'csv') {
      final fields = DataImportService.getFieldsForTable(_selectedCsvTable);
      for (final f in fields) {
        if (f.isRequired && (_csvFieldMapping[f.dbKey] == null || _csvFieldMapping[f.dbKey]!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('মেপিং ভুল: "${f.label}" কলাম নির্বাচন করা হয়নি!'),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }
      }
    }

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('ডেটা ইমপোর্ট নিশ্চিতকরণ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'নির্বাচন করা ফাইল ও কলাম ম্যাপিং অনুযায়ী ডেটাবেসে ইমপোর্ট করা হবে।\n\n'
              '• ডুপ্লিকেট কাস্টমার মার্জ হবে\n'
              '• কোনো ডেটা মুছে যাবে না\n'
              '• আইডি ম্যাপিং ও ফরেন কি বজায় থাকবে',
              style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'ফাইল: $_fileName',
              style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('ইমপোর্ট শুরু করুন'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isImporting = true);

    try {
      ImportResult result;
      if (_fileExtension == 'csv') {
        result = await DataImportService.importFromCsv(
          _selectedFile!,
          _selectedCsvTable,
          customMapping: _csvFieldMapping,
        );
      } else {
        result = await DataImportService.importFromExcel(
          _selectedFile!,
          customMappings: _excelFieldMappings,
        );
      }

      if (mounted) {
        context.read<DashboardProvider>().fetchStats();
        setState(() {
          _isImporting = false;
          _lastResult = result;
        });
        _showSummaryDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showSummaryDialog(ImportResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('ইমপোর্ট ফলাফল'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('কাস্টমার ইমপোর্ট:', '${result.customersImported} জন'),
              _summaryRow('কাস্টমার মার্জ (ডুপ্লিকেট):', '${result.customersMerged} জন'),
              const Divider(color: Colors.white12),
              _summaryRow('বাকি লেনদেন ইমপোর্ট:', '${result.transactionsImported} টি'),
              _summaryRow('বাকি স্কিপড (ডুপ্লিকেট/ত্রুটি):', '${result.transactionsSkipped} টি'),
              const Divider(color: Colors.white12),
              _summaryRow('পেমেন্ট ইমপোর্ট:', '${result.paymentsImported} টি'),
              _summaryRow('পেমেন্ট স্কিপড (ডুপ্লিকেট/ত্রুটি):', '${result.paymentsSkipped} টি'),
              if (result.skippedLogs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('ত্রুটি ও স্কিপড লগ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning)),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      result.skippedLogs.join('\n'),
                      style: const TextStyle(fontSize: 11, color: Colors.white60, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('ইমপোর্ট ব্যর্থ হয়েছে'),
          ],
        ),
        content: Text(
          'ত্রুটি বিবরণ: $error\n\nকোনো ডেটা পরিবর্তন হয়নি (Transaction Rolled Back)।',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বন্ধ করুন', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ডেটা ব্যাকআপ ইমপোর্ট'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info banner
            GlassCard(
              padding: const EdgeInsets.all(16),
              opacity: 0.06,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.dataset_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excel / CSV ব্যাকআপ রিস্টোর',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'পুরাতন ব্যাকআপ ফাইল নির্বাচন করুন ও ফিল্ড ম্যাপিং কাস্টমাইজ করে ডেটা যোগ করুন।',
                          style: TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('১. ফাইল নির্বাচন করুন', style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            // File selection card
            GestureDetector(
              onTap: _isImporting ? null : _pickFile,
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                opacity: 0.06,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFile != null ? AppColors.primary : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null ? Icons.description_rounded : Icons.upload_file_rounded,
                        color: _selectedFile != null ? AppColors.primary : Colors.white38,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fileName ?? 'ফাইল নির্বাচন করতে ট্যাপ করুন',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _selectedFile != null ? FontWeight.bold : FontWeight.normal,
                          color: _selectedFile != null ? Colors.white : Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedFile != null
                            ? 'ফরম্যাট: ${_fileExtension?.toUpperCase()}'
                            : 'সাপোর্টেড ফরম্যাট: .xlsx, .csv',
                        style: const TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // CSV Table type selection
            if (_fileExtension == 'csv') ...[
              const SizedBox(height: 20),
              const Text('২. CSV টেবিল প্রকার বেছে নিন:', style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                opacity: 0.06,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCsvTable,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: _csvTableLabels.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCsvTable = val);
                        if (_selectedFile != null) _extractHeadersAndAutoMatch();
                      }
                    },
                  ),
                ),
              ),
            ],

            // Field Mapping UI Section
            if (_selectedFile != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.alt_route_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    _fileExtension == 'csv' ? '২. কলাম ফিল্ড ম্যাপিং (Field Mapping)' : '২. কলাম ফিল্ড ম্যাপিং (Field Mapping)',
                    style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoadingHeaders)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_fileExtension == 'csv')
                _buildCsvFieldMappingCard()
              else
                _buildExcelFieldMappingCard(),
            ],

            const SizedBox(height: 32),

            // Start import button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_selectedFile == null || _isImporting || _isLoadingHeaders) ? null : _startImport,
                icon: _isImporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  _isImporting ? 'ইমপোর্ট প্রসেসিং হচ্ছে...' : 'ইমপোর্ট শুরু করুন',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            // Show last result summary if available
            if (_lastResult != null) ...[
              const SizedBox(height: 24),
              const Text('সর্বশেষ ইমপোর্ট ফলাফল', style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(16),
                opacity: 0.06,
                child: Column(
                  children: [
                    _summaryRow('কাস্টমার ইমপোর্ট:', '${_lastResult!.customersImported}'),
                    _summaryRow('কাস্টমার মার্জ:', '${_lastResult!.customersMerged}'),
                    _summaryRow('বাকি ইমপোর্ট:', '${_lastResult!.transactionsImported}'),
                    _summaryRow('বাকি স্কিপড:', '${_lastResult!.transactionsSkipped}'),
                    _summaryRow('পেমেন্ট ইমপোর্ট:', '${_lastResult!.paymentsImported}'),
                    _summaryRow('পেমেন্ট স্কিপড:', '${_lastResult!.paymentsSkipped}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCsvFieldMappingCard() {
    final fields = DataImportService.getFieldsForTable(_selectedCsvTable);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      opacity: 0.06,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ফাইলের কলামের সাথে ডেটাবেস ফিল্ড মেলাুন:',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          ...fields.map((f) => _buildFieldDropdownRow(
                field: f,
                selectedHeader: _csvFieldMapping[f.dbKey],
                availableHeaders: _csvHeaders,
                onChanged: (val) {
                  setState(() {
                    _csvFieldMapping[f.dbKey] = val;
                  });
                },
              )),
        ],
      ),
    );
  }

  Widget _buildExcelFieldMappingCard() {
    if (_excelHeaders.isEmpty) {
      return const GlassCard(
        padding: EdgeInsets.all(16),
        opacity: 0.06,
        child: Text('কোনো শীট পাওয়া যায়নি।', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: _excelHeaders.entries.map((entry) {
        final sheetName = entry.key;
        final headers = entry.value;
        final fields = DataImportService.getFieldsForTable(sheetName);
        final sheetMapping = _excelFieldMappings[sheetName] ?? {};

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            opacity: 0.06,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'শীট: $sheetName',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...fields.map((f) => _buildFieldDropdownRow(
                      field: f,
                      selectedHeader: sheetMapping[f.dbKey],
                      availableHeaders: headers,
                      onChanged: (val) {
                        setState(() {
                          if (_excelFieldMappings[sheetName] == null) {
                            _excelFieldMappings[sheetName] = {};
                          }
                          _excelFieldMappings[sheetName]![f.dbKey] = val;
                        });
                      },
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFieldDropdownRow({
    required FieldDefinition field,
    required String? selectedHeader,
    required List<String> availableHeaders,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Text(
                  field.label,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                if (field.isRequired)
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
                  color: selectedHeader != null ? AppColors.primary.withValues(alpha: 0.5) : Colors.white12,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: availableHeaders.contains(selectedHeader) ? selectedHeader : null,
                  hint: const Text('-- স্কিপ করুন --', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('-- স্কিপ করুন --', style: TextStyle(color: Colors.white38)),
                    ),
                    ...availableHeaders.map((h) => DropdownMenuItem<String?>(
                          value: h,
                          child: Text(h, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
