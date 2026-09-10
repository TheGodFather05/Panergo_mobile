import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';

final countriesProvider =
    FutureProvider<List<Country>>((ref) => ref.read(apiProvider).countries());

final citiesProvider = FutureProvider.family<List<City>, String>(
  (ref, countryCode) => ref.read(apiProvider).cities(countryCode),
);

/// The quartiers of one town. Keyed by city so switching towns refetches.
final quartiersProvider = FutureProvider.family<List<Quartier>, String?>(
  (ref, cityId) => ref.read(apiProvider).quartiers(cityId: cityId),
);

/// Where someone is, chosen rather than typed.
///
/// Three lists that narrow — country, then town, then quartier — because
/// routing matches all of them as exact strings. A typed spelling is a market
/// of one that nobody else can reach, and the person waits for offers that can
/// never arrive with nothing anywhere to explain it.
///
/// Each list returns its choice through the route rather than a callback: the
/// rows sit inside nested builders, and popping from one of those is the kind of
/// thing that works until it quietly does not.
abstract final class PlacePickers {
  static Future<Country?> country(BuildContext context, {String? selected}) =>
      Navigator.of(context).push<Country>(
        MaterialPageRoute<Country>(
          builder: (_) => _PlaceList<Country>(
            title: 'Pays',
            hint: 'Rechercher un pays',
            emptyCount: (n) => '$n pays desservi${n > 1 ? 's' : ''}',
            watch: (ref) => ref.watch(countriesProvider),
            labelOf: (c) => c.name,
            detailOf: (c) => c.dialCode,
            isSelected: (c) => c.code == selected,
            icon: 'public',
          ),
        ),
      );

  /// The quartiers of one town. [cityId] null lists everywhere Panergo serves,
  /// which is what the profile edit screen wants.
  static Future<Quartier?> quartier(BuildContext context,
          {String? cityId, String? selected}) =>
      Navigator.of(context).push<Quartier>(
        MaterialPageRoute<Quartier>(
          builder: (_) => _PlaceList<Quartier>(
            title: 'Quartiers',
            hint: 'Rechercher un quartier',
            emptyCount: (n) => '$n quartier${n > 1 ? 's' : ''} desservi${n > 1 ? 's' : ''}',
            watch: (ref) => ref.watch(quartiersProvider(cityId)),
            labelOf: (q) => q.name,
            detailOf: (q) => q.city,
            isSelected: (q) => q.name == selected,
            icon: 'location_on',
          ),
        ),
      );

  static Future<City?> city(BuildContext context,
          {required String countryCode, String? selected}) =>
      Navigator.of(context).push<City>(
        MaterialPageRoute<City>(
          builder: (_) => _PlaceList<City>(
            title: 'Villes',
            hint: 'Rechercher une ville',
            emptyCount: (n) => '$n ville${n > 1 ? 's' : ''} desservie${n > 1 ? 's' : ''}',
            watch: (ref) => ref.watch(citiesProvider(countryCode)),
            labelOf: (c) => c.name,
            detailOf: (_) => null,
            isSelected: (c) => c.name == selected,
            icon: 'location_city',
          ),
        ),
      );
}

/// One step of the cascade. Same shape whatever it is listing.
class _PlaceList<T> extends ConsumerStatefulWidget {
  const _PlaceList({
    required this.title,
    required this.hint,
    required this.emptyCount,
    required this.watch,
    required this.labelOf,
    required this.detailOf,
    required this.isSelected,
    required this.icon,
  });

  final String title;
  final String hint;
  final String Function(int) emptyCount;
  /// Watched by the caller and handed in, so this widget stays generic
  /// without needing a provider type it cannot name.
  final AsyncValue<List<T>> Function(WidgetRef) watch;
  final String Function(T) labelOf;
  final String? Function(T) detailOf;
  final bool Function(T) isSelected;
  final String icon;

  @override
  ConsumerState<_PlaceList<T>> createState() => _PlaceListState<T>();
}

class _PlaceListState<T> extends ConsumerState<_PlaceList<T>> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Held once: the rows are built inside nested builders that each shadow
    // `context`, and the pop has to leave *this* route.
    final rootContext = context;
    final async = widget.watch(ref);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: widget.title,
                onBack: () => Navigator.of(rootContext).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  async.value == null
                      ? '…'
                      : widget.emptyCount(async.value!.length),
                  style: context.type.meta,
                ),
              ),
              const SizedBox(height: Space.s14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    // Clearing a search on a phone otherwise means holding
                    // backspace, which nobody enjoys.
                    suffixIcon: _query.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            child: const Center(
                              widthFactor: 1,
                              child: _ClearChip(),
                            ),
                          ),
                    filled: true,
                    fillColor: PanergoColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: Radii.brInput,
                      borderSide: const BorderSide(color: PanergoColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: Radii.brInput,
                      borderSide: const BorderSide(color: PanergoColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s14),
              Expanded(
                child: AsyncView<List<T>>(
                  state: async.isLoading && !async.hasValue
                      ? LoadState.loading
                      : async.hasError && !async.hasValue
                          ? LoadState.error
                          : LoadState.normal,
                  data: async.value,
                  errorTitle: 'Impossible de charger la liste',
                  skeleton: (_) => const _Skeleton(),
                  empty: (_) => const SizedBox.shrink(),
                  builder: (_, items) {
                    final matches = items
                        .where((e) =>
                            _query.isEmpty ||
                            normalizePlace(widget.labelOf(e))
                                .contains(normalizePlace(_query)))
                        .toList();

                    if (matches.isEmpty) return const _NoMatch();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Space.gutter, 0, Space.gutter, Space.s26),
                      itemCount: matches.length,
                      itemBuilder: (_, i) => PlaceRow(
                        icon: widget.icon,
                        label: widget.labelOf(matches[i]),
                        detail: widget.detailOf(matches[i]),
                        selected: widget.isSelected(matches[i]),
                        onTap: () => Navigator.of(rootContext).pop(matches[i]),
                      ),
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

class _ClearChip extends StatelessWidget {
  const _ClearChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: PanergoColors.fillAlt,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: MaterialSymbol('close', size: 16, color: PanergoColors.muted),
      ),
    );
  }
}

class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String icon;
  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s14, vertical: Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(
              color: selected ? brand.fill : PanergoColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            MaterialSymbol(icon,
                size: 19,
                color: selected ? brand.link : PanergoColors.subtle),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: PanergoColors.ink)),
            ),
            if (detail != null) ...[
              Text(detail!,
                  style: const TextStyle(
                      fontSize: 12.5, color: PanergoColors.faint)),
              const SizedBox(width: Space.s8),
            ],
            if (selected)
              MaterialSymbol('check_circle', size: 20, color: brand.link),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Space.s30),
        child: Text(
          'Aucun résultat. Panergo s’étend petit à petit.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: PanergoColors.muted),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.s8),
            height: 58,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}

/// Accent-insensitive comparison for search.
///
/// Nobody reaches for the diaeresis on a phone keyboard, so `Deido` has to find
/// `Deïdo` and `Yaounde` has to find `Yaoundé`.
String normalizePlace(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');