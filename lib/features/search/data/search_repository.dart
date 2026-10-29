import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../../../core/network/paged.dart';
import '../../doctor/domain/doctor.dart';
import '../domain/doctor_query.dart';
import '../domain/specialty.dart';

/// Public catalog: specialties, cities and doctor search.
class SearchRepository {
  SearchRepository(this._dio);

  static const pageSize = 20;

  final Dio _dio;

  ApiResult<List<Specialty>> specialties() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/specialties');
    return [
      for (final s in response.data!)
        Specialty.fromJson(s as Map<String, dynamic>),
    ];
  });

  /// Cities may come back as plain strings or as `{name}` objects.
  ApiResult<List<String>> cities() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/cities');
    return [
      for (final c in response.data!)
        if (c is String) c else (c as Map<String, dynamic>)['name'] as String,
    ];
  });

  ApiResult<Paged<Doctor>> doctors(DoctorQuery query, {int page = 1}) =>
      guardApi(() async {
        final text = query.text?.trim();
        final response = await _dio.get<Map<String, dynamic>>(
          '/doctors',
          queryParameters: {
            'specialtyId': ?query.specialtyId,
            'city': ?query.city,
            if (text != null && text.isNotEmpty) 'q': text,
            'page': page,
            'pageSize': pageSize,
          },
        );
        return Paged.fromJson(response.data!, Doctor.fromJson);
      });
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(dioProvider)),
);
