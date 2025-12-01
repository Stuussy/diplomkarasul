import 'user.dart';

class MedicalRecord {
  MedicalRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.doctor,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final AppUser? doctor;
  final List<String> tags;

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    final doctorJson = json['doctor'] as Map<String, dynamic>?;
    return MedicalRecord(
      id: json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
      doctor: doctorJson != null ? AppUser.fromJson(doctorJson) : null,
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}
