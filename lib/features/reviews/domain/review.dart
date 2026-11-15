/// `rating: {average, count}` on a doctor.
class DoctorRating {
  const DoctorRating({required this.average, required this.count});

  final double average;
  final int count;

  static DoctorRating? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final average = (json['average'] as num?)?.toDouble();
    final count = (json['count'] as num?)?.toInt();
    if (average == null || count == null || count <= 0) return null;
    return DoctorRating(average: average, count: count);
  }
}

/// A published review in `GET /doctors/{idOrSlug}/reviews`.
class DoctorReview {
  const DoctorReview({
    required this.rating,
    required this.createdAt,
    this.comment,
    this.patientFirstName,
    this.reply,
  });

  final int rating;
  final String? comment;
  final String? patientFirstName;
  final DateTime createdAt;
  final String? reply;

  factory DoctorReview.fromJson(Map<String, dynamic> json) => DoctorReview(
    rating: (json['rating'] as num).toInt(),
    comment: json['comment'] as String?,
    patientFirstName: json['patientFirstName'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    reply: json['reply'] as String?,
  );
}

/// The patient's own review of an appointment (`review` on the appointment).
class AppointmentReview {
  const AppointmentReview({required this.rating, this.comment});

  final int rating;
  final String? comment;

  static AppointmentReview? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return AppointmentReview(
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
    );
  }
}
