import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../domain/promotion.dart';
import 'promotions_providers.dart';

/// The "Offers" section of the home screen: a horizontal strip of public
/// promotions. Hidden when the feature is off, while loading, when there are
/// none, and when they cannot be loaded.
class OffersStrip extends ConsumerWidget {
  const OffersStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(featuresProvider.select((f) => f.promotions));
    if (!enabled) return const SizedBox.shrink();
    final offers = ref.watch(promotionsProvider).value;
    if (offers == null || offers.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      key: const Key('offersStrip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(l10n.offersTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => OfferCard(offer: offers[index]),
          ),
        ),
      ],
    );
  }
}

class OfferCard extends ConsumerWidget {
  const OfferCard({super.key, required this.offer});

  final Promotion offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final number = NumberFormat.decimalPattern(locale);
    final value = offer.discountType == DiscountType.percent
        ? l10n.offerPercent(number.format(offer.value))
        : l10n.offerFixed(number.format(offer.value));
    final scheme = theme.colorScheme;
    return SizedBox(
      width: 264,
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('offer-${offer.code}'),
          onTap: () {
            ref.read(selectedCouponProvider.notifier).select(offer.code);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.offerSaved(offer.code))),
            );
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  offer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
                if ((offer.description ?? '').isNotEmpty)
                  Text(
                    offer.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.onPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          offer.code,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (offer.validTo != null)
                      Flexible(
                        child: Text(
                          l10n.offerValidUntil(
                            DateFormat.MMMd(locale)
                                .format(ClinicTime.parseDate(offer.validTo!)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
