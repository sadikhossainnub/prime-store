class Purchase {
  final int? id;
  final int? supplierId;
  final String? supplierName;
  final String? invoiceNo;
  final double totalAmount;
  final double paidAmount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final List<PurchaseItem> items;

  Purchase({
    this.id,
    this.supplierId,
    this.supplierName,
    this.invoiceNo,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.date,
    this.note,
    required this.createdAt,
    this.items = const [],
  });

  double get dueAmount => totalAmount - paidAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'invoice_no': invoiceNo,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'date': date.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory Purchase.fromMap(Map<String, dynamic> map, {List<PurchaseItem> items = const []}) =>
      Purchase(
        id: map['id'],
        supplierId: map['supplier_id'],
        supplierName: map['supplier_name'],
        invoiceNo: map['invoice_no'],
        totalAmount: (map['total_amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        date: DateTime.parse(map['date']),
        note: map['note'],
        createdAt: DateTime.parse(map['created_at']),
        items: items,
      );
}

class PurchaseItem {
  final int? id;
  final int purchaseId;
  final int productId;
  final String? productName;
  final String? productUnit;
  final double quantity;
  final double buyPrice;
  final double totalPrice;

  PurchaseItem({
    this.id,
    required this.purchaseId,
    required this.productId,
    this.productName,
    this.productUnit,
    required this.quantity,
    required this.buyPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchase_id': purchaseId,
        'product_id': productId,
        'quantity': quantity,
        'buy_price': buyPrice,
        'total_price': totalPrice,
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
        id: map['id'],
        purchaseId: map['purchase_id'],
        productId: map['product_id'],
        productName: map['product_name'],
        productUnit: map['product_unit'],
        quantity: (map['quantity'] as num).toDouble(),
        buyPrice: (map['buy_price'] as num).toDouble(),
        totalPrice: (map['total_price'] as num).toDouble(),
      );
}
