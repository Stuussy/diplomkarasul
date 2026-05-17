import 'clinic.dart';
import 'user.dart';

class MedicalRecord {
  MedicalRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.doctor,
    required this.patient,
    required this.clinic,
    required this.price,
    required this.toothMap,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final AppUser? doctor;
  final AppUser? patient;
  final Clinic? clinic;
  final double price;
  final List<String> tags;
  final List<ToothMark> toothMap;

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    final rawDoctor = json['doctor'];
    final rawPatient = json['patient'];
    final rawAppointment = json['appointment'];
    Clinic? clinic;
    if (rawAppointment is Map<String, dynamic>) {
      final rawClinic = rawAppointment['clinic'];
      if (rawClinic is Map<String, dynamic>) {
        clinic = Clinic.fromJson(rawClinic);
      }
    }
    final rawPrice = json['price'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;
    return MedicalRecord(
      id: json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
      doctor: rawDoctor is Map<String, dynamic> ? AppUser.fromJson(rawDoctor) : null,
      patient: rawPatient is Map<String, dynamic> ? AppUser.fromJson(rawPatient) : null,
      clinic: clinic,
      price: price,
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      toothMap: (json['toothMap'] as List<dynamic>? ?? [])
          .map((item) => ToothMark.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ToothMark {
  ToothMark({
    required this.arch,
    required this.index,
    required this.status,
    this.note,
  });

  final String arch;
  final int index;
  final String status;
  final String? note;

  factory ToothMark.fromJson(Map<String, dynamic> json) => ToothMark(
    arch: json['arch']?.toString() ?? 'upper',
    index: (json['index'] as num?)?.toInt() ?? 1,
    status: json['status']?.toString() ?? 'healthy',
    note: json['note']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'arch': arch,
    'index': index,
    'status': status,
    if (note != null) 'note': note,
  };
}
