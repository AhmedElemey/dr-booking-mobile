import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/pill.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../insurance/domain/insurance.dart';
import '../../payments/domain/payment.dart';
import '../../payments/presentation/payment_actions.dart';
import '../../reviews/presentation/rate_visit_sheet.dart';
import '../domain/appointment.dart';

/// Price, discount and total, with the payment status and "Pay online".
/// Shown when the clinic uses online payments or promotions.
class PriceCard extends ConsumerWidget {
  const PriceCard({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final features = ref.watch(featuresProvider);
    final price = appointment.priceEgp;
    if (price == null || !(features.onlinePayments || features.promotions)) {
      return const SizedBox.shrink();
    }
    final total = appointment.totalEgp ?? price;
    final status = appointment.paymentStatus;
    final statusColor = switch (status) {
      AppointmentPaymentStatus.paid => Colors.green,
      AppointmentPaymentStatus.pending => Colors.orange,
      AppointmentPaymentStatus.refunded => Colors.blueGrey,
      AppointmentPaymentStatus.unpaid => Colors.red,
    };
    return Card(
      key: const Key('priceCard'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.paymentSection,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (features.onlinePayments)
                  Pill(
                    key: const Key('paymentStatus'),
                    label: l10n.paymentStatusName(status),
                    color: statusColor,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _AmountRow(label: l10n.priceLabel, value: l10n.priceEgp(price)),
            if (appointment.discountEgp > 0)
              _AmountRow(
                label: l10n.discountLabel,
                value: l10n.priceEgp(appointment.discountEgp),
                color: Colors.green.shade700,
              ),
            const Divider(height: 20),
            _AmountRow(
              label: l10n.totalLabel,
              value: l10n.priceEgp(total),
              bold: true,
            ),
            if (!features.onlinePayments) ...[
              const SizedBox(height: 8),
              Text(l10n.payAtClinic, style: theme.textTheme.bodySmall),
            ],
            if (features.onlinePayments && appointment.canPayOnline) ...[
              const SizedBox(height: 14),
              PayOnlineButton(appointment: appointment),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// The insurance the patient entered and the clinic's answer.
class InsuranceCard extends StatelessWidget {
  const InsuranceCard({super.key, required this.insurance});

  final AppointmentInsurance insurance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = switch (insurance.status) {
      InsuranceStatus.approved => Colors.green,
      InsuranceStatus.rejected => Colors.red,
      InsuranceStatus.pending => Colors.orange,
    };
    return Card(
      key: const Key('insuranceCard'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insurance.provider.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Pill(
                  key: const Key('insuranceStatus'),
                  label: l10n.insuranceStatusName(insurance.status),
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.insuranceMemberLabel}: ${insurance.memberNumber}',
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodyMedium,
            ),
            if ((insurance.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${l10n.insuranceClinicNote}: ${insurance.note}'),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Rate your visit" for a completed visit, or the patient's own review.
class ReviewSection extends ConsumerWidget {
  const ReviewSection({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enabled = ref.watch(featuresProvider.select((f) => f.reviews));
    if (!enabled) return const SizedBox.shrink();
    final review = appointment.review;
    if (review != null) {
      return Card(
        key: const Key('yourReview'),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.yourReview, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              RatingStars(value: review.rating.toDouble(), size: 22),
              if ((review.comment ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(review.comment!),
              ],
            ],
          ),
        ),
      );
    }
    if (!appointment.canReview) return const SizedBox.shrink();
    return Card(
      key: const Key('rateCard'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.rateYourVisit, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.ratingPrompt(appointment.doctor.name)),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('rateVisit'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final saved = await showRateVisitSheet(context, appointment);
                if (saved == true) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.reviewThanks)),
                  );
                }
              },
              icon: const Icon(Icons.star_rounded),
              label: Text(l10n.rateYourVisit),
            ),
          ],
        ),
      ),
    );
  }
}
