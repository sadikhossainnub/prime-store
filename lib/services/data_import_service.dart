import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class FieldDefinition {
  final String dbKey;
  final String label;
  final bool isRequired;
  final List<String> defaultKeywords;

  const FieldDefinition({
    required this.dbKey,
    required this.label,
    this.isRequired = false,
    this.defaultKeywords = const [],
  });
}

class ImportResult {
  int customersImported;
  int customersMerged;
  int transactionsImported;
  int transactionsSkipped;
  int paymentsImported;
  int paymentsSkipped;
  List<String> skippedLogs;

  ImportResult({
    this.customersImported = 0,
    this.customersMerged = 0,
    this.transactionsImported = 0,
    this.transactionsSkipped = 0,
    this.paymentsImported = 0,
    this.paymentsSkipped = 0,
    List<String>? skippedLogs,
  }) : skippedLogs = skippedLogs ?? [];

  int get totalImported => customersImported + transactionsImported + paymentsImported;
  int get totalSkipped => transactionsSkipped + paymentsSkipped + skippedLogs.length;
}

class DataImportService {
  // Table Field Definitions
  static const customerFields = [
    FieldDefinition(dbKey: 'id', label: 'পুরাতন কাস্টমার আইডি (Old ID)', isRequired: false, defaultKeywords: ['id', 'customer_id', 'cust_id']),
    FieldDefinition(dbKey: 'name', label: 'কাস্টমারের নাম (Name)', isRequired: true, defaultKeywords: ['name', 'নাম', 'customer_name', 'customer']),
    FieldDefinition(dbKey: 'phone', label: 'ফোন নম্বর (Phone)', isRequired: false, defaultKeywords: ['phone', 'ফোন', 'mobile', 'মোবাইল']),
    FieldDefinition(dbKey: 'address', label: 'ঠিকানা (Address)', isRequired: false, defaultKeywords: ['address', 'ঠিকানা', 'location']),
    FieldDefinition(dbKey: 'credit_limit', label: 'ক্রেডিট সীমা (Credit Limit)', isRequired: false, defaultKeywords: ['credit_limit', 'limit', 'বাকি সীমা']),
    FieldDefinition(dbKey: 'created_at', label: 'তৈরির তারিখ (Created At)', isRequired: false, defaultKeywords: ['created_at', 'createdat', 'date', 'তারিখ']),
  ];

  static const transactionFields = [
    FieldDefinition(dbKey: 'customer_id', label: 'কাস্টমার আইডি (Customer ID)', isRequired: true, defaultKeywords: ['customer_id', 'customerid', 'cust_id', 'id']),
    FieldDefinition(dbKey: 'amount', label: 'বাকির পরিমাণ (Amount)', isRequired: true, defaultKeywords: ['amount', 'পরিমাণ', 'টাকা', 'baki']),
    FieldDefinition(dbKey: 'description', label: 'বিবরণ (Description)', isRequired: false, defaultKeywords: ['description', 'desc', 'note', 'বিবরণ', 'নোট']),
    FieldDefinition(dbKey: 'date', label: 'তারিখ (Date)', isRequired: false, defaultKeywords: ['date', 'তারিখ']),
    FieldDefinition(dbKey: 'created_at', label: 'তৈরির তারিখ (Created At)', isRequired: false, defaultKeywords: ['created_at', 'createdat']),
  ];

  static const paymentFields = [
    FieldDefinition(dbKey: 'customer_id', label: 'কাস্টমার আইডি (Customer ID)', isRequired: true, defaultKeywords: ['customer_id', 'customerid', 'cust_id', 'id']),
    FieldDefinition(dbKey: 'amount', label: 'জমার পরিমাণ (Amount)', isRequired: true, defaultKeywords: ['amount', 'পরিমাণ', 'টাকা', 'paid', 'joma']),
    FieldDefinition(dbKey: 'note', label: 'বিবরণ / নোট (Note)', isRequired: false, defaultKeywords: ['note', 'description', 'desc', 'নোট', 'বিবরণ']),
    FieldDefinition(dbKey: 'date', label: 'তারিখ (Date)', isRequired: false, defaultKeywords: ['date', 'তারিখ']),
    FieldDefinition(dbKey: 'created_at', label: 'তৈরির তারিখ (Created At)', isRequired: false, defaultKeywords: ['created_at', 'createdat']),
  ];

