class BakiTransaction {
  final int? id;
  final int customerId;
  final double amount;
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  BakiTransaction({
    this.id,
    required this.customerId,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BakiTransaction.fromMap(Map<String, dynamic> map) {
    return BakiTransaction(
      id: map['id'],
      customerId: map['customer_id'],
      amount: map['amount'].toDouble(),
      description: map['description'],
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
