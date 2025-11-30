class Clinic {
  final String id;
  final String name;
  final String? address;
  final List<double> coordinates;
  final String? taxiDeepLink;
  final String? supportPhone;
  final String? supportEmail;
  final String? qrPayload;
  final DateTime? qrUpdatedAt;

  const Clinic({
    required this.id,
    required this.name,
    required this.coordinates,
    this.address,
    this.taxiDeepLink,
    this.supportPhone,
    this.supportEmail,
    this.qrPayload,
    this.qrUpdatedAt,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    final qr = json['qr'] as Map<String, dynamic>?;
    return Clinic(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] as String?,
      coordinates: (json['location']?['coordinates'] as List?)?.cast<double>() ?? [0, 0],
      taxiDeepLink: json['taxiDeepLink'] as String?,
      supportPhone: json['supportPhone'] as String?,
      supportEmail: json['supportEmail'] as String?,
      qrPayload: qr?['payload'] as String?,
      qrUpdatedAt: qr?['updatedAt'] != null ? DateTime.parse(qr!['updatedAt'] as String) : null,
    );
  }
}
