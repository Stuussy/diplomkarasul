import 'user.dart';

class Review {
  Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.patient,
    this.doctor,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final AppUser? patient;
  final AppUser? doctor;

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
      doctor: json['doctor'] is Map<String, dynamic>
          ? AppUser.fromJson(json['doctor'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Сводка отзывов о клинике: средняя оценка, количество и последние отзывы.
class ClinicReviews {
  ClinicReviews({required this.average, required this.count, required this.reviews});

  final double average;
  final int count;
  final List<Review> reviews;

  factory ClinicReviews.fromJson(Map<String, dynamic> json) {
    final list = (json['reviews'] as List<dynamic>? ?? [])
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
    return ClinicReviews(
      average: (json['average'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      reviews: list,
    );
  }
}
