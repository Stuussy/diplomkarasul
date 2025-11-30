import 'user.dart';

class SupportMessage {
  final String id;
  final AppUser? patient;
  final String content;
  final String status;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final List<SupportMessageEntry> history;

  SupportMessage({
    required this.id,
    required this.patient,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.history,
    required this.lastMessageAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final history = (json['history'] as List<dynamic>? ?? [])
        .map((entry) => SupportMessageEntry.fromJson(entry as Map<String, dynamic>))
        .toList();
    return SupportMessage(
      id: json['_id'] ?? '',
      patient: json['patient'] != null ? AppUser.fromJson(json['patient']) : null,
      content: json['content'] ?? '',
      status: json['status'] ?? 'open',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
      lastMessageAt:
          json['lastMessageAt'] != null ? DateTime.parse(json['lastMessageAt']).toLocal() : null,
      history: history,
    );
  }
}

class SupportMessageEntry {
  final AppUser? sender;
  final String content;
  final DateTime createdAt;

  SupportMessageEntry({
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  factory SupportMessageEntry.fromJson(Map<String, dynamic> json) {
    return SupportMessageEntry(
      sender: json['sender'] != null ? AppUser.fromJson(json['sender']) : null,
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
