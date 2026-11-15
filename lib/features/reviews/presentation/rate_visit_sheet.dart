import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointments_providers.dart';
import '../data/reviews_repository.dart';

/// "Rate your visit": stars and an optional comment. Resolves true once the
/// review is saved (it can only be sent once per appointment).
Future<bool?> showRateVisitSheet(
  BuildContext context,
  Appointment appointment,
) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => RateVisitSheet(appointment: appointment),
);

class RateVisitSheet extends ConsumerStatefulWidget {
  const RateVisitSheet({super.key, required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<RateVisitSheet> createState() => _RateVisitSheetState();
}

class _RateVisitSheetState extends ConsumerState<RateVisitSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_rating == 0) {
      setState(() => _error = l10n.selectRating);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final id = widget.appointment.id;
    final result = await ref
        .read(reviewsRepositoryProvider)
        .submit(id, rating: _rating, comment: _comment.text);
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _sending = false;
          _error = l10n.failureMessage(failure);
        });
        // The visit was already rated (maybe on another device): refresh it.
        if (failure.code == 'ALREADY_REVIEWED' ||
            failure.code == 'NOT_REVIEWABLE') {
          invalidateAppointments(ref, id: id);
        }
      },
      (_) {
        invalidateAppointments(ref, id: id);
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.rateYourVisit,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ratingPrompt(widget.appointment.doctor.name),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            StarPicker(
              value: _rating,
              onChanged: (value) => setState(() {
                _rating = value;
                _error = null;
              }),
            ),
            TextField(
              key: const Key('reviewComment'),
              controller: _comment,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(hintText: l10n.reviewCommentHint),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                key: const Key('reviewError'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('submitReview'),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.submitReview),
            ),
          ],
        ),
      ),
    );
  }
}
