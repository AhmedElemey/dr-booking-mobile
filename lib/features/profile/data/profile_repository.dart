import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../../auth/domain/app_user.dart';

/// `PUT /me` and the FCM device-token endpoints.
class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  ApiResult<AppUser> updateMe({String? fullName, String? preferredLanguage}) =>
      guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/me',
          data: {
            'fullName': ?fullName,
            'preferredLanguage': ?preferredLanguage,
          },
        );
        final data = response.data;
        if (data != null && data['id'] != null) return AppUser.fromJson(data);
        // The update succeeded but the body is not the user: read it back.
        final fresh = await _dio.get<Map<String, dynamic>>('/me');
        return AppUser.fromJson(fresh.data!);
      });

  /// Idempotent by token; returns the id to unregister with.
  ApiResult<String> registerDeviceToken(String token, String platform) =>
      guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/me/device-tokens',
          data: {'token': token, 'platform': platform},
        );
        return response.data!['id'] as String;
      });

  ApiResult<void> unregisterDeviceToken(String id) => guardApi(() async {
    await _dio.delete<void>('/me/device-tokens/$id');
  });
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);
