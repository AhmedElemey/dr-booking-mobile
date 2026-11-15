import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../../../core/network/paged.dart';
import '../domain/review.dart';

class ReviewsRepository {
  ReviewsRepository(this._dio);

  static const pageSize = 10;

  final Dio _dio;

  ApiResult<Paged<DoctorReview>> forDoctor(String idOrSlug, {int page = 1}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/doctors/$idOrSlug/reviews',
          queryParameters: {'page': page, 'pageSize': pageSize},
        );
        return Paged.fromJson(response.data!, DoctorReview.fromJson);
      });

  /// Once per completed appointment (`ALREADY_REVIEWED` / `NOT_REVIEWABLE`).
  ApiResult<void> submit(
    String appointmentId, {
    required int rating,
    String? comment,
  }) => guardApi(() async {
    final trimmed = comment?.trim();
    await _dio.post<void>(
      '/appointments/$appointmentId/review',
      data: {
        'rating': rating,
        if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
      },
    );
  });
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(ref.watch(dioProvider)),
);
