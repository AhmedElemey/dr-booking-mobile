import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../features/clinic_config/presentation/features_controller.dart';
import '../../features/doctor/domain/doctor.dart';
import 'doctor_avatar.dart';
import 'pill.dart';
import 'rating_stars.dart';

class DoctorCard extends ConsumerWidget {
  const DoctorCard({super.key, required this.doctor, required this.onTap});

  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(featuresProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final details = <String>[
      ?doctor.specialty?.name,
      if (doctor.yearsExperience != null)
        l10n.yearsExperience(doctor.yearsExperience!),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(18),
          child: Row(
            children: [
              DoctorAvatar(name: doctor.name, photoUrl: doctor.photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details.join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if ((features.reviews && doctor.rating != null) ||
                        (features.videoConsultation && doctor.offersVideo)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (features.reviews && doctor.rating != null)
                            RatingBadge(rating: doctor.rating!),
                          if (features.videoConsultation && doctor.offersVideo)
                            Pill(
                              key: const Key('videoBadge'),
                              label: l10n.videoBadge,
                              color: theme.colorScheme.primary,
                              icon: Icons.videocam_outlined,
                            ),
                        ],
                      ),
                    ],
                    if (doctor.clinic != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              doctor.clinic!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (doctor.consultationFeeEgp != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.consultationFee(
                          l10n.priceEgp(doctor.consultationFeeEgp!),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
