import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../../../core/network/paged.dart';
import '../../insurance/domain/insurance.dart';
import '../domain/appointment.dart';

enum AppointmentScope { upcoming, past }

/// Booking (`POST /appointments`) and the patient's own appointments.
class AppointmentsRepository {
  AppointmentsRepository(this._dio);

  static const pageSize = 20;

  final Dio _dio;

  ApiResult<Appointment> book({
    required String slotId,
    String? serviceId,
    String? note,
    String? familyMemberId,
    AppointmentMode? mode,
    InsuranceChoice? insurance,
    String? couponCode,
  }) => guardApi(() async {
    final trimmed = note?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '/appointments',
      data: {
        'slotId': slotId,
        'serviceId': ?serviceId,
        if (trimmed != null && trimmed.isNotEmpty) 'patientNote': trimmed,
        'familyMemberId': ?familyMemberId,
        if (mode != null && mode != AppointmentMode.inPerson) 'mode': mode.wire,
        if (insurance != null) 'insurance': insurance.toJson(),
        'couponCode': ?couponCode,
      },
    );
    return Appointment.fromJson(response.data!);
  });

  ApiResult<Paged<Appointment>> list(AppointmentScope scope, {int page = 1}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/appointments',
          queryParameters: {
            'scope': scope.name,
            'page': page,
            'pageSize': pageSize,
          },
        );
        return Paged.fromJson(response.data!, Appointment.fromJson);
      });

  ApiResult<Appointment> get(String id) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/appointments/$id');
    return Appointment.fromJson(response.data!);
  });

  /// Returns the refreshed appointment (the endpoint may answer with an empty
  /// body, in which case it is read back).
  ApiResult<Appointment> cancel(String id, {String? reason}) =>
      guardApi(() async {
        final trimmed = reason?.trim();
        final response = await _dio.post<Map<String, dynamic>>(
          '/appointments/$id/cancel',
          data: {if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed},
        );
        return _orReload(id, response.data);
      });

  ApiResult<Appointment> reschedule(String id, {required String slotId}) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/appointments/$id/reschedule',
          data: {'slotId': slotId},
        );
        return _orReload(id, response.data);
      });

  Future<Appointment> _orReload(String id, Map<String, dynamic>? body) async {
    if (body != null && body['id'] != null && body['doctor'] != null) {
      return Appointment.fromJson(body);
    }
    final response = await _dio.get<Map<String, dynamic>>('/appointments/$id');
    return Appointment.fromJson(response.data!);
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => AppointmentsRepository(ref.watch(dioProvider)),
);
