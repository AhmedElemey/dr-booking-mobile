import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/brand_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../shared/widgets/error_view.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../promotions/presentation/offers_strip.dart';
import '../../profile/presentation/language_switcher.dart';
import '../../search/presentation/search_providers.dart';

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
    final multiBranch = ref.watch(
      featuresProvider.select((f) => f.multiBranch),
    );
    final cities = multiBranch ? ref.watch(citiesProvider) : null;
    ref.listen(localeProvider, (_, _) => setState(() => _city = null));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.nightlight_round,
                color: theme.colorScheme.onPrimary,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n.brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: const [LanguageToggleButton(), SizedBox(width: 8)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.homeHeadline,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 58,
                      height: 70,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.medical_services_outlined,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('searchField'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _openList(),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _openList,
                    tooltip: l10n.allDoctors,
                    icon: Icon(
                      Icons.arrow_forward,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ),
              if (cities != null) ...[
                const SizedBox(height: 10),
                cities.maybeWhen(
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : DropdownButtonFormField<String?>(
                          key: const Key('cityField'),
                          initialValue: _city,
                          isExpanded: true,
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
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('allDoctors'),
                onPressed: _openList,
                icon: const Icon(Icons.groups_outlined),
                label: Text(l10n.allDoctors),
              ),
              const OffersStrip(),
              const SizedBox(height: 24),
              Text(
                l10n.specialtiesTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              specialties.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingView(),
                ),
                error: (error, _) => SizedBox(
                  height: 180,
                  child: ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(specialtiesProvider),
                  ),
                ),
                data: (items) => LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          SizedBox(
                            width: width,
                            child: Material(
                              color: theme.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                key: Key('specialty-${items[i].id}'),
                                borderRadius: BorderRadius.circular(20),
                                onTap: () =>
                                    _openList(specialtyId: items[i].id),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 108,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        [
                                          Icons.health_and_safety_outlined,
                                          Icons.auto_awesome_outlined,
                                          Icons.child_care_outlined,
                                          Icons.medical_services_outlined,
                                        ][i % 4],
                                        color: i.isEven
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.secondary,
                                        size: 25,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        items[i].name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
