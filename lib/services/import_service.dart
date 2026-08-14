import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/sale.dart';
import '../models/purchase.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../database/database_helper.dart';

enum ImportCategory {
  product('পণ্য', Icons.inventory_2_rounded),
  customer('কাস্টমার', Icons.people_rounded),
  supplier('সাপ্লায়ার', Icons.local_shipping_rounded),
  sale('বিক্রয়', Icons.point_of_sale_rounded),
  purchase('ক্রয়', Icons.shopping_cart_rounded),
  transaction('বাকি হিসাব', Icons.receipt_long_rounded),
  payment('পেমেন্ট/জমা', Icons.payments_rounded);

  final String label;
  final IconData icon;
  const ImportCategory(this.label, this.icon);
}

class FieldDef {
  final String key;
  final String label;
  final bool isRequired;
  final List<String> defaultKeywords;

  const FieldDef({
    required this.key,
    required this.label,
    this.isRequired = false,
    this.defaultKeywords = const [],
  });
}

class ImportResult {
  final int totalRows;
  final int successCount;
  final int skipCount;
  final List<String> errors;

  ImportResult({
    required this.totalRows,
    required this.successCount,
    required this.skipCount,
    required this.errors,
  });
}

class ParsedItem {
  final String title;
  final String subtitle;
  final String? detail;
  final int rowIndex;
  final Map<String, dynamic> data;
  bool selected;

  ParsedItem({
    required this.title,
    required this.subtitle,
    this.detail,
    required this.rowIndex,
    required this.data,
    this.selected = true,
  });
}

class ParsedProduct extends ParsedItem {
  final String name;
  final String? category;
  final String unit;
  final double buyPrice;
  final double sellPrice;
  final double currentStock;
  final double minStockAlert;
  final String? barcode;

  ParsedProduct({
    required this.name,
    this.category,
    this.unit = 'pcs',
    required this.buyPrice,
    required this.sellPrice,
    this.currentStock = 0,
    this.minStockAlert = 5,
    this.barcode,
    required super.rowIndex,
    super.selected = true,
  }) : super(
          title: name,
          subtitle: 'বিক্রি: ৳${sellPrice.toStringAsFixed(0)} | স্টক: ${currentStock.toStringAsFixed(0)}',
          detail: category != null ? 'ক্যাটেগরি: $category' : null,
          data: {
            'name': name,
            'category': category,
            'unit': unit,
            'buyPrice': buyPrice,
            'sellPrice': sellPrice,
            'currentStock': currentStock,
            'minStockAlert': minStockAlert,
            'barcode': barcode,
          },
        );

  Product toProduct() => Product(
        name: name,
        category: category,
        unit: unit,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        currentStock: currentStock,
        minStockAlert: minStockAlert,
        barcode: barcode,
        createdAt: DateTime.now(),
      );
}

class ImportService {
  // Product Keys
  static const _nameKeys = ['name', 'নাম', 'product', 'product name', 'পণ্যের নাম', 'পণ্য'];
  static const _categoryKeys = ['category', 'ক্যাটেগরি', 'বিভাগ', 'cat'];
  static const _unitKeys = ['unit', 'একক', 'ইউনিট'];
  static const _buyPriceKeys = ['buy price', 'buy_price', 'ক্রয় মূল্য', 'cost', 'purchase price', 'ক্রয়মূল্য', 'কেনা দাম'];
  static const _sellPriceKeys = ['sell price', 'sell_price', 'বিক্রয় মূল্য', 'price', 'selling price', 'বিক্রয়মূল্য', 'বিক্রি দাম'];
  static const _stockKeys = ['stock', 'current stock', 'current_stock', 'স্টক', 'quantity', 'পরিমাণ', 'মজুদ'];
  static const _minStockKeys = ['min stock', 'min_stock_alert', 'min stock alert', 'সর্বনিম্ন স্টক', 'alert'];
  static const _barcodeKeys = ['barcode', 'বারকোড', 'bar code', 'sku'];

