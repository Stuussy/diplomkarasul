import 'clinic.dart';
import 'review.dart';
import 'user.dart';

class Appointment {
  final String id;
  final AppUser? doctor;
  final AppUser? patient;
  final Clinic? clinic;
  final String service;
  final DateTime startTime;
  final int durationMinutes;
  final String status;
  final DateTime? confirmWindowStart;
  final DateTime? confirmWindowEnd;
  final DateTime? cancelBefore;
  final bool fineIssued;
  final Review? review;

  Appointment({
    required this.id,
    required this.doctor,
    required this.patient,
    required this.clinic,
    required this.service,
    required this.startTime,
    required this.durationMinutes,
    required this.status,
    this.confirmWindowStart,
    this.confirmWindowEnd,
    this.cancelBefore,
    this.fineIssued = false,
    this.review,
  });

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final rawDoctor = json['doctor'];
    final rawPatient = json['patient'];
    final rawClinic = json['clinic'];
    return Appointment(
      id: json['_id'] ?? '',
      doctor: rawDoctor is Map<String, dynamic> ? AppUser.fromJson(rawDoctor) : null,
      patient: rawPatient is Map<String, dynamic> ? AppUser.fromJson(rawPatient) : null,
      clinic: rawClinic is Map<String, dynamic> ? Clinic.fromJson(rawClinic) : null,
      service: json['service'] ?? '',
      startTime: DateTime.parse(json['startTime']).toLocal(),
      durationMinutes: json['durationMinutes'] ?? 30,
      status: json['status'] ?? 'scheduled',
      confirmWindowStart: json['confirmWindow']?['start'] != null
          ? DateTime.parse(json['confirmWindow']['start']).toLocal()
          : null,
      confirmWindowEnd: json['confirmWindow']?['end'] != null
          ? DateTime.parse(json['confirmWindow']['end']).toLocal()
          : null,
      cancelBefore:
          json['cancelBefore'] != null ? DateTime.parse(json['cancelBefore']).toLocal() : null,
      fineIssued: json['fineIssued'] ?? false,
      review: json['review'] is Map<String, dynamic> ? Review.fromJson(json['review']) : null,
    );
  }
}