  static List<FieldDefinition> getFieldsForTable(String table) {
    switch (table.toLowerCase().trim()) {
      case 'customers':
      case 'customer':
        return customerFields;
      case 'transactions':
      case 'transaction':
      case 'baki':
        return transactionFields;
      case 'payments':
      case 'payment':
      case 'joma':
        return paymentFields;
      default:
        return customerFields;
    }
  }

  /// Auto-match file headers to DB fields
  static Map<String, String?> autoMatchFields(String table, List<String> fileHeaders) {
    final fields = getFieldsForTable(table);
    final map = <String, String?>{};

    for (final field in fields) {
      String? matchedHeader;
      for (final header in fileHeaders) {
        final h = header.trim().toLowerCase();
        for (final kw in field.defaultKeywords) {
          if (h == kw.toLowerCase()) {
            matchedHeader = header;
            break;
          }
        }
        if (matchedHeader != null) break;
      }
      map[field.dbKey] = matchedHeader;
    }
    return map;
  }

  /// Extract headers from a CSV file (non-blocking)
  static Future<List<String>> extractCsvHeaders(File file) async {
    final content = await file.readAsString();
    final rows = await Future.microtask(() => const CsvToListConverter(eol: '\n').convert(content));
    if (rows.isEmpty) return [];
    return rows.first.map((e) => (e?.toString() ?? '').trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Extract headers from an Excel sheet (non-blocking background isolate)
  static Future<Map<String, List<String>>> extractExcelHeaders(File file) async {
    final bytes = await file.readAsBytes();
    final excel = await compute(_parseExcelBytes, bytes);
    final result = <String, List<String>>{};

    for (final entry in excel.tables.entries) {
      if (entry.value.rows.isNotEmpty) {
        final headers = entry.value.rows.first
            .map((c) => (c?.value?.toString() ?? '').trim())
            .where((s) => s.isNotEmpty)
            .toList();
        result[entry.key] = headers;
      }
    }
    return result;
  }

  static Excel _parseExcelBytes(Uint8List bytes) {
    return Excel.decodeBytes(bytes);
  }

  static String _getCellValue(List<dynamic> row, int? colIndex) {
    if (colIndex == null || colIndex < 0 || colIndex >= row.length) return '';
    final val = row[colIndex];
    if (val == null) return '';
    if (val is Data) {
      return val.value?.toString().trim() ?? '';
    }
    return val.toString().trim();
  }

  static double? _parseDouble(String val) {
    if (val.isEmpty) return null;
    final cleaned = val.replaceAll(RegExp(r'[,৳$€£¥₹\s]'), '');
    return double.tryParse(cleaned);
  }

  static DateTime _parseDate(String val, String context, List<String> logs) {
    if (val.trim().isEmpty) {
      logs.add('$context: Date is empty, defaulted to current time');
      return DateTime.now();
    }
    final parsed = DateTime.tryParse(val.trim());
    if (parsed != null) return parsed;

    try {
      final parts = val.trim().split(RegExp(r'[-/.]'));
      if (parts.length == 3) {
        int d = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        int y = int.parse(parts[2]);
        if (y < 100) y += 2000;
        return DateTime(y, m, d);
      }
    } catch (_) {}

    logs.add('$context: Invalid date "$val", defaulted to current time');
    return DateTime.now();
  }

  /// Import from multi-sheet `.xlsx` file with optional custom field mappings (non-blocking)
  static Future<ImportResult> importFromExcel(
    File file, {
    Map<String, Map<String, String?>>? customMappings,
  }) async {
    final bytes = await file.readAsBytes();
    final excel = await compute(_parseExcelBytes, bytes);

    Sheet? customerSheet;
    Sheet? transactionSheet;
    Sheet? paymentSheet;

    String? customerSheetName;
    String? transactionSheetName;
    String? paymentSheetName;

    for (final entry in excel.tables.entries) {
      final name = entry.key.trim().toLowerCase();
      if (name == 'customers' || name == 'customer') {
        customerSheet = entry.value;
        customerSheetName = entry.key;
      } else if (name == 'transactions' || name == 'transaction' || name == 'baki') {
        transactionSheet = entry.value;
        transactionSheetName = entry.key;
      } else if (name == 'payments' || name == 'payment' || name == 'joma') {
        paymentSheet = entry.value;
        paymentSheetName = entry.key;
      }
    }

    final db = await DatabaseHelper.instance.database;
    final result = ImportResult();

    await db.transaction((txn) async {
      final oldCustomerIdToNewId = <int, int>{};

      // 1. Customers
      if (customerSheet != null && customerSheet.rows.length > 1) {
        final map = customMappings?[customerSheetName] ?? customMappings?['customers'];
        await _processCustomersSheet(customerSheet.rows, txn, result, oldCustomerIdToNewId, map);
      }

      // 2. Transactions
      if (transactionSheet != null && transactionSheet.rows.length > 1) {
        final map = customMappings?[transactionSheetName] ?? customMappings?['transactions'];
        await _processTransactionsSheet(transactionSheet.rows, txn, result, oldCustomerIdToNewId, map);
      }

      // 3. Payments
      if (paymentSheet != null && paymentSheet.rows.length > 1) {
        final map = customMappings?[paymentSheetName] ?? customMappings?['payments'];
        await _processPaymentsSheet(paymentSheet.rows, txn, result, oldCustomerIdToNewId, map);
      }
    });

    return result;
  }

  /// Import single table from `.csv` file with custom field mapping
  static Future<ImportResult> importFromCsv(
    File file,
    String tableName, {
    Map<String, String?>? customMapping,
  }) async {
    final content = await file.readAsString();
    final rows = await Future.microtask(() => const CsvToListConverter(eol: '\n').convert(content));

    if (rows.isEmpty) {
      throw Exception('ফাইলটি খালি (File is empty)');
    }

    final db = await DatabaseHelper.instance.database;
    final result = ImportResult();

    await db.transaction((txn) async {
      final oldCustomerIdToNewId = <int, int>{};

      final table = tableName.toLowerCase().trim();
      if (table == 'customers') {
        await _processCustomersSheet(rows, txn, result, oldCustomerIdToNewId, customMapping);
      } else if (table == 'transactions') {
        await _processTransactionsSheet(rows, txn, result, oldCustomerIdToNewId, customMapping);
      } else if (table == 'payments') {
        await _processPaymentsSheet(rows, txn, result, oldCustomerIdToNewId, customMapping);
      } else {
        throw Exception('অজানা টেবিল: $tableName (Unknown table name)');
      }
    });

    return result;
  }

  // --- Processing Helpers with Column Resolution ---

  static int? _getColumnIndex(List<String> headers, String? mappedHeader, List<String> fallbackKeywords) {
    if (mappedHeader != null && mappedHeader.isNotEmpty) {
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].trim().toLowerCase() == mappedHeader.trim().toLowerCase()) {
          return i;
        }
      }
    }
    // Fallback keyword search
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final kw in fallbackKeywords) {
        if (h == kw.toLowerCase()) return i;
      }
    }
    return null;
  }

  static Future<void> _processCustomersSheet(
    List<List<dynamic>> rows,
    Transaction txn,
    ImportResult result,
    Map<int, int> oldCustomerIdToNewId,
    Map<String, String?>? customMapping,
  ) async {
    if (rows.length <= 1) return;

    final headers = rows.first.map((e) => (e?.toString() ?? '').trim()).toList();

    final idCol = _getColumnIndex(headers, customMapping?['id'], ['id', 'customer_id', 'cust_id']);
    final nameCol = _getColumnIndex(headers, customMapping?['name'], ['name', 'নাম', 'customer_name', 'customer']);
    final phoneCol = _getColumnIndex(headers, customMapping?['phone'], ['phone', 'ফোন', 'mobile', 'মোবাইল']);
    final addressCol = _getColumnIndex(headers, customMapping?['address'], ['address', 'ঠিকানা']);
    final photoCol = _getColumnIndex(headers, customMapping?['photo_path'], ['photo_path', 'photo', 'ছবি']);
    final limitCol = _getColumnIndex(headers, customMapping?['credit_limit'], ['credit_limit', 'limit', 'বাকি সীমা']);
    final createdCol = _getColumnIndex(headers, customMapping?['created_at'], ['created_at', 'createdat', 'date', 'তারিখ']);

    if (nameCol == null) {
      result.skippedLogs.add('[Customers] Header "name" missing or unmapped');
      return;
    }

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = _getCellValue(row, nameCol);

      if (name.isEmpty) {
        result.skippedLogs.add('[Customers Row ${i + 1}] Skipped: Name is required');
        continue;
      }

      final rawId = _getCellValue(row, idCol);
      final oldId = int.tryParse(rawId);
      final phone = _getCellValue(row, phoneCol);
      final address = _getCellValue(row, addressCol);
      final photoPath = _getCellValue(row, photoCol);
      final creditLimit = _parseDouble(_getCellValue(row, limitCol)) ?? 0.0;
      final createdAt = _parseDate(_getCellValue(row, createdCol), '[Customers Row ${i + 1}]', result.skippedLogs);

      final existing = await txn.rawQuery(
        'SELECT id FROM customers WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) AND TRIM(phone) = TRIM(?)',
        [name, phone],
      );

      if (existing.isNotEmpty) {
        final existingId = (existing.first['id'] as num).toInt();
        if (oldId != null) {
          oldCustomerIdToNewId[oldId] = existingId;
        }
        result.customersMerged++;
      } else {
        final newId = await txn.insert('customers', {
          'name': name,
          'phone': phone.isNotEmpty ? phone : 'N/A',
          'address': address.isNotEmpty ? address : null,
          'photo_path': photoPath.isNotEmpty ? photoPath : null,
          'credit_limit': creditLimit,
          'created_at': createdAt.toIso8601String(),
        });

        if (oldId != null) {
          oldCustomerIdToNewId[oldId] = newId;
        }
        result.customersImported++;
      }
    }
  }

  static Future<void> _processTransactionsSheet(
    List<List<dynamic>> rows,
    Transaction txn,
    ImportResult result,
    Map<int, int> oldCustomerIdToNewId,
    Map<String, String?>? customMapping,
  ) async {
    if (rows.length <= 1) return;

    final headers = rows.first.map((e) => (e?.toString() ?? '').trim()).toList();

    final custIdCol = _getColumnIndex(headers, customMapping?['customer_id'], ['customer_id', 'customerid', 'cust_id', 'id']);
    final amountCol = _getColumnIndex(headers, customMapping?['amount'], ['amount', 'পরিমাণ', 'টাকা', 'baki']);
    final descCol = _getColumnIndex(headers, customMapping?['description'], ['description', 'desc', 'note', 'বিবরণ', 'নোট']);
    final dateCol = _getColumnIndex(headers, customMapping?['date'], ['date', 'তারিখ']);
    final createdCol = _getColumnIndex(headers, customMapping?['created_at'], ['created_at', 'createdat']);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      final rawCustId = _getCellValue(row, custIdCol);
      final oldCustId = int.tryParse(rawCustId);

      if (oldCustId == null) {
        result.transactionsSkipped++;
        result.skippedLogs.add('[Transactions Row ${i + 1}] Skipped: Invalid customer_id');
        continue;
      }

      int? newCustId = oldCustomerIdToNewId[oldCustId];

      if (newCustId == null) {
        final checkLocal = await txn.rawQuery('SELECT id FROM customers WHERE id = ?', [oldCustId]);
        if (checkLocal.isNotEmpty) {
          newCustId = oldCustId;
        }
      }

      if (newCustId == null) {
        result.transactionsSkipped++;
        result.skippedLogs.add('[Transactions Row ${i + 1}] Skipped: Customer ID $oldCustId not found');
        continue;
      }

      final amount = _parseDouble(_getCellValue(row, amountCol));
      if (amount == null || amount <= 0) {
        result.transactionsSkipped++;
        result.skippedLogs.add('[Transactions Row ${i + 1}] Skipped: Invalid amount');
        continue;
      }

      final desc = _getCellValue(row, descCol);
      final date = _parseDate(_getCellValue(row, dateCol), '[Transactions Row ${i + 1}]', result.skippedLogs);
      final createdAtVal = _getCellValue(row, createdCol);
      final createdAt = createdAtVal.isNotEmpty
          ? _parseDate(createdAtVal, '[Transactions Row ${i + 1} created_at]', result.skippedLogs)
          : date;

      final existingTxn = await txn.rawQuery(
        'SELECT id FROM transactions WHERE customer_id = ? AND amount = ? AND date = ?',
        [newCustId, amount, date.toIso8601String()],
      );

      if (existingTxn.isNotEmpty) {
        result.transactionsSkipped++;
        result.skippedLogs.add('[Transactions Row ${i + 1}] Skipped: Duplicate transaction');
      } else {
        await txn.insert('transactions', {
          'customer_id': newCustId,
          'amount': amount,
          'description': desc.isNotEmpty ? desc : null,
          'date': date.toIso8601String(),
          'created_at': createdAt.toIso8601String(),
        });
        result.transactionsImported++;
      }
    }
  }

  static Future<void> _processPaymentsSheet(
    List<List<dynamic>> rows,
    Transaction txn,
    ImportResult result,
    Map<int, int> oldCustomerIdToNewId,
    Map<String, String?>? customMapping,
  ) async {
    if (rows.length <= 1) return;

    final headers = rows.first.map((e) => (e?.toString() ?? '').trim()).toList();

    final custIdCol = _getColumnIndex(headers, customMapping?['customer_id'], ['customer_id', 'customerid', 'cust_id', 'id']);
    final amountCol = _getColumnIndex(headers, customMapping?['amount'], ['amount', 'পরিমাণ', 'টাকা', 'paid', 'joma']);
    final noteCol = _getColumnIndex(headers, customMapping?['note'], ['note', 'description', 'desc', 'নোট', 'বিবরণ']);
    final dateCol = _getColumnIndex(headers, customMapping?['date'], ['date', 'তারিখ']);
    final createdCol = _getColumnIndex(headers, customMapping?['created_at'], ['created_at', 'createdat']);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      final rawCustId = _getCellValue(row, custIdCol);
      final oldCustId = int.tryParse(rawCustId);

      if (oldCustId == null) {
        result.paymentsSkipped++;
        result.skippedLogs.add('[Payments Row ${i + 1}] Skipped: Invalid customer_id');
        continue;
      }

      int? newCustId = oldCustomerIdToNewId[oldCustId];

      if (newCustId == null) {
        final checkLocal = await txn.rawQuery('SELECT id FROM customers WHERE id = ?', [oldCustId]);
        if (checkLocal.isNotEmpty) {
          newCustId = oldCustId;
        }
      }

      if (newCustId == null) {
        result.paymentsSkipped++;
        result.skippedLogs.add('[Payments Row ${i + 1}] Skipped: Customer ID $oldCustId not found');
        continue;
      }

      final amount = _parseDouble(_getCellValue(row, amountCol));
      if (amount == null || amount <= 0) {
        result.paymentsSkipped++;
        result.skippedLogs.add('[Payments Row ${i + 1}] Skipped: Invalid amount');
        continue;
      }

      final note = _getCellValue(row, noteCol);
      final date = _parseDate(_getCellValue(row, dateCol), '[Payments Row ${i + 1}]', result.skippedLogs);
      final createdAtVal = _getCellValue(row, createdCol);
      final createdAt = createdAtVal.isNotEmpty
          ? _parseDate(createdAtVal, '[Payments Row ${i + 1} created_at]', result.skippedLogs)
          : date;

      final existingPmt = await txn.rawQuery(
        'SELECT id FROM payments WHERE customer_id = ? AND amount = ? AND date = ?',
        [newCustId, amount, date.toIso8601String()],
      );

      if (existingPmt.isNotEmpty) {
        result.paymentsSkipped++;
        result.skippedLogs.add('[Payments Row ${i + 1}] Skipped: Duplicate payment');
      } else {
        await txn.insert('payments', {
          'customer_id': newCustId,
          'amount': amount,
          'note': note.isNotEmpty ? note : null,
          'date': date.toIso8601String(),
          'created_at': createdAt.toIso8601String(),
        });
        result.paymentsImported++;
      }
    }
  }
}
