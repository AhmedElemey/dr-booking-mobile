import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/doctor_avatar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/pill.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../reviews/presentation/review_tile.dart';
import '../../reviews/presentation/reviews_providers.dart';
import '../domain/doctor.dart';
import 'doctor_providers.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final doctor = ref.watch(doctorProvider(slug));
    return Scaffold(
      appBar: AppBar(),
      body: doctor.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(doctorProvider(slug)),
        ),
        data: (doctor) => _ProfileBody(doctor: doctor, slug: slug),
      ),
      bottomNavigationBar: doctor.hasValue
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: FilledButton(
                  key: const Key('bookAppointment'),
                  onPressed: () => context.push('/doctors/$slug/slots'),
                  child: Text(l10n.bookAppointment),
                ),
              ),
            )
          : null,
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.doctor, required this.slug});

  final Doctor doctor;
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(featuresProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final clinic = doctor.clinic;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            DoctorAvatar(
              name: doctor.name,
              photoUrl: doctor.photoUrl,
              radius: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.name, style: theme.textTheme.headlineSmall),
                  if (doctor.specialty != null)
                    Text(
                      doctor.specialty!.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (doctor.yearsExperience != null)
                    Text(
                      l10n.yearsExperience(doctor.yearsExperience!),
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (features.reviews && doctor.rating != null) ...[
                    const SizedBox(height: 4),
                    RatingBadge(rating: doctor.rating!, large: true),
                  ],
                  if (features.videoConsultation && doctor.offersVideo) ...[
                    const SizedBox(height: 6),
                    Pill(
                      key: const Key('videoBadge'),
                      label: l10n.videoVisit,
                      color: theme.colorScheme.primary,
                      icon: Icons.videocam_outlined,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (doctor.consultationFeeEgp != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(
                l10n.consultationFee(l10n.priceEgp(doctor.consultationFeeEgp!)),
              ),
              subtitle: Text(
                features.onlinePayments
                    ? l10n.payOnlineOrClinic
                    : l10n.payAtClinic,
              ),
            ),
          ),
        ],
        if ((doctor.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.aboutSection, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(doctor.bio!, style: theme.textTheme.bodyLarge),
        ],
        if (clinic != null) ...[
          const SizedBox(height: 20),
          Text(l10n.clinicSection, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clinic.name, style: theme.textTheme.titleSmall),
                  if ((clinic.address ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(clinic.address!)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (features.insurance && doctor.insuranceProviders.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.insuranceLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('acceptedInsurers'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final insurer in doctor.insuranceProviders)
                Chip(
                  avatar: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 18,
                  ),
                  label: Text(insurer.name),
                ),
            ],
          ),
        ],
        if (doctor.services.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.servicesSection, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                for (final service in doctor.services)
                  ListTile(
                    title: Text(service.name),
                    subtitle: service.durationMinutes == null
                        ? null
                        : Text(l10n.minutesShort(service.durationMinutes!)),
                    trailing: service.priceEgp == null
                        ? null
                        : Text(l10n.priceEgp(service.priceEgp!)),
                  ),
              ],
            ),
          ),
        ],
        if (features.reviews) _ReviewsSection(doctor: doctor, slug: slug),
      ],
    );
  }
}

/// Rating summary, the latest reviews and a link to all of them.
class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.doctor, required this.slug});

  final Doctor doctor;
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reviews = ref.watch(doctorReviewsProvider(slug)).value?.items;
    return Column(
      key: const Key('reviewsSection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text(l10n.reviewsTitle, style: theme.textTheme.titleMedium),
            const Spacer(),
            if (doctor.rating != null)
              RatingBadge(rating: doctor.rating!, large: true),
          ],
        ),
        const SizedBox(height: 8),
        if (reviews == null)
          const SizedBox(height: 60, child: LoadingView())
        else if (reviews.isEmpty)
          Text(l10n.noReviews)
        else ...[
          for (final review in reviews.take(3)) ...[
            ReviewTile(review: review),
            const SizedBox(height: 8),
          ],
          TextButton(
            key: const Key('seeAllReviews'),
            onPressed: () => context.push('/doctors/$slug/reviews'),
            child: Text(l10n.seeAllReviews),
          ),
        ],
      ],
    );
  }
}
