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

final quartiersProvider = FutureProvider<List<Quartier>>(
  (ref) => ref.read(apiProvider).quartiers(),
);

/// The quartiers Panergo serves.
///
/// A picker rather than a text field, and that is a correctness decision rather
/// than a comfort: routing compares quartiers as exact strings, so a typed
/// "akwa " is a market of one that nobody else can ever match. Someone would
/// wait for offers that could never arrive, with nothing anywhere to say why.
///
/// Built as a twin of the trades picker — same header, same search, same derived
/// count — with one difference: this list comes over the network, so it declares
/// all five states.
class QuartierPickerScreen extends ConsumerStatefulWidget {
  const QuartierPickerScreen({
    super.key,
    required this.onSelected,
    this.selected,
  });

  final ValueChanged<Quartier> onSelected;

  /// Highlighted on open, so someone changing their mind sees where they were.
  final String? selected;

  @override
  ConsumerState<QuartierPickerScreen> createState() =>
      _QuartierPickerScreenState();
}

class _QuartierPickerScreenState extends ConsumerState<QuartierPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quartiersProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Quartiers',
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  // Derived from the list, never a literal.
                  async.value == null
                      ? 'Où êtes-vous ?'
                      : '${async.value!.length} quartiers desservis',
                  style: context.type.meta,
                ),
              ),
              const SizedBox(height: Space.s14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un quartier',
                    prefixIcon: const Icon(Icons.search, size: 20),
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
                child: AsyncView<List<Quartier>>(
                  state: async.isLoading && !async.hasValue
                      ? LoadState.loading
                      : async.hasError && !async.hasValue
                          ? LoadState.error
                          : LoadState.normal,
                  data: async.value,
                  onRetry: () => ref.invalidate(quartiersProvider),
                  errorTitle: 'Impossible de charger les quartiers',
                  skeleton: (_) => const _Skeleton(),
                  empty: (_) => const SizedBox.shrink(),
                  builder: (context, quartiers) {
                    final matches = quartiers
                        .where((q) =>
                            _query.isEmpty ||
                            normalizeForSearch(q.name)
                                .contains(normalizeForSearch(_query)))
                        .toList();

                    if (matches.isEmpty) return const _NoMatch();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Space.gutter, 0, Space.gutter, Space.s26),
                      itemCount: matches.length,
                      itemBuilder: (context, i) => _QuartierRow(
                        quartier: matches[i],
                        selected: matches[i].name == widget.selected,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelected(matches[i]);
                        },
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

class _QuartierRow extends StatelessWidget {
  const _QuartierRow({
    required this.quartier,
    required this.selected,
    required this.onTap,
  });

  final Quartier quartier;
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
            MaterialSymbol('location_on',
                size: 19,
                color: selected ? brand.link : PanergoColors.subtle),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quartier.name,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: PanergoColors.ink)),
                  Text(quartier.city,
                      style: const TextStyle(
                          fontSize: 11.5, color: PanergoColors.faint)),
                ],
              ),
            ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            MaterialSymbol('search_off', size: 40, color: PanergoColors.disabled),
            SizedBox(height: Space.s12),
            Text('Aucun quartier ne correspond',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            SizedBox(height: Space.s6),
            Text(
              'Panergo s’étend petit à petit. Si le vôtre manque, il arrivera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.muted),
            ),
          ],
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
        for (var i = 0; i < 8; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.s8),
            height: 60,
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
/// `Deïdo` and `Bepanda` has to find `Bépanda`.
String normalizeForSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');