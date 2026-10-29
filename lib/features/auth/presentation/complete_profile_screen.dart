import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../profile/data/profile_repository.dart';
import 'auth_controller.dart';

/// New users enter their name once; the router leaves this screen as soon as
/// the user has one.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = l10n.nameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(profileRepositoryProvider)
        .updateMe(fullName: name);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = l10n.failureMessage(failure);
      }),
      (user) {
        ref.read(authControllerProvider.notifier).userUpdated(user);
        final from = widget.from;
        context.go(from != null && from.startsWith('/') ? from : '/');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.completeProfileTitle,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.completeProfileSubtitle,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              TextField(
                key: const Key('nameField'),
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.name],
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.fullNameLabel,
                  errorText: _error,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('saveName'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.finish),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
