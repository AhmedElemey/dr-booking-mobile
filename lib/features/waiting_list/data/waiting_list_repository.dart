import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/waiting_entry.dart';

class WaitingListRepository {
  WaitingListRepository(this._dio);

  final Dio _dio;

  /// [date] is a clinic-local `yyyy-MM-dd`.
  ApiResult<WaitingEntry> join({
    required String doctorId,
    required String date,
    String? serviceId,
    String? familyMemberId,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/waiting-list',
      data: {
        'doctorId': doctorId,
        'date': date,
        'serviceId': ?serviceId,
        'familyMemberId': ?familyMemberId,
      },
    );
    return WaitingEntry.fromJson(response.data!);
  });

  ApiResult<List<WaitingEntry>> mine() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/waiting-list');
    return [
      for (final e in response.data!)
        WaitingEntry.fromJson(e as Map<String, dynamic>),
    ];
  });

  ApiResult<void> leave(String id) => guardApi(() async {
    await _dio.delete<void>('/waiting-list/$id');
  });
}

final waitingListRepositoryProvider = Provider<WaitingListRepository>(
  (ref) => WaitingListRepository(ref.watch(dioProvider)),
);
