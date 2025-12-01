import 'user.dart';

class Review {
  Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.patient,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final AppUser? patient;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['_id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
      patient:
          json['patient'] != null ? AppUser.fromJson(json['patient'] as Map<String, dynamic>) : null,
    );
  }
}
