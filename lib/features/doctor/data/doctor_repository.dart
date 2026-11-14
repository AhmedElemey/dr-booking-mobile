import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/doctor.dart';
import '../domain/doctor_slots.dart';

class DoctorRepository {
  DoctorRepository(this._dio);

  /// The API accepts at most 14 days per slot query.
  static const slotWindowDays = 14;

  final Dio _dio;

  ApiResult<Doctor> doctor(String idOrSlug) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/doctors/$idOrSlug');
    return Doctor.fromJson(response.data!);
  });

  /// Open slots from [from] for the next [slotWindowDays] days. Dates are
  /// clinic-local calendar dates (`yyyy-MM-dd`).
  ApiResult<DoctorSlots> slots(String idOrSlug, {required DateTime from}) =>
      guardApi(() async {
        final to = from.add(const Duration(days: slotWindowDays - 1));
        final response = await _dio.get<Map<String, dynamic>>(
          '/doctors/$idOrSlug/slots',
          queryParameters: {'from': _date(from), 'to': _date(to)},
        );
        return DoctorSlots.fromJson(response.data!);
      });

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final doctorRepositoryProvider = Provider<DoctorRepository>(
  (ref) => DoctorRepository(ref.watch(dioProvider)),
);
