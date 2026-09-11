import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/useful_button.dart';
import 'quartier_thread_screen.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

final quartierProvider =
    FutureProvider.autoDispose<List<QuartierPost>>((ref) async {
  final page = await ref.watch(apiProvider).quartier();
  return page.posts;
});

/// Quartier — the neighbourhood channel, promoted to a main tab (ADR-04).
class QuartierScreen extends ConsumerWidget {
  const QuartierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quartierProvider);
    final user = ref.watch(currentUserProvider);
    final posts = async.value ?? const <QuartierPost>[];

    return FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s12, Space.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quartier', style: context.type.h1),
                const SizedBox(height: Space.xs),
                Text(
                  user?.neighborhood.isNotEmpty == true
                      ? user!.neighborhood
                      : 'Votre quartier',
                  style: context.type.meta,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.gutterTight),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
            child: _Composer(
              name: user?.name ?? '',
              onTap: () => _compose(context, ref),
            ),
          ),
          const SizedBox(height: Space.gutterTight),
          Expanded(
            child: AsyncView<List<QuartierPost>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: posts.isEmpty,
              ),
              data: async.value,
              onRetry: () => ref.invalidate(quartierProvider),
              errorTitle: 'Impossible de charger le quartier',
              skeleton: (context) => const _QuartierSkeleton(),
              empty: (context) => const _EmptyQuartier(),
              builder: (context, items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(quartierProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, index) =>
                      _PostCard(post: items[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ComposeSheet(),
    );
    if (posted == true) ref.invalidate(quartierProvider);
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.s12),
      radius: Radii.card,
      child: Row(
        children: [
          InitialsAvatar(name: name, size: 36, radius: null),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Text('Poser une question au quartier…',
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.placeholder)),
          ),
          MaterialSymbol('campaign', size: 22, color: context.brand.link),
        ],
      ),
    );
  }
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet();

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _controller = TextEditingController();
  QuartierPostKind _kind = QuartierPostKind.question;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createQuartierPost(
            kind: _kind,
            body: _controller.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PanergoColors.page,
          borderRadius: Radii.brSheet,
        ),
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s12, Space.gutter, Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: Space.s18),
                decoration: BoxDecoration(
                  color: PanergoColors.disabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Publier dans le quartier', style: context.type.h3),
            const SizedBox(height: Space.gutterTight),
            Wrap(
              spacing: Space.s8,
              children: [
                for (final kind in QuartierPostKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: Space.gutterTight),
            Container(
              padding: const EdgeInsets.all(Space.s14),
              decoration: BoxDecoration(
                color: PanergoColors.surface,
                borderRadius: Radii.brCard,
                border: Border.all(color: PanergoColors.borderStrong),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'Que voulez-vous partager avec vos voisins ?',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.s12),
              Text(_error!,
                  style: context.type.bodySmall
                      .copyWith(color: PanergoColors.danger)),
            ],
            const SizedBox(height: Space.gutterTight),
            PanergoButton(
              label: 'Publier',
              enabled: _valid,
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final QuartierPost post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final tint = _kindTint(post.kind);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => QuartierThreadScreen(post: post),
        ),
      ),
      child: PanergoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: post.authorName, size: 40, radius: 12),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName, style: type.cardTitleSmall),
                    const SizedBox(height: 2),
                    Text(Formats.relativeTime(post.createdAt),
                        style: type.metaSmall),
                  ],
                ),
              ),
              StatusPill(
                label: post.kind.label,
                background: tint.tint,
                foreground: tint.foreground,
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          Text(post.body, style: type.body),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              // Reply count comes from a real count query, never a literal.
              Text(
                post.replyCount == 0
                    ? 'Aucune réponse'
                    : '${post.replyCount} réponse${post.replyCount > 1 ? 's' : ''}',
                style: type.metaSmall,
              ),
              const SizedBox(width: Space.s12),
              UsefulButton(kind: 'QUARTIER', postId: post.id),
              const Spacer(),
              Text('Répondre',
                  style: type.metaSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.brand.link,
                  )),
              const SizedBox(width: 3),
              MaterialSymbol('chevron_right',
                  size: 16, color: context.brand.link),
            ],
          ),
        ],
      ),
      ),
    );
  }

  static CategoryTint _kindTint(QuartierPostKind kind) => switch (kind) {
        QuartierPostKind.question => CategoryTints.at(4),
        QuartierPostKind.prestataire => CategoryTints.at(0),
        QuartierPostKind.recommandation => CategoryTints.at(3),
      };
}

class _EmptyQuartier extends StatelessWidget {
  const _EmptyQuartier();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('groups',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Le quartier est calme',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'Personne n’a encore publié ici. Posez la première question à '
                'vos voisins.',
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.subtle, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuartierSkeleton extends StatelessWidget {
  const _QuartierSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (context, index) => const PanergoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 40, height: 40, radius: 12),
                SizedBox(width: Space.s12),
                SkeletonBox(width: 120, height: 13),
              ],
            ),
            SizedBox(height: Space.s12),
            SkeletonBox(width: double.infinity, height: 12, light: true),
            SizedBox(height: Space.s6),
            SkeletonBox(width: 200, height: 12, light: true),
          ],
        ),
      ),
    );
  }
}
