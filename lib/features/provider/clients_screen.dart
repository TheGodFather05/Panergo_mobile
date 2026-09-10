import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/material_symbol.dart';

final clientsProvider = FutureProvider.autoDispose<List<ClientSummary>>(
  (ref) => ref.read(apiProvider).clients(),
);

/// The people a provider has worked for.
///
/// A memory aid, not a CRM: no notes, no tags, nothing to send anyone. It turns
/// a list of finished jobs into the handful of names worth remembering, with the
/// ones who came back at the top.
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientsProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      appBar: AppBar(
        backgroundColor: PanergoColors.page,
        elevation: 0,
        leading: const BackButton(color: PanergoColors.ink),
        title: const Text('Mes clients',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
      ),
      body: AsyncView<List<ClientSummary>>(
        state: async.isLoading && !async.hasValue
            ? LoadState.loading
            : async.hasError && !async.hasValue
                ? LoadState.error
                : (async.value?.isEmpty ?? false)
                    ? LoadState.empty
                    : LoadState.normal,
        data: async.value,
        onRetry: () => ref.invalidate(clientsProvider),
        errorTitle: 'Impossible de charger vos clients',
        skeleton: (_) => const _Skeleton(),
        empty: (_) => const _NoClientsYet(),
        builder: (context, clients) => _Body(clients: clients),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.clients});

  final List<ClientSummary> clients;

  @override
  Widget build(BuildContext context) {
    final repeats = clients.where((c) => c.repeat).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s8, Space.gutterTight, Space.s26),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.gutterTight, left: 2),
          child: Text(
            // Both counts come from the list itself (§4.5).
            repeats == 0
                ? '${clients.length} client${clients.length > 1 ? 's' : ''}'
                : '${clients.length} clients · $repeats '
                    'fidèle${repeats > 1 ? 's' : ''}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PanergoColors.muted),
          ),
        ),
        for (final client in clients) _ClientRow(client: client),
      ],
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client});

  final ClientSummary client;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          _Initials(name: client.name),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        client.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: PanergoColors.ink),
                      ),
                    ),
                    // A word, not just a tint (RM-16).
                    if (client.repeat) ...[
                      const SizedBox(width: Space.s6),
                      const _RepeatChip(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(_summary,
                    style: const TextStyle(
                        fontSize: 12, color: PanergoColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: Space.s8),
          Text(
            Formats.money(client.totalValue),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink),
          ),
        ],
      ),
    );
  }

  String get _summary {
    final jobs = '${client.jobs} mission${client.jobs > 1 ? 's' : ''}';
    final last = client.lastHired;
    if (last == null) return jobs;
    return '$jobs · dernière ${Formats.relativeTime(last).toLowerCase()}';
  }
}

class _RepeatChip extends StatelessWidget {
  const _RepeatChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.brand.soft,
        borderRadius: BorderRadius.circular(Radii.badge),
      ),
      child: Text(
        'Fidèle',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: context.brand.link),
      ),
    );
  }
}

/// The design's avatar fallback: initials on a tinted tile.
class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length > 1
        ? '${parts.first[0]}${parts[1][0]}'
        : (name.isEmpty ? '?' : name[0]);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: PanergoColors.fillAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: PanergoColors.body),
        ),
      ),
    );
  }
}

class _NoClientsYet extends StatelessWidget {
  const _NoClientsYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('group',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.gutterTight),
            const Text('Pas encore de clients',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Les personnes pour qui vous terminez une mission apparaîtront '
              'ici.',
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
      padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.s8),
            height: 66,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
