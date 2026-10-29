import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
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
    final hasFilters = _query.specialtyId != null || _query.city != null;

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
                        label: Text(_query.city!),
                        onDeleted: () => setState(
                          () => _query = _query.copyWith(city: () => null),
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
