class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final DateTime createdAt;
  final double totalDue;

  Supplier({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    required this.createdAt,
    this.totalDue = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'created_at': createdAt.toIso8601String(),
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'],
        name: map['name'],
        phone: map['phone'],
        address: map['address'],
        createdAt: DateTime.parse(map['created_at']),
        totalDue: (map['total_due'] as num?)?.toDouble() ?? 0.0,
      );
}
