import 'appointment.dart';

class Fine {
  final String id;
  final double amount;
  final String reason;
  final DateTime createdAt;
  final bool isPaid;
  final DateTime? paidAt;
  final Appointment? appointment;

  Fine({
    required this.id,
    required this.amount,
    required this.reason,
    required this.createdAt,
    required this.isPaid,
    this.paidAt,
    this.appointment,
  });

  factory Fine.fromJson(Map<String, dynamic> json) {
    final rawAppointment = json['appointment'];
    return Fine(
      id: json['_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      reason: json['reason'] ?? '',
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
      isPaid: json['isPaid'] ?? false,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt']).toLocal()
          : null,
      appointment: rawAppointment is Map<String, dynamic>
          ? Appointment.fromJson(rawAppointment)
          : null,
    );
  }
}
