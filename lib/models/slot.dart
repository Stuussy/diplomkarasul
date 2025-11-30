class Slot {
  final String id;
  final String doctorId;
  final String clinicId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  Slot({
    required this.id,
    required this.doctorId,
    required this.clinicId,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      id: json['_id'] ?? '',
      doctorId: json['doctor']?.toString() ?? '',
      clinicId: json['clinic']?.toString() ?? '',
      startTime: DateTime.parse(json['startTime']).toLocal(),
      endTime: DateTime.parse(json['endTime']).toLocal(),
      status: json['status'] ?? 'available',
    );
  }
}
