import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/promotions_repository.dart';
import '../domain/promotion.dart';

/// The coupon field of the confirm step. Checks the code with
/// `POST /coupons/validate` as it is typed (after a short pause) or when
/// "Apply" is tapped, and reports the outcome through [onChanged]: the typed
/// code and its validation (null while unchecked or unchecked-able).
class CouponField extends ConsumerStatefulWidget {
  const CouponField({
    super.key,
    required this.doctorId,
    required this.serviceId,
    required this.onChanged,
    this.initialCode,
    this.canValidate = true,
    this.onNeedsSignIn,
  });

  final String doctorId;
  final String? serviceId;
  final String? initialCode;

  /// False for guests: the API only validates for signed-in patients.
  final bool canValidate;
  final VoidCallback? onNeedsSignIn;
  final void Function(String code, CouponValidation? validation) onChanged;

  @override
  ConsumerState<CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends ConsumerState<CouponField> {
  static const _pause = Duration(milliseconds: 500);

  late final TextEditingController _controller;
  Timer? _debounce;
  CouponValidation? _result;
  Object? _error;
  bool _checking = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
    if ((widget.initialCode ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _validate());
    }
  }

  @override
  void didUpdateWidget(CouponField old) {
    super.didUpdateWidget(old);
    if (old.serviceId != widget.serviceId && _code.isNotEmpty) _validate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _code => _controller.text.trim().toUpperCase();

  void _onTyped(String _) {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _result = null;
      _error = null;
      _checking = false;
    });
    widget.onChanged(_code, null);
    if (_code.length >= 3 && widget.canValidate) {
      _debounce = Timer(_pause, _validate);
    }
  }

  Future<void> _validate() async {
    final code = _code;
    if (code.isEmpty || !mounted) return;
    if (!widget.canValidate) {
      widget.onNeedsSignIn?.call();
      return;
    }
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _checking = true;
      _error = null;
    });
    final result = await ref
        .read(promotionsRepositoryProvider)
        .validate(code, doctorId: widget.doctorId, serviceId: widget.serviceId);
    // A newer keystroke or service change supersedes this answer.
    if (!mounted || generation != _generation) return;
    result.fold(
      (failure) {
        setState(() {
          _checking = false;
          _result = null;
          _error = failure;
        });
        widget.onChanged(code, null);
      },
      (validation) {
        setState(() {
          _checking = false;
          _result = validation;
        });
        widget.onChanged(code, validation);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _result;
    final String? message;
    final bool good;
    if (result != null && result.valid) {
      message = l10n.couponApplied(
        result.code,
        l10n.priceEgp(result.discountEgp),
      );
      good = true;
    } else if (result != null) {
      message = l10n.couponReasonMessage(result.reason);
      good = false;
    } else if (_error != null) {
      message = l10n.failureMessage(_error!);
      good = false;
    } else {
      message = null;
      good = false;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('couponField'),
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                onChanged: _onTyped,
                onSubmitted: (_) => _validate(),
                decoration: InputDecoration(
                  labelText: l10n.couponLabel,
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  suffixIcon: _checking
                      ? const Padding(
                          padding: EdgeInsetsDirectional.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : good
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4),
              child: FilledButton.tonal(
                key: const Key('applyCoupon'),
                style: FilledButton.styleFrom(minimumSize: const Size(80, 48)),
                onPressed: _checking || _code.isEmpty ? null : _validate,
                child: Text(l10n.applyCoupon),
              ),
            ),
          ],
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
            child: Text(
              message,
              key: const Key('couponMessage'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: good ? Colors.green.shade700 : theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
