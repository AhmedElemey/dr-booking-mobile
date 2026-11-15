import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/insurance.dart';

class InsuranceRepository {
  InsuranceRepository(this._dio);

  final Dio _dio;

  /// Active providers, for the doctor-list filter.
  ApiResult<List<InsuranceProvider>> providers() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/insurance-providers');
    return [
      for (final p in response.data!)
        InsuranceProvider.fromJson(p as Map<String, dynamic>),
    ];
  });
}

final insuranceRepositoryProvider = Provider<InsuranceRepository>(
  (ref) => InsuranceRepository(ref.watch(dioProvider)),
);
