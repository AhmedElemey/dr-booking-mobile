import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/promotion.dart';

class PromotionsRepository {
  PromotionsRepository(this._dio);

  final Dio _dio;

  ApiResult<List<Promotion>> offers() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/promotions');
    return [
      for (final p in response.data!)
        Promotion.fromJson(p as Map<String, dynamic>),
    ];
  });

  /// A refused code is a normal answer (`valid: false` with a `reason`), not a
  /// failure.
  ApiResult<CouponValidation> validate(
    String code, {
    required String doctorId,
    String? serviceId,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/coupons/validate',
      data: {'code': code, 'doctorId': doctorId, 'serviceId': ?serviceId},
    );
    return CouponValidation.fromJson(code, response.data!);
  });
}

final promotionsRepositoryProvider = Provider<PromotionsRepository>(
  (ref) => PromotionsRepository(ref.watch(dioProvider)),
);