  // Customer / Supplier Keys
  static const _phoneKeys = ['phone', 'ফোন', 'mobile', 'মোবাইল', 'contact', 'যোগাযোগ', 'নম্বর'];
  static const _addressKeys = ['address', 'ঠিকানা', 'location', 'বাসা'];
  static const _creditLimitKeys = ['credit limit', 'credit_limit', 'ক্রেডিট লিমিট', 'বাকি সীমা', 'limit'];

  // Transaction / Payment / Sale Keys
  static const _customerNameKeys = ['customer', 'customer_name', 'কাস্টমার', 'কাস্টমারের নাম', 'গ্রাহক', 'name', 'নাম'];
  static const _supplierNameKeys = ['supplier', 'supplier_name', 'সাপ্লায়ার', 'ডিলার', 'name', 'নাম'];
  static const _amountKeys = ['amount', 'টাকা', 'পরিমাণ', 'বাকি', 'জমা', 'total', 'baki'];
  static const _paidKeys = ['paid', 'paid_amount', 'জমা', 'জমা টাকা', 'পরিশোধ'];
  static const _bakiKeys = ['baki', 'baki_amount', 'বাকি', 'বাকি টাকা'];
  static const _descKeys = ['description', 'desc', 'note', 'নোট', 'বিবরণ', 'কারণ'];
  static const _dateKeys = ['date', 'তারিখ', 'created_at', 'time'];
  static const _invoiceKeys = ['invoice', 'invoice_no', 'ইনভয়েস', 'চালান', 'মেমো', 'মেমো নম্বর'];

