import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/family_member.dart';
import 'family_providers.dart';
import 'family_screen.dart';

/// "Booking for": me or one of the family members (or add a new one).
class BookingForPicker extends ConsumerWidget {
  const BookingForPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final FamilyMember? selected;
  final ValueChanged<FamilyMember?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final members = ref.watch(familyMembersProvider).value ?? const [];
    return Column(
      key: const Key('bookingFor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.bookingFor, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoiceChip(
                showCheckmark: false,
                labelPadding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                selectedColor: theme.colorScheme.primary,
                checkmarkColor: theme.colorScheme.onPrimary,
                labelStyle: TextStyle(
                  color: selected == null
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
                key: const Key('for-me'),
                avatar: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: selected == null
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
                label: SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.55,
                  child: Text(l10n.bookingForMe),
                ),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
              const SizedBox(height: 8),
              for (final member in members) ...[
                ChoiceChip(
                  showCheckmark: false,
                  labelPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  selectedColor: theme.colorScheme.primary,
                  checkmarkColor: theme.colorScheme.onPrimary,
                  labelStyle: TextStyle(
                    color: selected?.id == member.id
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  key: Key('for-${member.id}'),
                  avatar: Icon(
                    member.relation == FamilyRelation.child
                        ? Icons.child_care
                        : Icons.person_outline,
                    size: 18,
                    color: selected?.id == member.id
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  label: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.55,
                    child: Text(
                      '${member.fullName} (${l10n.relationName(member.relation)})',
                    ),
                  ),
                  selected: selected?.id == member.id,
                  onSelected: (_) => onSelected(member),
                ),
                const SizedBox(height: 8),
              ],
              ActionChip(
                key: const Key('addMemberChip'),
                avatar: const Icon(Icons.add, size: 18),
                label: SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.55,
                  child: Text(l10n.addFamilyMember),
                ),
                onPressed: () async {
                  final saved = await showFamilyMemberSheet(context, ref);
                  if (saved == true) ref.invalidate(familyMembersProvider);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
