import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/paged_list_view.dart';
import 'review_tile.dart';
import 'reviews_providers.dart';

/// Every published review of one doctor.
class DoctorReviewsScreen extends ConsumerWidget {
  const DoctorReviewsScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = doctorReviewsProvider(slug);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewsTitle)),
      body: PagedListView(
        value: ref.watch(provider),
        onLoadMore: ref.read(provider.notifier).loadMore,
        onRefresh: () => ref.refresh(provider.future),
        empty: EmptyView(
          icon: Icons.star_border_rounded,
          message: l10n.noReviews,
        ),
        itemBuilder: (context, review) => ReviewTile(review: review),
      ),
    );
  }
}
