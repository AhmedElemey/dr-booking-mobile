import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/family_repository.dart';
import '../domain/family_member.dart';
import 'family_providers.dart';

/// Settings > Family members: list, add, edit and remove.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(familyMembersProvider);
    final count = members.value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyTitle)),
      body: members.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(familyMembersProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyView(
                icon: Icons.family_restroom_outlined,
                message: l10n.familyEmpty,
              )
            : ListView.separated(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                itemCount: items.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _MemberCard(member: items[index]),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count >= FamilyRepository.maxMembers)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: Text(
                    l10n.familyLimit,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              FilledButton.icon(
                key: const Key('addFamilyMember'),
                onPressed:
                    members.hasValue && count < FamilyRepository.maxMembers
                    ? () => showFamilyMemberSheet(context, ref)
                    : null,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(l10n.addFamilyMember),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final details = [
      l10n.relationName(member.relation),
      if (member.gender != null) l10n.genderName(member.gender!),
      if (member.dateOfBirth != null)
        ClinicTime.date(ClinicTime.parseDate(member.dateOfBirth!), locale),
    ];
    return Card(
      key: Key('member-${member.id}'),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            member.relation == FamilyRelation.child
                ? Icons.child_care
                : Icons.person_outline,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(member.fullName),
        subtitle: Text(details.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('edit-${member.id}'),
              tooltip: l10n.editFamilyMember,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  showFamilyMemberSheet(context, ref, member: member),
            ),
            IconButton(
              key: Key('remove-${member.id}'),
              tooltip: l10n.removeFamilyMember,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => _remove(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFamilyConfirm(member.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('confirmRemoveMember'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.removeFamilyMember),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(familyRepositoryProvider).delete(member.id);
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      ),
      (_) {
        ref.invalidate(familyMembersProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.familyRemoved)));
      },
    );
  }
}

/// The add / edit form, as a bottom sheet. Resolves true when saved.
Future<bool?> showFamilyMemberSheet(
  BuildContext context,
  WidgetRef ref, {
  FamilyMember? member,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _MemberForm(member: member),
);

class _MemberForm extends ConsumerStatefulWidget {
  const _MemberForm({this.member});

  final FamilyMember? member;

  @override
  ConsumerState<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends ConsumerState<_MemberForm> {
  late final TextEditingController _name;
  late FamilyRelation _relation;
  FamilyGender? _gender;
  String? _dob;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _name = TextEditingController(text: m?.fullName ?? '');
    _relation = m?.relation ?? FamilyRelation.child;
    _gender = m?.gender;
    _dob = m?.dateOfBirth;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob == null
          ? DateTime(now.year - 10)
          : ClinicTime.parseDate(_dob!),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dob = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_name.text.trim().length < 2) {
      setState(() => _error = l10n.familyNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(familyRepositoryProvider);
    final existing = widget.member;
    final result = existing == null
        ? await repo.add(
            fullName: _name.text,
            relation: _relation,
            dateOfBirth: _dob,
            gender: _gender,
          )
        : await repo.update(
            existing.id,
            fullName: _name.text,
            relation: _relation,
            dateOfBirth: _dob,
            gender: _gender,
          );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = l10n.failureMessage(failure);
      }),
      (_) {
        ref.invalidate(familyMembersProvider);
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
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
              widget.member == null
                  ? l10n.addFamilyMember
                  : l10n.editFamilyMember,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('familyNameField'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.fullNameLabel),
            ),
            const SizedBox(height: 16),
            Text(l10n.relationLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final relation in FamilyRelation.values)
                  ChoiceChip(
                    key: Key('relation-${relation.wire}'),
                    label: Text(l10n.relationName(relation)),
                    selected: _relation == relation,
                    onSelected: (_) => setState(() => _relation = relation),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.genderLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final gender in FamilyGender.values)
                  ChoiceChip(
                    key: Key('gender-${gender.wire}'),
                    label: Text(l10n.genderName(gender)),
                    selected: _gender == gender,
                    onSelected: (selected) =>
                        setState(() => _gender = selected ? gender : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('pickBirthDate'),
              onPressed: _pickDate,
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                _dob == null
                    ? l10n.dateOfBirthLabel
                    : ClinicTime.date(ClinicTime.parseDate(_dob!), locale),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('familyError'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveFamilyMember'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
