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
    this.reviews = 49,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final clinics = switch (json['clinics']) {
      List<dynamic> value => value.cast<String>(),
      _ => const <String>[],
    };
    final specialties = switch (json['specialties']) {
      List<dynamic> value => value.cast<String>(),
      _ => const <String>[],
    };
    final rating = (json['rating'] is num) ? (json['rating'] as num).toDouble() : 4.8;
    final reviews = (json['reviews'] is num) ? (json['reviews'] as num).toInt() : 49;
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
    );
  }
}
