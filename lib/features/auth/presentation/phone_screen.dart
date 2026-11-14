import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/config/brand_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/auth_repository.dart';
import '../domain/phone_number.dart';

/// Step 1 of login: the patient's Egyptian mobile number.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, this.from});

  /// Where to return after login.
  final String? from;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final phone = PhoneNumber.normalize(_controller.text);
    if (phone == null) {
      setState(() => _error = l10n.phoneInvalid);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref.read(authRepositoryProvider).requestOtp(phone);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _sending = false;
        _error = l10n.failureMessage(failure);
      }),
      (_) {
        setState(() => _sending = false);
        final from = widget.from;
        context.push(
          Uri(
            path: '/login/otp',
            queryParameters: {'phone': phone, 'from': ?from},
          ).toString(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.nightlight_round,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.phoneTitle(l10n.brandName),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.phoneSubtitle, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 28),
              TextField(
                key: const Key('phoneField'),
                controller: _controller,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  hintText: l10n.phoneHint,
                  errorText: _error,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('sendCode'),
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sendCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
