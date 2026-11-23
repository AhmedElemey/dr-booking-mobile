import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/display_labels.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../insurance/domain/insurance.dart';
import '../../insurance/presentation/insurance_providers.dart';
import '../../../shared/widgets/doctor_card.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../domain/doctor_query.dart';
import 'search_providers.dart';

/// Paged search results for the filters chosen on the home screen.
class DoctorListScreen extends ConsumerStatefulWidget {
  const DoctorListScreen({super.key, required this.initialQuery});

  final DoctorQuery initialQuery;

  @override
  ConsumerState<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends ConsumerState<DoctorListScreen> {
  late final TextEditingController _search;
  late DoctorQuery _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _search = TextEditingController(text: _query.text);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickInsurer(List<InsuranceProvider> insurers) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.insuranceFilterTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('insurer-any'),
              title: Text(l10n.allInsurers),
              selected: _query.insuranceProviderId == null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final insurer in insurers)
              ListTile(
                key: Key('insurer-${insurer.id}'),
                title: Text(insurer.name),
                selected: _query.insuranceProviderId == insurer.id,
                onTap: () => Navigator.of(context).pop(insurer.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _query = _query.copyWith(
        insuranceProviderId: () => picked.isEmpty ? null : picked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(doctorListProvider(_query));
    final notifier = ref.read(doctorListProvider(_query).notifier);
    final specialtyName = ref
        .watch(specialtiesProvider)
        .value
        ?.where((s) => s.id == _query.specialtyId)
        .firstOrNull
        ?.name;
    final insuranceOn = ref.watch(featuresProvider.select((f) => f.insurance));
    final insurers = insuranceOn
        ? ref.watch(insuranceProvidersProvider).value
        : null;
    final insurerName = insurers
        ?.where((i) => i.id == _query.insuranceProviderId)
        .firstOrNull
        ?.name;
    final hasFilters =
        _query.specialtyId != null ||
        _query.city != null ||
        _query.insuranceProviderId != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.doctorsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: TextField(
              key: const Key('listSearchField'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) =>
                  setState(() => _query = _query.copyWith(text: () => value)),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (insuranceOn && insurers != null && insurers.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ActionChip(
                  key: const Key('insuranceFilter'),
                  avatar: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 18,
                  ),
                  label: Text(insurerName ?? l10n.insuranceFilterTitle),
                  onPressed: () => _pickInsurer(insurers),
                ),
              ),
            ),
          if (hasFilters)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_query.specialtyId != null)
                      InputChip(
                        label: Text(specialtyName ?? l10n.specialtiesTitle),
                        onDeleted: () => setState(
                          () =>
                              _query = _query.copyWith(specialtyId: () => null),
                        ),
                      ),
                    if (_query.city != null)
                      InputChip(
                        label: Text(cityLabel(_query.city!, l10n)),
                        onDeleted: () => setState(
                          () => _query = _query.copyWith(city: () => null),
                        ),
                      ),
                    if (_query.insuranceProviderId != null)
                      InputChip(
                        key: const Key('insuranceChip'),
                        label: Text(insurerName ?? l10n.insuranceLabel),
                        onDeleted: () => setState(
                          () => _query = _query.copyWith(
                            insuranceProviderId: () => null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: PagedListView(
              value: list,
              onLoadMore: notifier.loadMore,
              onRefresh: () => ref.refresh(doctorListProvider(_query).future),
              empty: EmptyView(
                message: l10n.noDoctorsFound,
                action: hasFilters || (_query.text ?? '').isNotEmpty
                    ? OutlinedButton(
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = const DoctorQuery();
                        }),
                        child: Text(l10n.clearFilters),
                      )
                    : null,
              ),
              itemBuilder: (context, doctor) => DoctorCard(
                doctor: doctor,
                onTap: () => context.push('/doctors/${doctor.slug}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
