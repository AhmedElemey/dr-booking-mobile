import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/failure.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_view.dart';
import '../../appointments/presentation/appointments_providers.dart';
import '../data/payments_repository.dart';
import '../domain/payment.dart';
import 'payment_flow.dart';

/// Where `<applicationId>://payment-return?paymentId=..&status=..` lands. The
/// query only says how the checkout ended; the payment itself is read from the
/// API (the webhook may arrive a moment later, so a pending payment is retried).
class PaymentReturnScreen extends ConsumerStatefulWidget {
  const PaymentReturnScreen({super.key, this.paymentId});

  final String? paymentId;

  @override
  ConsumerState<PaymentReturnScreen> createState() =>
      _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends ConsumerState<PaymentReturnScreen> {
  Payment? _payment;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.paymentId ?? ref.read(paymentFlowProvider)?.paymentId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = const Failure(code: 'NOT_FOUND');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    for (var attempt = 0; attempt < 4; attempt++) {
      final result = await ref.read(paymentsRepositoryProvider).get(id);
      if (!mounted) return;
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) {
        setState(() {
          _loading = false;
          _error = failure;
        });
        return;
      }
      final payment = result.toNullable()!;
      setState(() => _payment = payment);
      if (payment.status.isFinal) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    final payment = _payment;
    ref.invalidate(appointmentListProvider);
    if (payment != null) {
      ref.invalidate(appointmentProvider(payment.appointmentId));
      if (payment.status.isFinal) {
        ref.read(paymentFlowProvider.notifier).clear();
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final payment = _payment;
    final (icon, color, message) = switch (payment?.status) {
      PaymentStatus.paid => (
        Icons.check_circle,
        theme.colorScheme.primary,
        l10n.paymentResultPaid,
      ),
      PaymentStatus.failed || PaymentStatus.cancelled => (
        Icons.error_outline,
        theme.colorScheme.error,
        l10n.paymentResultFailed,
      ),
      _ => (
        Icons.hourglass_top,
        theme.colorScheme.outline,
        l10n.paymentResultPending,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentResultTitle)),
      body: _error != null && payment == null
          ? ErrorView(error: _error!, onRetry: _load)
          : Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_loading && !(payment?.status.isFinal ?? false))
                      const CircularProgressIndicator()
                    else
                      Icon(icon, size: 80, color: color),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      key: const Key('paymentResult'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (payment != null) ...[
                      const SizedBox(height: 8),
                      Text(l10n.priceEgp(payment.amountEgp)),
                    ],
                    const SizedBox(height: 28),
                    if (payment != null)
                      FilledButton(
                        key: const Key('viewPaidAppointment'),
                        onPressed: () => context.go(
                          '/appointments/${payment.appointmentId}',
                        ),
                        child: Text(l10n.viewAppointment),
                      )
                    else
                      FilledButton(
                        onPressed: () => context.go('/appointments'),
                        child: Text(l10n.viewMyAppointments),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
