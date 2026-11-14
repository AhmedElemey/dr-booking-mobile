import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/brand.g.dart';
import '../../appointments/presentation/appointments_providers.dart';
import '../data/payments_repository.dart';
import '../domain/payment.dart';

/// A checkout the patient left the app for and has not come back from yet.
class PendingPayment {
  const PendingPayment({required this.paymentId, required this.appointmentId});

  final String paymentId;
  final String appointmentId;
}

/// Starts online payments and settles them when the patient returns, either
/// through the `payment-return` link or, failing that, by polling
/// `GET /payments/{id}` when the app resumes.
class PaymentFlow extends Notifier<PendingPayment?> {
  @override
  PendingPayment? build() => null;

  /// `POST /appointments/{id}/pay`; remembers the payment until it settles.
  Future<Checkout> start(String appointmentId) async {
    final result = await ref
        .read(paymentsRepositoryProvider)
        .pay(appointmentId, returnUrl: Brand.paymentReturnUrl);
    final checkout = result.fold<Checkout>((f) => throw f, (c) => c);
    state = PendingPayment(
      paymentId: checkout.paymentId,
      appointmentId: appointmentId,
    );
    return checkout;
  }

  /// Reads the pending payment back from the API. A final status (paid, failed)
  /// ends the wait; the appointment lists reload either way.
  Future<Payment?> refreshPending() async {
    final pending = state;
    if (pending == null) return null;
    final result = await ref
        .read(paymentsRepositoryProvider)
        .get(pending.paymentId);
    return result.fold(
      (failure) {
        debugPrint('payment refresh failed: $failure');
        return null;
      },
      (payment) {
        if (!ref.mounted) return payment;
        ref.invalidate(appointmentListProvider);
        ref.invalidate(appointmentProvider(payment.appointmentId));
        if (payment.status.isFinal) state = null;
        return payment;
      },
    );
  }

  void clear() => state = null;
}

final paymentFlowProvider = NotifierProvider<PaymentFlow, PendingPayment?>(
  PaymentFlow.new,
);

/// The route the app opens for `<applicationId>://payment-return?...`, or null
/// when [uri] is something else.
String? paymentReturnLocation(Uri uri) {
  final isReturn =
      uri.host == 'payment-return' ||
      uri.path == '/payment-return' ||
      uri.path == 'payment-return';
  if (!isReturn) return null;
  final q = uri.queryParameters;
  return Uri(
    path: '/payment-return',
    queryParameters: {
      if (q['paymentId'] != null) 'paymentId': q['paymentId']!,
      if (q['status'] != null) 'status': q['status']!,
    },
  ).toString();
}
