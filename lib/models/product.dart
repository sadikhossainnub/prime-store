class Product {
  final int? id;
  final String name;
  final String? category;
  final String unit;
  final double buyPrice;
  final double sellPrice;
  final double currentStock;
  final double minStockAlert;
  final String? barcode;
  final String? photoPath;
  final DateTime createdAt;

  Product({
    this.id,
    required this.name,
    this.category,
    this.unit = 'pcs',
    required this.buyPrice,
    required this.sellPrice,
    this.currentStock = 0,
    this.minStockAlert = 5,
    this.barcode,
    this.photoPath,
    required this.createdAt,
  });

  bool get isLowStock => currentStock <= minStockAlert;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'current_stock': currentStock,
        'min_stock_alert': minStockAlert,
        'barcode': barcode,
        'photo_path': photoPath,
        'created_at': createdAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'],
        name: map['name'],
        category: map['category'],
        unit: map['unit'] ?? 'pcs',
        buyPrice: (map['buy_price'] as num).toDouble(),
        sellPrice: (map['sell_price'] as num).toDouble(),
        currentStock: (map['current_stock'] as num).toDouble(),
        minStockAlert: (map['min_stock_alert'] as num).toDouble(),
        barcode: map['barcode'],
        photoPath: map['photo_path'],
        createdAt: DateTime.parse(map['created_at']),
      );

  Product copyWith({
    int? id,
    String? name,
    String? category,
    String? unit,
    double? buyPrice,
    double? sellPrice,
    double? currentStock,
    double? minStockAlert,
    String? barcode,
    String? photoPath,
    DateTime? createdAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        buyPrice: buyPrice ?? this.buyPrice,
        sellPrice: sellPrice ?? this.sellPrice,
        currentStock: currentStock ?? this.currentStock,
        minStockAlert: minStockAlert ?? this.minStockAlert,
        barcode: barcode ?? this.barcode,
        photoPath: photoPath ?? this.photoPath,
        createdAt: createdAt ?? this.createdAt,
      );
}
