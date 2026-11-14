import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/error_view.dart';
import '../../profile/presentation/language_switcher.dart';
import '../../search/presentation/search_providers.dart';

/// Home / search: name search, city filter and specialty tiles.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  String? _city;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openList({String? specialtyId}) {
    final text = _search.text.trim();
    context.push(
      Uri(
        path: '/doctors',
        queryParameters: {
          'specialtyId': ?specialtyId,
          'city': ?_city,
          if (text.isNotEmpty) 'q': text,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final specialties = ref.watch(specialtiesProvider);
    final cities = ref.watch(citiesProvider);
    // Reset the city if a language change renamed the options.
    ref.listen(localeProvider, (_, _) => setState(() => _city = null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [LanguageToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        children: [
          Text(l10n.homeHeadline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            key: const Key('searchField'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _openList(),
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          cities.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : DropdownButtonFormField<String?>(
                    key: const Key('cityField'),
                    initialValue: _city,
                    decoration: InputDecoration(
                      labelText: l10n.cityLabel,
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.allCities),
                      ),
                      for (final city in items)
                        DropdownMenuItem(value: city, child: Text(city)),
                    ],
                    onChanged: (value) => setState(() => _city = value),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Text(l10n.specialtiesTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          specialties.when(
            loading: () => const Padding(
              padding: EdgeInsetsDirectional.symmetric(vertical: 32),
              child: LoadingView(),
            ),
            error: (error, _) => SizedBox(
              height: 200,
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(specialtiesProvider),
              ),
            ),
            data: (items) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final specialty in items)
                  ActionChip(
                    key: Key('specialty-${specialty.id}'),
                    avatar: const Icon(
                      Icons.medical_services_outlined,
                      size: 18,
                    ),
                    label: Text(specialty.name),
                    onPressed: () => _openList(specialtyId: specialty.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            key: const Key('allDoctors'),
            onPressed: _openList,
            icon: const Icon(Icons.groups_outlined),
            label: Text(l10n.allDoctors),
          ),
        ],
      ),
    );
  }
}
