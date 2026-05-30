import 'user.dart';

class TreatmentStep {
  TreatmentStep({
    this.id,
    required this.order,
    required this.procedure,
    this.description = '',
    this.durationDays = 7,
    this.price = 0,
    this.status = 'pending',
  });

  final String? id;
  final int order;
  String procedure;
  String description;
  int durationDays;
  double price;
  String status; // pending | in_progress | done

  factory TreatmentStep.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    return TreatmentStep(
      id: json['_id']?.toString(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      procedure: json['procedure']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 7,
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'procedure': procedure,
    'description': description,
    'durationDays': durationDays,
    'price': price,
    'status': status,
  };
}

class TreatmentPlan {
  TreatmentPlan({
    required this.id,
    required this.title,
    this.diagnosis = '',
    this.summary = '',
    required this.steps,
    this.status = 'active',
    this.aiGenerated = false,
    this.createdAt,
    this.doctor,
    this.patient,
  });

  final String id;
  final String title;
  final String diagnosis;
  final String summary;
  final List<TreatmentStep> steps;
  final String status; // draft | active | completed | cancelled
  final bool aiGenerated;
  final DateTime? createdAt;
  final AppUser? doctor;
  final AppUser? patient;

  double get totalCost => steps.fold(0, (sum, s) => sum + s.price);

  int get totalDurationDays => steps.fold(0, (sum, s) => sum + s.durationDays);

  int get progress {
    if (steps.isEmpty) return 0;
    final done = steps.where((s) => s.status == 'done').length;
    return ((done / steps.length) * 100).round();
  }

  factory TreatmentPlan.fromJson(Map<String, dynamic> json) {
    final rawDoctor = json['doctor'];
    final rawPatient = json['patient'];
    return TreatmentPlan(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'План лечения',
      diagnosis: json['diagnosis']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      aiGenerated: json['aiGenerated'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      doctor: rawDoctor is Map<String, dynamic> ? AppUser.fromJson(rawDoctor) : null,
      patient: rawPatient is Map<String, dynamic> ? AppUser.fromJson(rawPatient) : null,
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((item) => TreatmentStep.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
