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
import 'place_pickers.dart';

/// The quartiers of one town. Keyed by city so switching towns refetches.
final quartiersProvider = FutureProvider.family<List<Quartier>, String?>(
  (ref, cityId) => ref.read(apiProvider).quartiers(cityId: cityId),
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
  const QuartierPickerScreen({super.key, this.selected, this.cityId});

  /// Highlighted on open, so someone changing their mind sees where they were.
  final String? selected;

  /// Narrows the list to one town. Null lists everywhere Panergo serves.
  final String? cityId;

  /// Opens the picker and returns what was chosen, or null if they backed out.
  ///
  /// The choice comes back through the route rather than a callback: the rows
  /// are built inside two nested builders, and resolving a Navigator from one
  /// of those is the kind of thing that works until it quietly does not.
  static Future<Quartier?> show(BuildContext context,
          {String? selected, String? cityId}) =>
      Navigator.of(context).push<Quartier>(
        MaterialPageRoute<Quartier>(
          builder: (_) =>
              QuartierPickerScreen(selected: selected, cityId: cityId),
        ),
      );

  @override
  ConsumerState<QuartierPickerScreen> createState() =>
      _QuartierPickerScreenState();
}

class _QuartierPickerScreenState extends ConsumerState<QuartierPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Held once here: the rows are built inside two nested builders, each of
    // which shadows `context`, and popping the route from one of those is the
    // kind of thing that works right up until it does not.
    final rootContext = context;
    final async = ref.watch(quartiersProvider(widget.cityId));

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
                  onRetry: () => ref.invalidate(quartiersProvider(widget.cityId)),
                  errorTitle: 'Impossible de charger les quartiers',
                  skeleton: (_) => const _Skeleton(),
                  empty: (_) => const SizedBox.shrink(),
                  builder: (context, quartiers) {
                    final matches = quartiers
                        .where((q) =>
                            _query.isEmpty ||
                            normalizePlace(q.name)
                                .contains(normalizePlace(_query)))
                        .toList();

                    if (matches.isEmpty) return const _NoMatch();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Space.gutter, 0, Space.gutter, Space.s26),
                      itemCount: matches.length,
                      itemBuilder: (_, i) => PlaceRow(
                        icon: 'location_on',
                        label: matches[i].name,
                        detail: matches[i].city,
                        selected: matches[i].name == widget.selected,
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

