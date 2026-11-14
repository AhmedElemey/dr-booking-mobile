import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/patient_records.dart';

class RecordsRepository {
  RecordsRepository(this._dio);

  final Dio _dio;

  /// The signed-in patient's records, or a family member's.
  ApiResult<PatientRecords> mine({String? familyMemberId}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/me/records',
          queryParameters: {'familyMemberId': ?familyMemberId},
        );
        return PatientRecords.fromJson(response.data!);
      });
}

final recordsRepositoryProvider = Provider<RecordsRepository>(
  (ref) => RecordsRepository(ref.watch(dioProvider)),
);
