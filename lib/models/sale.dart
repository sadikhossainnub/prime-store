class Sale {
  final int? id;
  final int? customerId;
  final String? customerName;
  final String saleType; // 'cash', 'baki', 'partial'
  final double totalAmount;
  final double paidAmount;
  final double bakiAmount;
  final String? invoiceNo;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final List<SaleItem> items;

  Sale({
    this.id,
    this.customerId,
    this.customerName,
    required this.saleType,
    required this.totalAmount,
    this.paidAmount = 0,
    this.bakiAmount = 0,
    this.invoiceNo,
    required this.date,
    this.note,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'sale_type': saleType,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'baki_amount': bakiAmount,
        'invoice_no': invoiceNo,
        'date': date.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem> items = const []}) => Sale(
        id: map['id'],
        customerId: map['customer_id'],
        customerName: map['customer_name'],
        saleType: map['sale_type'] ?? 'cash',
        totalAmount: (map['total_amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        bakiAmount: (map['baki_amount'] as num).toDouble(),
        invoiceNo: map['invoice_no'],
        date: DateTime.parse(map['date']),
        note: map['note'],
        createdAt: DateTime.parse(map['created_at']),
        items: items,
      );
}

class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final String? productName;
  final String? productUnit;
  final double quantity;
  final double sellPrice;
  final double discount;
  final double totalPrice;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    this.productName,
    this.productUnit,
    required this.quantity,
    required this.sellPrice,
    this.discount = 0,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'sell_price': sellPrice,
        'discount': discount,
        'total_price': totalPrice,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        id: map['id'],
        saleId: map['sale_id'],
        productId: map['product_id'],
        productName: map['product_name'],
        productUnit: map['product_unit'],
        quantity: (map['quantity'] as num).toDouble(),
        sellPrice: (map['sell_price'] as num).toDouble(),
        discount: (map['discount'] as num).toDouble(),
        totalPrice: (map['total_price'] as num).toDouble(),
      );
}
