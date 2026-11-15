import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../domain/review.dart';

/// One published review with the clinic's reply, if any.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final DoctorReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RatingStars(value: review.rating.toDouble(), size: 16),
                const Spacer(),
                Text(
                  DateFormat.yMMMd(locale).format(review.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if ((review.patientFirstName ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.patientFirstName!, style: theme.textTheme.titleSmall),
            ],
            if ((review.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(review.comment!),
            ],
            if ((review.reply ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.clinicReply,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(review.reply!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
