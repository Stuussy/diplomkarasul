class Clinic {
  final String id;
  final String name;
  final String? description;
  final String? city;
  final String? address;
  final ClinicContacts? contacts;
  final List<ClinicWorkingHour> workingHours;
  final String status;
  final List<ClinicService> services;
  final List<String> doctors;
  final List<double> coordinates;
  final String? taxiDeepLink;
  final String? qrPayload;
  final DateTime? qrUpdatedAt;

  const Clinic({
    required this.id,
    required this.name,
    required this.coordinates,
    required this.status,
    required this.workingHours,
    required this.services,
    required this.doctors,
    this.description,
    this.city,
    this.address,
    this.contacts,
    this.taxiDeepLink,
    this.qrPayload,
    this.qrUpdatedAt,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    final qr = json['qr'] as Map<String, dynamic>?;
    final contactsJson = json['contacts'] as Map<String, dynamic>?;
    return Clinic(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      contacts: contactsJson != null ? ClinicContacts.fromJson(contactsJson) : null,
      workingHours: (json['workingHours'] as List<dynamic>? ?? [])
          .map((item) => ClinicWorkingHour.fromJson(item as Map<String, dynamic>))
          .toList(),
      status: json['status'] ?? 'draft',
      services: (json['services'] as List<dynamic>? ?? [])
          .map((item) => ClinicService.fromJson(item as Map<String, dynamic>))
          .toList(),
      doctors: (json['doctors'] as List<dynamic>? ?? []).map((id) => id.toString()).toList(),
      coordinates: (json['location']?['coordinates'] as List?)?.cast<double>() ?? [0, 0],
      taxiDeepLink: json['taxiDeepLink'] as String?,
      qrPayload: qr?['payload'] as String?,
      qrUpdatedAt: qr?['updatedAt'] != null ? DateTime.parse(qr!['updatedAt'] as String) : null,
    );
  }
}

class ClinicContacts {
  final String? phone;
  final String? email;

  const ClinicContacts({this.phone, this.email});

  factory ClinicContacts.fromJson(Map<String, dynamic> json) {
    return ClinicContacts(
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}

class ClinicWorkingHour {
  final int day;
  final String? open;
  final String? close;
  final bool isClosed;

  const ClinicWorkingHour({
    required this.day,
    this.open,
    this.close,
    required this.isClosed,
  });

  factory ClinicWorkingHour.fromJson(Map<String, dynamic> json) {
    return ClinicWorkingHour(
      day: json['day'] ?? 0,
      open: json['open'] as String?,
      close: json['close'] as String?,
      isClosed: json['isClosed'] ?? false,
    );
  }
}

class ClinicService {
  final String id;
  final String name;
  final int price;
  final int durationMinutes;
  final String? description;
  final bool isActive;

  const ClinicService({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
    this.description,
  });

  factory ClinicService.fromJson(Map<String, dynamic> json) {
    return ClinicService(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
      durationMinutes: json['durationMinutes'] ?? 30,
      description: json['description'] as String?,
      isActive: json['isActive'] ?? true,
    );
  }
}