  static List<FieldDef> getFieldsForCategory(ImportCategory cat) {
    switch (cat) {
      case ImportCategory.product:
        return const [
          FieldDef(key: 'name', label: 'পণ্যের নাম (Name)', isRequired: true, defaultKeywords: _nameKeys),
          FieldDef(key: 'category', label: 'ক্যাটেগরি (Category)', defaultKeywords: _categoryKeys),
          FieldDef(key: 'unit', label: 'একক (Unit)', defaultKeywords: _unitKeys),
          FieldDef(key: 'buy_price', label: 'ক্রয় মূল্য (Buy Price)', defaultKeywords: _buyPriceKeys),
          FieldDef(key: 'sell_price', label: 'বিক্রয় মূল্য (Sell Price)', defaultKeywords: _sellPriceKeys),
          FieldDef(key: 'stock', label: 'স্টক (Current Stock)', defaultKeywords: _stockKeys),
          FieldDef(key: 'min_stock', label: 'সর্বনিম্ন স্টক (Min Alert)', defaultKeywords: _minStockKeys),
          FieldDef(key: 'barcode', label: 'বারকোড (Barcode)', defaultKeywords: _barcodeKeys),
        ];
      case ImportCategory.customer:
        return const [
          FieldDef(key: 'name', label: 'কাস্টমার নাম (Name)', isRequired: true, defaultKeywords: _customerNameKeys),
          FieldDef(key: 'phone', label: 'ফোন নম্বর (Phone)', defaultKeywords: _phoneKeys),
          FieldDef(key: 'address', label: 'ঠিকানা (Address)', defaultKeywords: _addressKeys),
          FieldDef(key: 'credit_limit', label: 'ক্রেডিট সীমা (Credit Limit)', defaultKeywords: _creditLimitKeys),
        ];
      case ImportCategory.supplier:
        return const [
          FieldDef(key: 'name', label: 'সাপ্লায়ার নাম (Name)', isRequired: true, defaultKeywords: _supplierNameKeys),
          FieldDef(key: 'phone', label: 'ফোন নম্বর (Phone)', defaultKeywords: _phoneKeys),
          FieldDef(key: 'address', label: 'ঠিকানা (Address)', defaultKeywords: _addressKeys),
        ];
      case ImportCategory.sale:
        return const [
          FieldDef(key: 'amount', label: 'মোট টাকা (Total Amount)', isRequired: true, defaultKeywords: _amountKeys),
          FieldDef(key: 'customer', label: 'কাস্টমার (Customer)', defaultKeywords: _customerNameKeys),
          FieldDef(key: 'paid', label: 'পরিশোধ (Paid Amount)', defaultKeywords: _paidKeys),
          FieldDef(key: 'baki', label: 'বাকি (Baki Amount)', defaultKeywords: _bakiKeys),
          FieldDef(key: 'invoice', label: 'ইনভয়েস (Invoice No)', defaultKeywords: _invoiceKeys),
          FieldDef(key: 'date', label: 'তারিখ (Date)', defaultKeywords: _dateKeys),
        ];
      case ImportCategory.purchase:
        return const [
          FieldDef(key: 'amount', label: 'মোট টাকা (Total Amount)', isRequired: true, defaultKeywords: _amountKeys),
          FieldDef(key: 'supplier', label: 'সাপ্লায়ার (Supplier)', defaultKeywords: _supplierNameKeys),
          FieldDef(key: 'paid', label: 'পরিশোধ (Paid Amount)', defaultKeywords: _paidKeys),
          FieldDef(key: 'invoice', label: 'ইনভয়েস (Invoice No)', defaultKeywords: _invoiceKeys),
          FieldDef(key: 'date', label: 'তারিখ (Date)', defaultKeywords: _dateKeys),
        ];
      case ImportCategory.transaction:
        return const [
          FieldDef(key: 'customer', label: 'কাস্টমার (Customer Name)', isRequired: true, defaultKeywords: _customerNameKeys),
          FieldDef(key: 'amount', label: 'বাকির পরিমাণ (Baki Amount)', isRequired: true, defaultKeywords: _amountKeys),
          FieldDef(key: 'note', label: 'বিবরণ (Description)', defaultKeywords: _descKeys),
          FieldDef(key: 'date', label: 'তারিখ (Date)', defaultKeywords: _dateKeys),
        ];
      case ImportCategory.payment:
        return const [
          FieldDef(key: 'customer', label: 'কাস্টমার (Customer Name)', isRequired: true, defaultKeywords: _customerNameKeys),
          FieldDef(key: 'amount', label: 'জমার পরিমাণ (Paid Amount)', isRequired: true, defaultKeywords: _amountKeys),
          FieldDef(key: 'note', label: 'বিবরণ (Note)', defaultKeywords: _descKeys),
          FieldDef(key: 'date', label: 'তারিখ (Date)', defaultKeywords: _dateKeys),
        ];
    }
  }

  /// Auto-match file headers to field keys
  static Map<String, String?> autoMatchFields(ImportCategory cat, List<String> headers) {
    final fields = getFieldsForCategory(cat);
    final map = <String, String?>{};

    for (final f in fields) {
      String? matched;
      for (final h in headers) {
        final lower = h.trim().toLowerCase();
        for (final kw in f.defaultKeywords) {
          if (lower == kw.toLowerCase()) {
            matched = h;
            break;
          }
        }
        if (matched != null) break;
      }
      map[f.key] = matched;
    }
    return map;
  }

