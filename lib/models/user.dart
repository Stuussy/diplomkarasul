class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? phone;
  final List<String> specialties;
  final List<String> clinics;
  final double rating;
  final int reviews;
  final List<String> services;
  final int experienceYears;
  final String? bio;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.phone,
    this.specialties = const [],
    this.clinics = const [],
    this.rating = 4.8,
    this.reviews = 0,
    this.services = const [],
    this.experienceYears = 0,
    this.bio,
    this.isActive = true,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory AppUser.fromJson(Map<String, dynamic> json) {
    List<String> parseClinics(dynamic raw) {
      if (raw is List) {
        return raw
            .map((item) {
              if (item is String) return item;
              if (item is Map<String, dynamic>) {
                final name = item['name']?.toString();
                if (name != null && name.isNotEmpty) return name;
                final address = item['address']?.toString();
                if (address != null && address.isNotEmpty) return address;
                final id = item['_id']?.toString();
                return id ?? '';
              }
              return item?.toString() ?? '';
            })
            .where((value) => value.isNotEmpty)
            .toList();
      }
      return <String>[];
    }

    final clinics = parseClinics(json['clinics']);
    final specialties = switch (json['specialties']) {
      List<dynamic> value => value.cast<String>(),
      _ => const <String>[],
    };
    final services = switch (json['services']) {
      List<dynamic> value => value.cast<String>(),
      _ => const <String>[],
    };
    final rating = (json['rating'] is num) ? (json['rating'] as num).toDouble() : 4.8;
    final reviews = (json['reviews'] is num) ? (json['reviews'] as num).toInt() : 0;
    return AppUser(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'patient',
      phone: json['phone'] as String?,
      specialties: specialties,
      clinics: clinics,
      rating: rating,
      reviews: reviews,
      services: services,
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      bio: json['bio'] as String?,
      isActive: json['isActive'] ?? true,
    );
  }
}
