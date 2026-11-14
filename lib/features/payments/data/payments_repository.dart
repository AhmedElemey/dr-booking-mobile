import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/payment.dart';

class PaymentsRepository {
  PaymentsRepository(this._dio);

  final Dio _dio;

  /// Starts an online payment; [returnUrl] is where the checkout sends the
  /// patient back to (the app's `<applicationId>://payment-return`).
  ApiResult<Checkout> pay(String appointmentId, {required String returnUrl}) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/appointments/$appointmentId/pay',
          data: {'returnUrl': returnUrl},
        );
        return Checkout.fromJson(response.data!);
      });

  ApiResult<Payment> get(String paymentId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/payments/$paymentId',
    );
    return Payment.fromJson(response.data!);
  });
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(dioProvider)),
);
