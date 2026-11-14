import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env_provider.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/network/dio_provider.dart';
import '../../appointments/domain/appointment.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../domain/payment.dart';
import 'payment_flow.dart';

/// "Pay online" for an upcoming, unpaid appointment; hidden when the clinic has
/// online payments off or there is nothing to pay.
class PayOnlineButton extends ConsumerStatefulWidget {
  const PayOnlineButton({super.key, required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<PayOnlineButton> createState() => _PayOnlineButtonState();
}

class _PayOnlineButtonState extends ConsumerState<PayOnlineButton> {
  bool _busy = false;

  Future<void> _pay() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final appointment = widget.appointment;
    setState(() => _busy = true);
    try {
      final checkout = await ref
          .read(paymentFlowProvider.notifier)
          .start(appointment.id);
      if (!mounted) return;
      if (ref.read(envProvider).useMockApi) {
        await _demoCheckout(checkout, appointment);
        return;
      }
      final opened = await ref.read(urlOpenerProvider)(
        Uri.parse(checkout.checkoutUrl),
        inApp: true,
      );
      if (!opened) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenLink)));
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Demo mode has no provider page, so a sheet plays its part.
  Future<void> _demoCheckout(Checkout checkout, Appointment appointment) async {
    final l10n = AppLocalizations.of(context);
    final amount = (appointment.totalEgp ?? 0);
    final outcome = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.demoCheckoutTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(l10n.demoCheckoutBody),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('demoPay'),
              onPressed: () => Navigator.of(context).pop('paid'),
              child: Text(l10n.demoPay(l10n.priceEgp(amount))),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('demoFail'),
              onPressed: () => Navigator.of(context).pop('failed'),
              child: Text(l10n.demoFail),
            ),
          ],
        ),
      ),
    );
    if (outcome == null || !mounted) return;
    final response = await ref
        .read(dioProvider)
        .post<Map<String, dynamic>>(
          '/payments/mock-checkout/${checkout.paymentId}',
          data: {'outcome': outcome},
        );
    if (!mounted) return;
    final target = paymentReturnLocation(
      Uri.parse(response.data!['returnUrl'] as String),
    );
    if (target != null) context.push(target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(featuresProvider.select((f) => f.onlinePayments));
    if (!enabled || !widget.appointment.canPayOnline) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      key: const Key('payOnline'),
      onPressed: _busy ? null : _pay,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.credit_card),
      label: Text(l10n.payOnline),
    );
  }
}