  /// Pick a file (CSV or Excel)
  static Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      allowMultiple: false,
    );
    return result?.files.firstOrNull;
  }

  /// Extract headers from a selected file (non-blocking)
  static Future<List<String>> extractHeaders(PlatformFile file) async {
    final path = file.path;
    if (path == null) return [];

    final ext = file.extension?.toLowerCase();
    List<List<dynamic>> rows;

    try {
      if (ext == 'csv') {
        final content = await File(path).readAsString();
        rows = await Future.microtask(() => const CsvToListConverter(eol: '\n').convert(content));
      } else if (ext == 'xlsx' || ext == 'xls') {
        final bytes = await File(path).readAsBytes();
        final excel = await compute(_parseExcelBytes, bytes);
        final sheet = excel.tables.values.first;
        rows = sheet.rows.map((r) => r.map((cell) => cell?.value ?? '').toList()).toList();
      } else {
        return [];
      }

      if (rows.isEmpty) return [];
      return rows.first.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Excel _parseExcelBytes(Uint8List bytes) {
    return Excel.decodeBytes(bytes);
  }

  /// Parse file based on selected category & custom field mapping (non-blocking)
  static Future<List<ParsedItem>> parseFile(
    PlatformFile file,
    ImportCategory category, {
    Map<String, String?>? customMapping,
  }) async {
    final path = file.path;
    if (path == null) throw Exception('ফাইল পাথ পাওয়া যায়নি');

    final ext = file.extension?.toLowerCase();
    List<List<dynamic>> rows;

    if (ext == 'csv') {
      final content = await File(path).readAsString();
      rows = await Future.microtask(() => const CsvToListConverter(eol: '\n').convert(content));
    } else if (ext == 'xlsx' || ext == 'xls') {
      final bytes = await File(path).readAsBytes();
      final excel = await compute(_parseExcelBytes, bytes);
      final sheet = excel.tables.values.first;
      rows = sheet.rows.map((r) => r.map((cell) => cell?.value ?? '').toList()).toList();
    } else {
      throw Exception('অসমর্থিত ফাইল ফরম্যাট: .$ext');
    }

    if (rows.isEmpty) throw Exception('ফাইলটি খালি');

    final headers = rows.first.map((e) => e.toString().trim()).toList();

    switch (category) {
      case ImportCategory.product:
        return _parseProducts(rows, headers, customMapping);
      case ImportCategory.customer:
        return _parseCustomers(rows, headers, customMapping);
      case ImportCategory.supplier:
        return _parseSuppliers(rows, headers, customMapping);
      case ImportCategory.sale:
        return _parseSales(rows, headers, customMapping);
      case ImportCategory.purchase:
        return _parsePurchases(rows, headers, customMapping);
      case ImportCategory.transaction:
        return _parseTransactions(rows, headers, customMapping);
      case ImportCategory.payment:
        return _parsePayments(rows, headers, customMapping);
    }
  }

  static int? _resolveCol(List<String> headers, String? mappedHeader, List<String> fallbackKeywords) {
    if (mappedHeader != null && mappedHeader.isNotEmpty) {
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].trim().toLowerCase() == mappedHeader.trim().toLowerCase()) return i;
      }
    }
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final kw in fallbackKeywords) {
        if (h == kw.toLowerCase()) return i;
      }
    }
    return null;
  }

  static List<ParsedItem> _parseProducts(List<List<dynamic>> rows, List<String> headers, Map<String, String?>? customMapping) {
    final map = {
      'name': _resolveCol(headers, customMapping?['name'], _nameKeys),
      'category': _resolveCol(headers, customMapping?['category'], _categoryKeys),
      'unit': _resolveCol(headers, customMapping?['unit'], _unitKeys),
      'buy_price': _resolveCol(headers, customMapping?['buy_price'], _buyPriceKeys),
      'sell_price': _resolveCol(headers, customMapping?['sell_price'], _sellPriceKeys),
      'stock': _resolveCol(headers, customMapping?['stock'], _stockKeys),
      'min_stock': _resolveCol(headers, customMapping?['min_stock'], _minStockKeys),
      'barcode': _resolveCol(headers, customMapping?['barcode'], _barcodeKeys),
    };

    if (map['name'] == null) {
      throw Exception('পণ্যের নাম কলামটি ম্যাপিং করা হয়নি।');
    }

    final items = <ParsedItem>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = _getCellValue(row, map['name']);
      if (name.isEmpty) continue;

      final cat = _getCellValue(row, map['category']);
      final unit = _getCellValue(row, map['unit']).isNotEmpty ? _getCellValue(row, map['unit']) : 'pcs';
      final buy = _parseDouble(_getCellValue(row, map['buy_price']));
      final sell = _parseDouble(_getCellValue(row, map['sell_price']));
      final stock = _parseDouble(_getCellValue(row, map['stock']));
      final minStock = _parseDouble(_getCellValue(row, map['min_stock']));
      final barcode = _getCellValue(row, map['barcode']);

      items.add(ParsedProduct(
        name: name,
        category: cat.isNotEmpty ? cat : null,
        unit: unit,
        buyPrice: buy,
        sellPrice: sell,
        currentStock: stock,
        minStockAlert: minStock > 0 ? minStock : 5,
        barcode: barcode.isNotEmpty ? barcode : null,
        rowIndex: i + 1,
      ));
    }
    return items;
  }

  static List<ParsedItem> _parseCustomers(List<List<dynamic>> rows, List<String> headers, Map<String, String?>? customMapping) {
    final map = {
      'name': _resolveCol(headers, customMapping?['name'], _customerNameKeys),
      'phone': _resolveCol(headers, customMapping?['phone'], _phoneKeys),
      'address': _resolveCol(headers, customMapping?['address'], _addressKeys),
      'credit_limit': _resolveCol(headers, customMapping?['credit_limit'], _creditLimitKeys),
    };

    if (map['name'] == null) {
      throw Exception('কাস্টমারের নাম কলামটি ম্যাপিং করা হয়নি।');
    }

    final items = <ParsedItem>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = _getCellValue(row, map['name']);
      if (name.isEmpty) continue;

      final phone = _getCellValue(row, map['phone']).isNotEmpty ? _getCellValue(row, map['phone']) : 'N/A';
      final address = _getCellValue(row, map['address']);
      final limit = _parseDouble(_getCellValue(row, map['credit_limit']));

      items.add(ParsedItem(
        title: name,
        subtitle: 'ফোন: $phone${address.isNotEmpty ? ' | $address' : ''}',
        detail: limit > 0 ? 'ক্রেডিট সীমা: ৳${limit.toStringAsFixed(0)}' : null,
        rowIndex: i + 1,
        data: {
          'name': name,
          'phone': phone,
          'address': address.isNotEmpty ? address : null,
          'creditLimit': limit,
        },
      ));
    }
    return items;
  }

  static List<ParsedItem> _parseSuppliers(List<List<dynamic>> rows, List<String> headers, Map<String, String?>? customMapping) {
    final map = {
      'name': _resolveCol(headers, customMapping?['name'], _supplierNameKeys),
      'phone': _resolveCol(headers, customMapping?['phone'], _phoneKeys),
      'address': _resolveCol(headers, customMapping?['address'], _addressKeys),
    };

    if (map['name'] == null) {
      throw Exception('সাপ্লায়ারের নাম কলামটি ম্যাপিং করা হয়নি।');
    }

    final items = <ParsedItem>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = _getCellValue(row, map['name']);
      if (name.isEmpty) continue;

      final phone = _getCellValue(row, map['phone']).isNotEmpty ? _getCellValue(row, map['phone']) : 'N/A';
      final address = _getCellValue(row, map['address']);

      items.add(ParsedItem(
        title: name,
        subtitle: 'ফোন: $phone${address.isNotEmpty ? ' | $address' : ''}',
        rowIndex: i + 1,
        data: {
          'name': name,
          'phone': phone,
          'address': address.isNotEmpty ? address : null,
        },
      ));
    }
    return items;
  }

  static List<ParsedItem> _parseSales(List<List<dynamic>> rows, List<String> headers, Map<String, String?>? customMapping) {
    final map = {
      'amount': _resolveCol(headers, customMapping?['amount'], _amountKeys),
      'customer': _resolveCol(headers, customMapping?['customer'], _customerNameKeys),
      'paid': _resolveCol(headers, customMapping?['paid'], _paidKeys),
      'baki': _resolveCol(headers, customMapping?['baki'], _bakiKeys),
      'invoice': _resolveCol(headers, customMapping?['invoice'], _invoiceKeys),
      'date': _resolveCol(headers, customMapping?['date'], _dateKeys),
    };

    if (map['amount'] == null) {
      throw Exception('মোট টাকা কলামটি ম্যাপিং করা হয়নি।');
    }

    final items = <ParsedItem>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final total = _parseDouble(_getCellValue(row, map['amount']));
      if (total <= 0) continue;

      final invoice = _getCellValue(row, map['invoice']);
      final customer = _getCellValue(row, map['customer']);
      final paid = _parseDouble(_getCellValue(row, map['paid']));
      final baki = _parseDouble(_getCellValue(row, map['baki']));
      final dateStr = _getCellValue(row, map['date']);
      final date = _parseDate(dateStr);

      items.add(ParsedItem(
        title: customer.isNotEmpty ? customer : 'নগদ বিক্রয়',
        subtitle: 'মোট: ৳${total.toStringAsFixed(0)} | পরিশোধ: ৳${paid.toStringAsFixed(0)}',
        detail: 'ইনভয়েস: ${invoice.isNotEmpty ? invoice : 'অটো'} | তারিখ: ${date.toString().split(' ')[0]}',
        rowIndex: i + 1,
        data: {
          'customerName': customer.isNotEmpty ? customer : null,
          'totalAmount': total,
          'paidAmount': paid,
          'bakiAmount': baki > 0 ? baki : (total - paid > 0 ? total - paid : 0.0),
          'invoiceNo': invoice.isNotEmpty ? invoice : null,
          'date': date,
        },
      ));
    }
    return items;
  }

  static List<ParsedItem> _parsePurchases(List<List<dynamic>> rows, List<String> headers, Map<String, String?>? customMapping) {
    final map = {
      'amount': _resolveCol(headers, customMapping?['amount'], _amountKeys),
      'supplier': _resolveCol(headers, customMapping?['supplier'], _supplierNameKeys),
      'paid': _resolveCol(headers, customMapping?['paid'], _paidKeys),
      'invoice': _resolveCol(headers, customMapping?['invoice'], _invoiceKeys),
      'date': _resolveCol(headers, customMapping?['date'], _dateKeys),
    };

    if (map['amount'] == null) {
      throw Exception('মোট টাকা কলামটি ম্যাপিং করা হয়নি।');
    }

    final items = <ParsedItem>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final total = _parseDouble(_getCellValue(row, map['amount']));
      if (total <= 0) continue;

      final invoice = _getCellValue(row, map['invoice']);
      final supplier = _getCellValue(row, map['supplier']);
      final paid = _parseDouble(_getCellValue(row, map['paid']));
      final dateStr = _getCellValue(row, map['date']);
      final date = _parseDate(dateStr);

      items.add(ParsedItem(
        title: supplier.isNotEmpty ? supplier : 'সাধারণ ক্রয়',
        subtitle: 'মোট: ৳${total.toStringAsFixed(0)} | পরিশোধ: ৳${paid.toStringAsFixed(0)}',
        detail: 'ইনভয়েস: ${invoice.isNotEmpty ? invoice : 'অটো'} | তারিখ: ${date.toString().split(' ')[0]}',
        rowIndex: i + 1,
        data: {
          'supplierName': supplier.isNotEmpty ? supplier : null,
          'totalAmount': total,
          'paidAmount': paid,
          'invoiceNo': invoice.isNotEmpty ? invoice : null,
          'date': date,
        },
      ));
    }
    return items;
  }

  static List<ParsedItem> _parseTransactions(List<List<dynamic>> rows, List<String> headers, Map<String, String?>? customMapping) {
    final map = {
      'customer': _resolveCol(headers, customMapping?['customer'], _customerNameKeys),
      'amount': _resolveCol(headers, customMapping?['amount'], _amountKeys),
      'note': _resolveCol(headers, customMapping?['note'], _descKeys),
      'date': _resolveCol(headers, customMapping?['date'], _dateKeys),
    };

    if (map['amount'] == null || map['customer'] == null) {
      throw Exception('কাস্টমারের নাম এবং বাকির পরিমাণ কলাম ম্যাপিং করতে হবে।');
    }

    final items = <ParsedItem>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final customer = _getCellValue(row, map['customer']);
      final amount = _parseDouble(_getCellValue(row, map['amount']));
      if (customer.isEmpty || amount <= 0) continue;

      final note = _getCellValue(row, map['note']);
      final dateStr = _getCellValue(row, map['date']);
      final date = _parseDate(dateStr);

      items.add(ParsedItem(
        title: customer,
        subtitle: 'বাকির পরিমাণ: ৳${amount.toStringAsFixed(0)}',
        detail: 'তারিখ: ${date.toString().split(' ')[0]}${note.isNotEmpty ? ' | $note' : ''}',
        rowIndex: i + 1,
        data: {
          'customerName': customer,
          'amount': amount,
          'description': note.isNotEmpty ? note : null,
          'date': date,
        },
      ));
    }
    return items;
  }

  static List<ParsedItem> _parsePayments(List<List<dynamic>> rows, List<String> headers, Map<String, String?>? customMapping) {
    final map = {
      'customer': _resolveCol(headers, customMapping?['customer'], _customerNameKeys),
      'amount': _resolveCol(headers, customMapping?['amount'], _amountKeys),
      'note': _resolveCol(headers, customMapping?['note'], _descKeys),
      'date': _resolveCol(headers, customMapping?['date'], _dateKeys),
    };

    if (map['amount'] == null || map['customer'] == null) {
      throw Exception('কাস্টমারের নাম এবং জমার পরিমাণ কলাম ম্যাপিং করতে হবে।');
    }

    final items = <ParsedItem>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final customer = _getCellValue(row, map['customer']);
      final amount = _parseDouble(_getCellValue(row, map['amount']));
      if (customer.isEmpty || amount <= 0) continue;

      final note = _getCellValue(row, map['note']);
      final dateStr = _getCellValue(row, map['date']);
      final date = _parseDate(dateStr);

      items.add(ParsedItem(
        title: customer,
        subtitle: 'জমার পরিমাণ: ৳${amount.toStringAsFixed(0)}',
        detail: 'তারিখ: ${date.toString().split(' ')[0]}${note.isNotEmpty ? ' | $note' : ''}',
        rowIndex: i + 1,
        data: {
          'customerName': customer,
          'amount': amount,
          'note': note.isNotEmpty ? note : null,
          'date': date,
        },
      ));
    }
    return items;
  }

  // DB Importers
  static Future<ImportResult> importData(List<ParsedItem> items, ImportCategory category) async {
    final selected = items.where((p) => p.selected).toList();
    int successCount = 0;
    int skipCount = 0;
    final errors = <String>[];

    final dbHelper = DatabaseHelper.instance;

    for (final item in selected) {
      try {
        switch (category) {
          case ImportCategory.product:
            if (item is ParsedProduct) {
              await dbHelper.createProduct(item.toProduct());
            } else {
              final d = item.data;
              await dbHelper.createProduct(Product(
                name: d['name'],
                category: d['category'],
                unit: d['unit'] ?? 'pcs',
                buyPrice: d['buyPrice'],
                sellPrice: d['sellPrice'],
                currentStock: d['currentStock'],
                minStockAlert: d['minStockAlert'],
                barcode: d['barcode'],
                createdAt: DateTime.now(),
              ));
            }
            break;

          case ImportCategory.customer:
            final d = item.data;
            await dbHelper.createCustomer(Customer(
              name: d['name'],
              phone: d['phone'] ?? 'N/A',
              address: d['address'],
              creditLimit: d['creditLimit'] ?? 0.0,
              createdAt: DateTime.now(),
            ));
            break;

          case ImportCategory.supplier:
            final d = item.data;
            await dbHelper.createSupplier(Supplier(
              name: d['name'],
              phone: d['phone'] ?? 'N/A',
              address: d['address'],
              createdAt: DateTime.now(),
            ));
            break;

          case ImportCategory.sale:
            final d = item.data;
            int? customerId;
            if (d['customerName'] != null) {
              customerId = await _findOrCreateCustomer(d['customerName']);
            }
            final total = d['totalAmount'] as double;
            final paid = d['paidAmount'] as double;
            final baki = d['bakiAmount'] as double;
            await dbHelper.createSale(
              Sale(
                customerId: customerId,
                saleType: baki > 0 ? (paid > 0 ? 'partial' : 'baki') : 'cash',
                totalAmount: total,
                paidAmount: paid,
                bakiAmount: baki,
                invoiceNo: d['invoiceNo'],
                date: d['date'] ?? DateTime.now(),
                createdAt: DateTime.now(),
              ),
              [],
            );
            break;

          case ImportCategory.purchase:
            final d = item.data;
            int? supplierId;
            if (d['supplierName'] != null) {
              supplierId = await _findOrCreateSupplier(d['supplierName']);
            }
            await dbHelper.createPurchase(
              Purchase(
                supplierId: supplierId,
                totalAmount: d['totalAmount'],
                paidAmount: d['paidAmount'],
                invoiceNo: d['invoiceNo'],
                date: d['date'] ?? DateTime.now(),
                createdAt: DateTime.now(),
              ),
              [],
            );
            break;

          case ImportCategory.transaction:
            final d = item.data;
            final custId = await _findOrCreateCustomer(d['customerName']);
            await dbHelper.createTransaction(BakiTransaction(
              customerId: custId,
              amount: d['amount'],
              description: d['description'],
              date: d['date'] ?? DateTime.now(),
              createdAt: DateTime.now(),
            ));
            break;

          case ImportCategory.payment:
            final d = item.data;
            final custId = await _findOrCreateCustomer(d['customerName']);
            await dbHelper.createPayment(Payment(
              customerId: custId,
              amount: d['amount'],
              note: d['note'],
              date: d['date'] ?? DateTime.now(),
              createdAt: DateTime.now(),
            ));
            break;
        }
        successCount++;
      } catch (e) {
        errors.add('সারি ${item.rowIndex}: ${item.title} - $e');
        skipCount++;
      }
    }

    return ImportResult(
      totalRows: selected.length,
      successCount: successCount,
      skipCount: skipCount,
      errors: errors,
    );
  }

  static Future<ImportResult> importProducts(List<ParsedProduct> products) {
    return importData(products, ImportCategory.product);
  }

  static Future<int> _findOrCreateCustomer(String name) async {
    final customers = await DatabaseHelper.instance.getAllCustomers();
    final existing = customers.where((c) => c.name.trim().toLowerCase() == name.trim().toLowerCase()).firstOrNull;
    if (existing != null && existing.id != null) return existing.id!;
    return await DatabaseHelper.instance.createCustomer(Customer(
      name: name.trim(),
      phone: 'N/A',
      createdAt: DateTime.now(),
    ));
  }

  static Future<int> _findOrCreateSupplier(String name) async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    final existing = suppliers.where((s) => s.name.trim().toLowerCase() == name.trim().toLowerCase()).firstOrNull;
    if (existing != null && existing.id != null) return existing.id!;
    return await DatabaseHelper.instance.createSupplier(Supplier(
      name: name.trim(),
      phone: 'N/A',
      createdAt: DateTime.now(),
    ));
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

  static double _parseDouble(String value) {
    if (value.isEmpty) return 0;
    value = value.replaceAll(RegExp(r'[,৳$€£¥₹\s]'), '');
    return double.tryParse(value) ?? 0;
  }

  static DateTime _parseDate(String val) {
    if (val.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(val);
    } catch (_) {
      try {
        final parts = val.split(RegExp(r'[-/.]'));
        if (parts.length == 3) {
          int d = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          int y = int.parse(parts[2]);
          if (y < 100) y += 2000;
          return DateTime(y, m, d);
        }
      } catch (_) {}
    }
    return DateTime.now();
  }
}
