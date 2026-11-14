import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../core/l10n/generated/app_localizations.dart';
import '../../features/reviews/domain/review.dart';

const _starColor = Color(0xFFF5A623);

/// Five read-only stars for a rating of 0 to 5 (halves are rounded).
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, this.size = 18});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rounded = (value * 2).round() / 2;
    return Semantics(
      label: l10n.ratingSemantics(rounded.toString()),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              rounded >= i
                  ? Icons.star_rounded
                  : rounded >= i - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: size,
              color: _starColor,
            ),
        ],
      ),
    );
  }
}

/// `★ 4.8 (126)`, as shown on doctor cards and the profile.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.large = false});

  final DoctorRating rating;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final style = large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodySmall;
    final average = NumberFormat('0.0', locale).format(rating.average);
    return Row(
      key: const Key('ratingBadge'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: large ? 22 : 16, color: _starColor),
        const SizedBox(width: 2),
        Text(average, style: style?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(
          l10n.ratingCount(rating.count),
          style: style?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Five tappable stars for choosing a rating.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            key: Key('star-$i'),
            tooltip: l10n.ratingSemantics('$i'),
            iconSize: 40,
            onPressed: () => onChanged(i),
            icon: Icon(
              value >= i ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _starColor,
            ),
          ),
      ],
    );
  }
}
