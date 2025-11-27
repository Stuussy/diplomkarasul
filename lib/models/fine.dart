class Fine {
  final String id;
  final double amount;
  final String reason;
  final DateTime createdAt;
  final bool isPaid;

  Fine({
    required this.id,
    required this.amount,
    required this.reason,
    required this.createdAt,
    required this.isPaid,
  });

  factory Fine.fromJson(Map<String, dynamic> json) {
    return Fine(
      id: json['_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      reason: json['reason'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isPaid: json['isPaid'] ?? false,
    );
  }
}
