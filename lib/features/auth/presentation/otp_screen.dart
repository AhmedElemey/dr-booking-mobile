import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/config/brand_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/network/failure.dart';
import '../data/auth_repository.dart';
import '../domain/phone_number.dart';
import 'auth_controller.dart';

/// Step 2 of login: the 6-digit code. On success the router's auth redirect
/// moves on (to the profile form for new users, otherwise back to `from`).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.from});

  final String phone;

  /// Where to continue after login (the screen that asked for it).
  final String? from;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _resendSeconds = 60;

  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft = _secondsLeft - 1);
    });
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final code = PhoneNumber.toAsciiDigits(_controller.text.trim());
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = l10n.otpInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(widget.phone, code);
    if (!mounted) return;
    final login = result.toNullable();
    if (login == null) {
      setState(() {
        _busy = false;
        _error = l10n.failureMessage(
          result.fold((f) => f, (_) => const Failure(code: Failure.unknown)),
        );
      });
      return;
    }
    final accepted = await ref
        .read(authControllerProvider.notifier)
        .signIn(login.user);
    if (!mounted) return;
    if (!accepted) {
      // A doctor/staff number: this app is for patients.
      setState(() {
        _busy = false;
        _error = l10n.errForbidden(l10n.brandName);
      });
      return;
    }
    // Navigate explicitly: a router refresh only sees the base location when
    // this screen was pushed on top of another one.
    final from = widget.from;
    context.go(
      login.user.hasName
          ? (from ?? '/')
          : Uri(
              path: '/profile/complete',
              queryParameters: {'from': ?from},
            ).toString(),
    );
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(authRepositoryProvider)
        .requestOtp(widget.phone);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _error = l10n.failureMessage(failure)),
      (_) {
        setState(() => _error = null);
        _startTimer();
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
              Text(l10n.otpTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                // Isolate the number so it stays left-to-right inside Arabic text.
                l10n.otpSubtitle('\u2066${widget.phone}\u2069'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              TextField(
                key: const Key('otpField'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 12,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
                ],
                onChanged: (value) {
                  if (value.length == 6 && !_busy) _verify();
                },
                decoration: InputDecoration(
                  labelText: l10n.otpLabel,
                  counterText: '',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('verifyCode'),
                onPressed: _busy ? null : _verify,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.verify),
              ),
              const SizedBox(height: 8),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        l10n.resendIn(_secondsLeft),
                        style: theme.textTheme.bodyMedium,
                      )
                    : TextButton(
                        key: const Key('resendCode'),
                        onPressed: _resend,
                        child: Text(l10n.resendCode),
                      ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text(l10n.changeNumber),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
