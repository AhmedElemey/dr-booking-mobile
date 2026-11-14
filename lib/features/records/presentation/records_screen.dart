import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/network/failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../family/presentation/family_providers.dart';
import '../data/records_repository.dart';
import '../domain/patient_records.dart';

/// The records of the patient (or one family member), keyed by family member id
/// (null = the account owner).
final recordsProvider = FutureProvider.autoDispose
    .family<PatientRecords, String?>((ref, familyMemberId) {
      ref.watch(localeProvider);
      return ref
          .watch(recordsRepositoryProvider)
          .mine(familyMemberId: familyMemberId)
          .unwrap();
    });

/// "My records": medical information and the entries the clinic shares, with a
/// switcher for family members.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  String? _memberId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final familyOn = ref.watch(
      featuresProvider.select((f) => f.familyAccounts),
    );
    final members = familyOn
        ? ref.watch(familyMembersProvider).value ?? const []
        : const [];
    final records = ref.watch(recordsProvider(_memberId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordsTitle)),
      body: Column(
        children: [
          if (members.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                key: const Key('recordsSwitcher'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: const Key('records-me'),
                      label: Text(l10n.bookingForMe),
                      selected: _memberId == null,
                      onSelected: (_) => setState(() => _memberId = null),
                    ),
                  ),
                  for (final member in members)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        key: Key('records-${member.id}'),
                        label: Text(member.fullName),
                        selected: _memberId == member.id,
                        onSelected: (_) =>
                            setState(() => _memberId = member.id),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: records.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(recordsProvider(_memberId)),
              ),
              data: (data) => _RecordsBody(records: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsBody extends ConsumerWidget {
  const _RecordsBody({required this.records});

  final PatientRecords records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = records.medicalInfo;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
      children: [
        Text(l10n.medicalInfoTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          key: const Key('medicalInfo'),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: info == null || info.isEmpty
                ? Text(l10n.noMedicalInfo)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(l10n.bloodTypeLabel, info.bloodType),
                      _InfoRow(l10n.allergiesLabel, info.allergies),
                      _InfoRow(l10n.chronicLabel, info.chronicConditions),
                      _InfoRow(l10n.medicationsLabel, info.medications),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.recordEntriesTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (records.entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Text(l10n.noRecords, key: const Key('noRecords')),
            ),
          )
        else
          for (final entry in records.entries) ...[
            _EntryCard(entry: entry),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if ((value ?? '').trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value!, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry});

  final RecordEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final icon = switch (entry.kind) {
      RecordKind.note => Icons.sticky_note_2_outlined,
      RecordKind.diagnosis => Icons.medical_information_outlined,
      RecordKind.prescription => Icons.medication_outlined,
      RecordKind.attachment => Icons.attach_file,
    };
    return Card(
      key: Key('record-${entry.id}'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.recordKindName(entry.kind),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.yMMMd(locale).format(entry.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(entry.title, style: theme.textTheme.titleSmall),
            if ((entry.body ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.body!),
            ],
            if ((entry.attachmentUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: Key('open-${entry.id}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final opened = await ref.read(urlOpenerProvider)(
                    Uri.parse(entry.attachmentUrl!),
                  );
                  if (!opened) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.couldNotOpenLink)),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.openAttachment),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
