class Clinic {
  final String id;
  final String name;
  final String? address;
  final List<double> coordinates;
  final String? taxiDeepLink;
  final String? supportPhone;

  const Clinic({
    required this.id,
    required this.name,
    required this.coordinates,
    this.address,
    this.taxiDeepLink,
    this.supportPhone,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] as String?,
      coordinates: (json['location']?['coordinates'] as List?)?.cast<double>() ?? [0, 0],
      taxiDeepLink: json['taxiDeepLink'] as String?,
      supportPhone: json['supportPhone'] as String?,
    );
  }
}
