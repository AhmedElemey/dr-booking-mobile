import 'package:flutter/material.dart';
import '../../../core/format/arabic_digits.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/network/failure.dart';
import '../../../shared/domain/clinic.dart';
import '../../../shared/widgets/input_formatters.dart';
import '../../appointments/data/appointments_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointments_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../doctor/presentation/doctor_providers.dart';
import '../../family/domain/family_member.dart';
import '../../family/presentation/family_providers.dart';
import '../../family/presentation/booking_for_picker.dart';
import '../../insurance/domain/insurance.dart';
import '../../promotions/domain/promotion.dart';
import '../../promotions/presentation/coupon_field.dart';
import '../../promotions/presentation/promotions_providers.dart';
import '../domain/booking_draft.dart';
import '../domain/booking_issue.dart';
import 'booking_providers.dart';

/// Booking step 2: summary, optional visit type and note. Guests can reach this
/// screen; they are asked to sign in only when they confirm.
class ConfirmBookingScreen extends ConsumerStatefulWidget {
  const ConfirmBookingScreen({super.key});

  @override
  ConsumerState<ConfirmBookingScreen> createState() =>
      _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends ConsumerState<ConfirmBookingScreen> {
  final _note = TextEditingController();
  final _memberNumber = TextEditingController();
  ServiceItem? _service;
  FamilyMember? _member;
  AppointmentMode _mode = AppointmentMode.inPerson;
  bool _useInsurance = false;
  InsuranceProvider? _insurer;
  String _couponCode = '';
  CouponValidation? _coupon;
  late final String? _savedCoupon = ref.read(selectedCouponProvider);
  bool _booking = false;
  String? _error;

  /// Set when the API refused them, so the stale doctor data is not offered again.
  bool _videoRefused = false;
  final _refusedInsurers = <String>{};

  @override
  void dispose() {
    _note.dispose();
    _memberNumber.dispose();
    super.dispose();
  }

  /// Price before any discount: the treatment's, else the consultation fee.
  num? _price(BookingDraft draft) =>
      _service?.priceEgp ?? draft.doctor.consultationFeeEgp;

  Future<void> _confirm() async {
    final draft = ref.read(bookingDraftProvider);
    if (draft == null) return;
    final l10n = AppLocalizations.of(context);
    final features = ref.read(featuresProvider);
    final insurer = _insurer;
    final number = _memberNumber.text.trim();
    if (features.insurance &&
        _useInsurance &&
        (insurer == null || number.isEmpty)) {
      setState(() => _error = l10n.insuranceRequired);
      return;
    }
    setState(() {
      _booking = true;
      _error = null;
    });
    // A code the API already refused is not sent again.
    final sendCoupon =
        features.promotions &&
        _couponCode.isNotEmpty &&
        (_coupon == null || _coupon!.valid);
    final result = await ref
        .read(appointmentsRepositoryProvider)
        .book(
          slotId: draft.slot.id,
          serviceId: _service?.id,
          note: _note.text,
          familyMemberId: features.familyAccounts ? _member?.id : null,
          mode:
              features.videoConsultation &&
                  draft.doctor.offersVideo &&
                  !_videoRefused
              ? _mode
              : null,
          insurance: features.insurance && _useInsurance && insurer != null
              ? InsuranceChoice(providerId: insurer.id, memberNumber: number)
              : null,
          couponCode: sendCoupon ? _couponCode : null,
        );
    if (!mounted) return;
    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      final issue = BookingIssue.from(failure);
      setState(() {
        _booking = false;
        _error = switch (issue) {
          BookingIssue.mode => l10n.errBookingModeRefused,
          BookingIssue.insuranceProvider => l10n.errBookingInsurerRefused,
          BookingIssue.insuranceMemberNumber => l10n.insuranceRequired,
          BookingIssue.familyMember => l10n.errBookingMemberRefused,
          null => l10n.failureMessage(failure),
        };
        switch (issue) {
          case BookingIssue.mode:
            _videoRefused = true;
            _mode = AppointmentMode.inPerson;
          case BookingIssue.insuranceProvider:
            if (insurer != null) _refusedInsurers.add(insurer.id);
            _insurer = null;
            if (draft.doctor.insuranceProviders.every(
              (p) => _refusedInsurers.contains(p.id),
            )) {
              _useInsurance = false;
            }
          case BookingIssue.familyMember:
            _member = null;
          case BookingIssue.insuranceMemberNumber || null:
            break;
        }
      });
      if (issue == BookingIssue.mode ||
          issue == BookingIssue.insuranceProvider) {
        ref.invalidate(doctorProvider(draft.doctor.slug));
      }
      if (issue == BookingIssue.familyMember) {
        ref.invalidate(familyMembersProvider);
      }
      if (failure.code == 'CLINIC_CLOSED') {
        ref.invalidate(doctorSlotsProvider(draft.doctor.slug));
        context.go('/doctors/${draft.doctor.slug}/slots');
        return;
      }
      if (failure.code == 'SLOT_TAKEN' || failure.code == 'SLOT_UNAVAILABLE') {
        // The list is stale: reload it and send the patient back to choose again.
        ref.invalidate(doctorSlotsProvider(draft.doctor.slug));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failureMessage(failure))));
        context.go('/doctors/${draft.doctor.slug}/slots');
      }
      return;
    }
    final appointment = result.toNullable()!;
    ref.read(lastBookingProvider.notifier).set(appointment);
    ref.read(selectedCouponProvider.notifier).clear();
    invalidateAppointments(ref);
    ref.invalidate(doctorSlotsProvider(draft.doctor.slug));
    context.go('/booking/success');
    ref.read(bookingDraftProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final draft = ref.watch(bookingDraftProvider);
    if (draft == null) return const Scaffold();
    final isGuest = ref.watch(authControllerProvider).value == null;
    final features = ref.watch(featuresProvider);
    final price = _price(draft);
    final discount = _coupon != null && _coupon!.valid
        ? _coupon!.discountEgp
        : 0;
    final slotLocal = ClinicTime.parseTime(
      draft.slot.local,
      onDate: ClinicTime.parseDate(draft.slotDate),
    );
    // Two lines: mixing a date and a time in one RTL run reorders the digits.
    final when =
        '${ClinicTime.date(slotLocal, locale)}\n${ClinicTime.time(slotLocal, locale)}';
    final doctor = draft.doctor;
    final insurers = [
      for (final p in doctor.insuranceProviders)
        if (!_refusedInsurers.contains(p.id)) p,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.confirmTitle),
        leading: BackButton(
          key: const Key('confirmBack'),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/doctors/${draft.doctor.slug}/slots');
            }
          },
        ),
      ),
      body: ListView(
        // Leave breathing room above the fixed confirm action so the final
        // controls can always scroll fully into view on short screens.
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(label: l10n.doctorLabel, value: doctor.name),
                  if (doctor.clinic != null)
                    _SummaryRow(
                      label: l10n.clinicLabel,
                      value: [
                        doctor.clinic!.name,
                        ?doctor.clinic!.address,
                      ].join('\n'),
                    ),
                  _SummaryRow(
                    label: l10n.whenLabel,
                    value: when,
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ),
          if (doctor.services.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.visitType, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in doctor.services)
                  ChoiceChip(
                    key: Key('service-${service.id}'),
                    label: Text(service.name),
                    selected: _service?.id == service.id,
                    onSelected: (selected) =>
                        setState(() => _service = selected ? service : null),
                  ),
              ],
            ),
          ],
          if (features.familyAccounts && !isGuest) ...[
            const SizedBox(height: 20),
            BookingForPicker(
              selected: _member,
              onSelected: (member) => setState(() => _member = member),
            ),
          ],
          if (features.videoConsultation &&
              doctor.offersVideo &&
              !_videoRefused) ...[
            const SizedBox(height: 20),
            Text(l10n.visitModeLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AppointmentMode>(
              key: const Key('visitMode'),
              segments: [
                ButtonSegment(
                  value: AppointmentMode.inPerson,
                  icon: const Icon(Icons.local_hospital_outlined),
                  label: Text(l10n.inPerson),
                ),
                ButtonSegment(
                  value: AppointmentMode.video,
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(l10n.videoVisit),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            if (_mode == AppointmentMode.video)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6),
                child: Text(
                  l10n.videoConfirmNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          if (features.insurance && insurers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      key: const Key('useInsurance'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.health_and_safety_outlined),
                      title: Text(l10n.useInsurance),
                      value: _useInsurance,
                      onChanged: (value) =>
                          setState(() => _useInsurance = value),
                    ),
                    if (_useInsurance) ...[
                      DropdownButtonFormField<InsuranceProvider>(
                        key: const Key('insurerField'),
                        initialValue: _insurer,
                        decoration: InputDecoration(
                          labelText: l10n.insuranceProviderLabel,
                        ),
                        items: [
                          for (final provider in insurers)
                            DropdownMenuItem(
                              value: provider,
                              child: Text(provider.name),
                            ),
                        ],
                        onChanged: (value) => setState(() => _insurer = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('memberNumberField'),
                        controller: _memberNumber,
                        maxLength: 100,
                        inputFormatters: [noLeadingSpace],
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.insuranceMemberLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (features.promotions) ...[
            const SizedBox(height: 20),
            CouponField(
              doctorId: doctor.id,
              serviceId: _service?.id,
              initialCode: _savedCoupon,
              canValidate: !isGuest,
              onNeedsSignIn: () => context.push(
                Uri(
                  path: '/login',
                  queryParameters: {'from': '/booking/confirm'},
                ).toString(),
              ),
              onChanged: (code, validation) => setState(() {
                _couponCode = code;
                _coupon = validation;
              }),
            ),
          ],
          if ((features.promotions || features.onlinePayments) &&
              price != null) ...[
            const SizedBox(height: 12),
            _PriceSummary(price: price, discount: discount),
          ],
          const SizedBox(height: 20),
          TextField(
            key: const Key('noteField'),
            controller: _note,
            maxLines: 3,
            maxLength: 500,
            buildCounter: localizedFieldCounter,
            decoration: InputDecoration(labelText: l10n.noteLabel),
          ),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(
                features.onlinePayments
                    ? l10n.payOnlineOrClinic
                    : l10n.payAtClinic,
              ),
              subtitle: features.onlinePayments
                  ? null
                  : Text(l10n.payAtClinicDetail),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('bookingError'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGuest)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: Text(
                    l10n.signInToBookHint,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton(
                key: const Key('confirmBooking'),
                onPressed: _booking
                    ? null
                    : isGuest
                    ? () => context.push(
                        Uri(
                          path: '/login',
                          queryParameters: {'from': '/booking/confirm'},
                        ).toString(),
                      )
                    : _confirm,
                child: _booking
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isGuest ? l10n.signInToBook : l10n.confirmBooking),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: emphasize
                ? theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Price, discount and total of the visit being booked.
class _PriceSummary extends StatelessWidget {
  const _PriceSummary({required this.price, required this.discount});

  final num price;
  final num discount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = (price - discount).clamp(0, price);
    Widget row(String label, String value, {TextStyle? style}) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
    return Card(
      key: const Key('priceSummary'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Column(
          children: [
            row(l10n.priceLabel, l10n.priceEgp(price)),
            if (discount > 0)
              row(
                l10n.discountLabel,
                l10n.priceEgp(discount),
                style: TextStyle(color: Colors.green.shade700),
              ),
            const Divider(height: 16),
            row(
              l10n.totalLabel,
              l10n.priceEgp(total),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
