import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../data/profile_repository.dart';
import 'language_switcher.dart';

/// Name, language and logout (or a sign-in prompt for guests).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).value;
    final language = ref.watch(localeProvider).languageCode;
    final features = ref.watch(featuresProvider);
    final englishEnabled = features.englishLanguage;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Text(l10n.accountSection, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (user == null)
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.guestSettingsPrompt),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('settingsSignIn'),
                      onPressed: () => context.push('/login?from=/settings'),
                      child: Text(l10n.signIn),
                    ),
                  ],
                ),
              ),
            )
          else
            _AccountCard(user: user),
          if (user != null &&
              (features.familyAccounts ||
                  features.waitingList ||
                  features.patientRecords)) ...[
            const SizedBox(height: 24),
            Text(l10n.sectionMyHealth, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (features.familyAccounts)
                    _NavTile(
                      key: const Key('openFamily'),
                      icon: Icons.family_restroom_outlined,
                      label: l10n.familyTitle,
                      onTap: () => context.push('/family'),
                    ),
                  if (features.waitingList)
                    _NavTile(
                      key: const Key('openWaitingList'),
                      icon: Icons.notifications_active_outlined,
                      label: l10n.waitingListTitle,
                      onTap: () => context.push('/waiting-list'),
                    ),
                  if (features.patientRecords)
                    _NavTile(
                      key: const Key('openRecords'),
                      icon: Icons.folder_shared_outlined,
                      label: l10n.recordsTitle,
                      onTap: () => context.push('/records'),
                    ),
                ],
              ),
            ),
          ],
          if (user != null &&
              (features.whatsappReminders ||
                  features.promotions ||
                  features.recallCampaigns)) ...[
            const SizedBox(height: 24),
            Text(l10n.notificationsSection, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (features.whatsappReminders)
                    SwitchListTile(
                      key: const Key('whatsappOptIn'),
                      secondary: const Icon(Icons.chat_outlined),
                      title: Text(l10n.whatsappReminders),
                      subtitle: Text(l10n.whatsappRemindersHint),
                      value: user.whatsAppOptIn,
                      onChanged: (value) =>
                          _setOptIn(context, ref, whatsApp: value),
                    ),
                  if (features.promotions || features.recallCampaigns)
                    SwitchListTile(
                      key: const Key('marketingOptIn'),
                      secondary: const Icon(Icons.local_offer_outlined),
                      title: Text(l10n.marketingOptIn),
                      subtitle: Text(l10n.marketingOptInHint),
                      value: user.marketingOptIn,
                      onChanged: (value) =>
                          _setOptIn(context, ref, marketing: value),
                    ),
                ],
              ),
            ),
          ],
          if (englishEnabled) ...[
            const SizedBox(height: 24),
            Text(l10n.languageSection, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              key: const Key('languageSelector'),
              segments: [
                ButtonSegment(value: 'ar', label: Text(l10n.arabic)),
                ButtonSegment(value: 'en', label: Text(l10n.english)),
              ],
              selected: {language},
              onSelectionChanged: (selection) =>
                  changeLanguage(ref, selection.first),
            ),
          ],
          if (user != null) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              key: const Key('logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () => _logout(context, ref),
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setOptIn(
    BuildContext context,
    WidgetRef ref, {
    bool? whatsApp,
    bool? marketing,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(profileRepositoryProvider)
        .updateMe(whatsAppOptIn: whatsApp, marketingOptIn: marketing);
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      ),
      (updated) =>
          ref.read(authControllerProvider.notifier).userUpdated(updated),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('confirmLogout'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    messenger.showSnackBar(SnackBar(content: Text(l10n.loggedOut)));
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: Icon(
      Icons.chevron_right,
      textDirection: Directionality.of(context),
    ),
    onTap: onTap,
  );
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.fullName ?? ''),
            subtitle: Text(l10n.fullNameLabel),
            trailing: IconButton(
              key: const Key('editName'),
              tooltip: l10n.editName,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editName(context, ref),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(user.phone),
              ),
            ),
            subtitle: Text(l10n.phoneLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: user.fullName ?? ''),
    );
    if (name == null || name == user.fullName) return;
    final result = await ref
        .read(profileRepositoryProvider)
        .updateMe(fullName: name);
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      ),
      (updated) =>
          ref.read(authControllerProvider.notifier).userUpdated(updated),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editName),
      content: TextField(
        key: const Key('editNameField'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.fullNameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('saveEditedName'),
          onPressed: () {
            final name = _controller.text.trim();
            if (name.length >= 2) Navigator.of(context).pop(name);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
