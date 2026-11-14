import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/video_room.dart';

class VideoRepository {
  VideoRepository(this._dio);

  final Dio _dio;

  /// `VIDEO_NOT_OPEN` (409) outside the join window.
  ApiResult<VideoRoom> room(String appointmentId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/appointments/$appointmentId/video',
    );
    return VideoRoom.fromJson(response.data!);
  });
}

final videoRepositoryProvider = Provider<VideoRepository>(
  (ref) => VideoRepository(ref.watch(dioProvider)),
);
