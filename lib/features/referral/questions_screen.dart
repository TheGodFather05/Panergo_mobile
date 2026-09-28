import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/panergo_api.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'question_detail_screen.dart';
import 'question_settings_screen.dart';
import 'question_vocabulary.dart';

/// How the four question screens reach their data.
///
/// One set of screens serves shops and artisans — the design builds them from a
/// single markup block and an `isShopQ` flag — so what differs is the endpoint
/// and the vocabulary, not the layout. This carries both.
class QuestionSource {
  const QuestionSource({
    required this.audience,
    required this.businessId,
    required this.title,
  });

  /// For a shop, whose questions are addressed by the shop's id.
  factory QuestionSource.shop({
    required String businessId,
    required String businessName,
  }) =>
      QuestionSource(
        audience: QuestionAudience.shop,
        businessId: businessId,
        title: businessName,
      );

  /// For an artisan, addressed by the token — they have one provider record.
  const QuestionSource.trade()
      : audience = QuestionAudience.trade,
        businessId = null,
        title = 'Espace prestataire';

  final QuestionAudience audience;
  final String? businessId;
  final String title;

  bool get isShop => audience == QuestionAudience.shop;

  Future<List<ShopInboxItem>> load(PanergoApi api) =>
      isShop ? api.shopInquiries(businessId!) : api.tradeInquiries();

  Future<void> answer(
    PanergoApi api,
    String inquiryId, {
    required bool yes,
    int? price,
    String? chip,
    String? note,
  }) =>
      isShop
          ? api.answerShopInquiry(businessId!, inquiryId,
              hasItem: yes, price: price, unit: chip, note: note)
          : api.answerTradeInquiry(inquiryId,
              canDo: yes, price: price, availability: chip, note: note);
}

final _questionsProvider = FutureProvider.autoDispose
    .family<List<ShopInboxItem>, QuestionSource>((ref, source) async =>
        source.load(ref.watch(apiProvider)));

/// « Questions des clients » — the list.
///
/// Design `m_questions` / `p_questions`. The closing note is the one that makes
/// the screen safe to ignore: « Personne ne voit que vous n'avez pas répondu. »
/// Without it, an unanswered list reads as a scoreboard.
class QuestionsScreen extends ConsumerWidget {
  const QuestionsScreen({super.key, required this.source});

  final QuestionSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_questionsProvider(source));
    final items = async.value ?? const <ShopInboxItem>[];
    final open = items.where((i) => !i.answered).length;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Questions des clients',
              subtitle: async.hasValue
                  ? (open == 0
                      ? 'Toutes répondues'
                      : '$open sans réponse')
                  : null,
              onBack: () => Navigator.of(context).maybePop(),
              trailing: _SettingsButton(source: source),
            ),
            Expanded(
              child: AsyncView<List<ShopInboxItem>>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: items.isEmpty,
                ),
                data: items,
                onRetry: () => ref.invalidate(_questionsProvider(source)),
                errorTitle: 'Chargement impossible',
                skeleton: (_) => const _QuestionsSkeleton(),
                empty: (_) => _NoQuestions(audience: source.audience),
                builder: (context, rows) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_questionsProvider(source)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutterTight, 0, Space.gutterTight, Space.s30),
                    children: [
                      for (final item in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.listGap),
                          child: _QuestionRow(
                            item: item,
                            source: source,
                            onChanged: () =>
                                ref.invalidate(_questionsProvider(source)),
                          ),
                        ),
                      const SizedBox(height: Space.s8),
                      // The reason this list is safe to leave alone.
                      Text(
                        'Les questions disparaissent à leur expiration. '
                        'Personne ne voit que vous n’avez pas répondu.',
                        style: context.type.metaSmall.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.source});

  final QuestionSource source;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QuestionSettingsScreen(source: source),
      )),
      icon: const MaterialSymbol('tune', size: 17, color: PanergoColors.ink2),
      label: Text('Réglages',
          style: context.type.labelSmall.copyWith(color: PanergoColors.ink2)),
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Space.s8),
          minimumSize: const Size(0, 34)),
    );
  }
}

/// One row: where it came from, the question, and what you said or have not.
class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.item,
    required this.source,
    required this.onChanged,
  });

  final ShopInboxItem item;
  final QuestionSource source;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final answered = item.answered;
    final yes = item.hasItem == true;

    return InkWell(
      borderRadius: Radii.brCardLarge,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => QuestionDetailScreen(item: item, source: source),
          ),
        );
        if (changed == true) onChanged();
      },
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCardLarge,
          // Unanswered takes an ink border, so what is outstanding is visible
          // before a word is read.
          border: Border.all(
            color: answered ? PanergoColors.border : PanergoColors.ink,
            width: answered ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client de ${item.neighborhood} · '
              '${Formats.relativeTime(item.askedAt)}',
              style: context.type.metaSmall,
            ),
            const SizedBox(height: Space.s8),
            Text('« ${item.text} »',
                style: context.type.bodyLarge
                    .copyWith(height: 1.4, color: PanergoColors.ink)),
            const SizedBox(height: Space.s12),
            Row(
              children: [
                MaterialSymbol(
                    answered
                        ? (yes ? 'check_circle' : 'do_not_disturb_on')
                        : 'schedule',
                    size: 17,
                    color: answered
                        ? (yes
                            ? PanergoColors.statusDoneInk
                            : PanergoColors.subtle)
                        : PanergoColors.ink),
                const SizedBox(width: Space.s6),
                Expanded(
                  child: Text(
                    answered
                        ? source.audience.answerSummary(
                            yes: yes, price: item.price, chip: item.unit)
                        : 'Sans réponse · ${_until(item.expiresAt)}',
                    style: context.type.metaSmall.copyWith(height: 1.4),
                  ),
                ),
                Text(answered ? 'Modifier' : 'Répondre',
                    style: context.type.labelSmall
                        .copyWith(color: context.brand.link)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _until(DateTime when) {
    final left = when.difference(DateTime.now());
    if (left.isNegative) return 'expirée';
    if (left.inHours < 24) return 'jusqu’à ${Formats.conversationTime(when)}';
    return 'jusqu’à demain ${Formats.conversationTime(when)}';
  }
}

class _NoQuestions extends StatelessWidget {
  const _NoQuestions({required this.audience});

  final QuestionAudience audience;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('forum', size: 34, color: PanergoColors.faint),
            const SizedBox(height: Space.s12),
            Text('Aucune question pour l’instant',
                style: context.type.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: Space.s6),
            Text(
              audience == QuestionAudience.shop
                  ? 'Quand un client cherche un article que vous pourriez '
                      'avoir, sa question arrive ici.'
                  : 'Quand un client se demande si un travail est faisable, '
                      'sa question arrive ici.',
              style: context.type.bodySmall.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionsSkeleton extends StatelessWidget {
  const _QuestionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.s30),
      children: const [
        SkeletonBox(height: 132),
        SizedBox(height: Space.listGap),
        SkeletonBox(height: 132),
      ],
    );
  }
}
