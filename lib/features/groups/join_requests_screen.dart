import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';

/// The owner's queue: who has asked to come in.
///
/// Oldest first — whoever waited longest is answered first. Each decision is
/// final in the sense that it cannot be taken twice, but a refusal is not a
/// ban: the person may ask again another day.
class JoinRequestsScreen extends ConsumerStatefulWidget {
  const JoinRequestsScreen({super.key, required this.group});

  final GroupSummary group;

  @override
  ConsumerState<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends ConsumerState<JoinRequestsScreen> {
  /// Requests currently being decided, so a second tap cannot double-send.
  final _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupJoinRequestsProvider(widget.group.id));
    final requests = async.value ?? const <GroupPerson>[];

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Demandes',
              subtitle: widget.group.name,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AsyncView<List<GroupPerson>>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: requests.isEmpty,
                ),
                data: requests,
                onRetry: () =>
                    ref.invalidate(groupJoinRequestsProvider(widget.group.id)),
                errorTitle: 'Demandes indisponibles',
                skeleton: (_) => const _Skeleton(),
                empty: (_) => const _Empty(),
                builder: (context, items) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  children: [
                    for (final person in items)
                      _RequestCard(
                        person: person,
                        busy: _busy.contains(person.id),
                        onAccept: () => _decide(person, accept: true),
                        onDecline: () => _decide(person, accept: false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(GroupPerson person, {required bool accept}) async {
    if (_busy.contains(person.id)) return;
    setState(() => _busy.add(person.id));

    try {
      await ref.read(apiProvider).decideGroupJoinRequest(
            widget.group.id,
            person.id,
            accept: accept,
          );
      ref.invalidate(groupJoinRequestsProvider(widget.group.id));
      ref.invalidate(groupMembersProvider(widget.group.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(accept
                ? '${person.userName} a rejoint le groupe.'
                : 'Demande de ${person.userName} refusée.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      // Somebody else may have decided it already; take the server's word.
      ref.invalidate(groupJoinRequestsProvider(widget.group.id));
    } finally {
      if (mounted) setState(() => _busy.remove(person.id));
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.person,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final GroupPerson person;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCardLarge,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(
                    name: person.userName,
                    photoUrl: person.userPhotoUrl,
                    size: 44,
                    radius: 13),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.userName,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: PanergoColors.ink)),
                      const SizedBox(height: 2),
                      Text(
                        // Where they are is the fact an owner judges on, for a
                        // quartier group especially.
                        [
                          person.userNeighborhood,
                          Formats.relativeTime(person.createdAt),
                        ].where((p) => p != null && p.isNotEmpty).join(' · '),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PanergoColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (person.message != null && person.message!.isNotEmpty) ...[
              const SizedBox(height: Space.s12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.s12),
                decoration: BoxDecoration(
                  color: PanergoColors.fill,
                  borderRadius: Radii.brCard,
                ),
                child: Text(person.message!,
                    style: const TextStyle(
                        fontSize: 13, height: 1.45, color: PanergoColors.body)),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _Decision(
                    label: 'Refuser',
                    solid: false,
                    onTap: busy ? null : onDecline,
                  ),
                ),
                const SizedBox(width: Space.s8),
                Expanded(
                  child: _Decision(
                    label: 'Accepter',
                    solid: true,
                    onTap: busy ? null : onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Decision extends StatelessWidget {
  const _Decision({
    required this.label,
    required this.solid,
    required this.onTap,
  });

  final String label;
  final bool solid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: solid ? brand.fill : PanergoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: solid ? null : Border.all(color: PanergoColors.borderStrong),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: solid ? Colors.white : PanergoColors.body)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Text(
          'Personne n’attend. Les nouvelles demandes apparaîtront ici.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: PanergoColors.muted),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (_, __) => Container(
        height: 150,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCardLarge,
        ),
      ),
    );
  }
}
