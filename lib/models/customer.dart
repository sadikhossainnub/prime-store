class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final String? photoPath;
  final double creditLimit;
  final DateTime createdAt;
  final double totalBaki;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    this.photoPath,
    this.creditLimit = 0,
    required this.createdAt,
    this.totalBaki = 0.0,
  });

  bool get isOverLimit => creditLimit > 0 && totalBaki >= creditLimit;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'photo_path': photoPath,
        'credit_limit': creditLimit,
        'created_at': createdAt.toIso8601String(),
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'],
        name: map['name'],
        phone: map['phone'],
        address: map['address'],
        photoPath: map['photo_path'],
        creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(map['created_at']),
        totalBaki: (map['total_baki'] as num?)?.toDouble() ?? 0.0,
      );
}
