import 'user.dart';

class SupportMessage {
  final String id;
  final AppUser? patient;
  final String content;
  final String status;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.patient,
    required this.content,
    required this.status,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['_id'] ?? '',
      patient: json['patient'] != null ? AppUser.fromJson(json['patient']) : null,
      content: json['content'] ?? '',
      status: json['status'] ?? 'open',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
