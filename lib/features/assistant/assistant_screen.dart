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
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../client/new_request_screen.dart';
import '../client/reviews_screen.dart';

/// One exchange in the assistant thread.
sealed class AssistantTurn {
  const AssistantTurn();
}

class UserAsked extends AssistantTurn {
  const UserAsked(this.text);

  final String text;
}

class AssistantThinking extends AssistantTurn {
  const AssistantThinking();
}

class AssistantReplied extends AssistantTurn {
  const AssistantReplied({
    required this.answer,
    required this.category,
    required this.neighborhood,
  });

  final AssistantAnswer answer;

  /// What the search was actually scoped to — the copy has to be able to say
  /// so when nothing came back.
  final ServiceCategory? category;
  final String neighborhood;

  bool get isEmpty => answer.providers.isEmpty;
}

class AssistantFailed extends AssistantTurn {
  const AssistantFailed(this.error);

  final ApiException error;
}

/// Assistant IA (screen 4) — the primary way into the product (ADR-03).
///
/// Runs full height with no tab bar: a thread of what was asked and what came
/// back, with the composer pinned at the bottom.
///
/// The search is only as good as its scope. The backend returns nothing unless
/// it knows both a category and a neighbourhood — it infers the category from
/// the words when it can, and never infers the neighbourhood — so this screen
/// supplies the user's own quartier and says which scope it used.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialCategory, this.initialQuery});

  final ServiceCategory? initialCategory;
  final String? initialQuery;

  static Route<void> route({
    ServiceCategory? initialCategory,
    String? initialQuery,
  }) =>
      MaterialPageRoute(
        builder: (_) => AssistantScreen(
          initialCategory: initialCategory,
          initialQuery: initialQuery,
        ),
      );

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  final List<AssistantTurn> _turns = [];

  ServiceCategory? _category;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;

    final seed = widget.initialQuery?.trim();
    if (seed != null && seed.isNotEmpty) {
      // Coming from the home card with something already typed: ask it rather
      // than making the user type it twice.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(seed));
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _neighborhood {
    final quartier = ref.read(currentUserProvider)?.neighborhood ?? '';
    return quartier.isEmpty ? 'Douala' : quartier;
  }

  Future<void> _ask(String raw) async {
    final query = raw.trim();
    if (query.isEmpty || _busy) return;

    final neighborhood = _neighborhood;

    setState(() {
      _turns
        ..add(UserAsked(query))
        ..add(const AssistantThinking());
      _busy = true;
      _composer.clear();
    });
    _scrollToEnd();

    try {
      final answer = await ref.read(apiProvider).assistantSearch(
            query: query,
            category: _category,
            neighborhood: neighborhood,
          );
      if (!mounted) return;
      setState(() {
        _turns
          ..removeLast()
          ..add(AssistantReplied(
            answer: answer,
            category: _category,
            neighborhood: neighborhood,
          ));
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _turns
          ..removeLast()
          ..add(AssistantFailed(e));
        _busy = false;
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.slideIn,
        curve: Curves.easeOut,
      );
    });
  }

  void _openRequest() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewRequestScreen(initialCategory: _category),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            _AssistantHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: _turns.isEmpty
                  ? _Intro(
                      neighborhood: _neighborhood,
                      onSuggestion: _ask,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                          Space.gutterTight, Space.s12, Space.gutterTight,
                          Space.s12),
                      itemCount: _turns.length,
                      itemBuilder: (context, index) => _TurnView(
                        turn: _turns[index],
                        onOpenRequest: _openRequest,
                      ),
                    ),
            ),
            _Composer(
              controller: _composer,
              category: _category,
              busy: _busy,
              onCategoryChanged: (value) => setState(() => _category = value),
              onSend: () => _ask(_composer.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Space.s10, Space.s8, Space.gutterTight, Space.s10),
      decoration: const BoxDecoration(
        color: PanergoColors.surface,
        border: Border(bottom: BorderSide(color: PanergoColors.border)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Retour',
            child: InkWell(
              onTap: onBack,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Center(
                  child: MaterialSymbol('arrow_back',
                      size: 24, color: PanergoColors.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.s6),
          const _AssistantMark(size: 42, radius: 13, iconSize: 22),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Assistant Panergo',
                    style: context.type.cardTitle.copyWith(height: 1.1)),
                const SizedBox(height: Space.xxs),
                Text('Recherche intelligente · IA',
                    style: context.type.metaSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark tile with the accent spark that stands for the assistant.
class _AssistantMark extends StatelessWidget {
  const _AssistantMark({
    required this.size,
    required this.radius,
    required this.iconSize,
  });

  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PanergoColors.ink,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: MaterialSymbol('auto_awesome',
          size: iconSize, color: context.brand.accent, filled: true),
    );
  }
}

/// What the user sees before asking anything: what this can do, where it is
/// looking, and three ways to start.
class _Intro extends StatelessWidget {
  const _Intro({required this.neighborhood, required this.onSuggestion});

  final String neighborhood;
  final ValueChanged<String> onSuggestion;

  static const _suggestions = [
    'Une fuite sous mon évier',
    'Mon frigo ne refroidit plus',
    'Panne de courant dans le salon',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s26, Space.gutter, Space.gutter),
      children: [
        const Center(child: _AssistantMark(size: 56, radius: 18, iconSize: 28)),
        const SizedBox(height: Space.gutterTight),
        Text(
          'Décrivez votre besoin',
          textAlign: TextAlign.center,
          style: context.type.h2,
        ),
        const SizedBox(height: Space.s8),
        Text(
          'En quelques mots, comme à un voisin. L’assistant cherche des '
          'prestataires actifs à $neighborhood et vous montre leurs chiffres — '
          'il ne recommande personne.',
          textAlign: TextAlign.center,
          style: context.type.bodySmall
              .copyWith(color: PanergoColors.subtle, height: 1.55),
        ),
        const SizedBox(height: Space.s26),
        Text('POUR COMMENCER', style: context.type.micro),
        const SizedBox(height: Space.s12),
        for (final suggestion in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s10),
            child: PanergoCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s14, vertical: 13),
              radius: Radii.card,
              onTap: () => onSuggestion(suggestion),
              child: Row(
                children: [
                  Expanded(
                    child: Text(suggestion, style: context.type.bodySmall),
                  ),
                  const MaterialSymbol('arrow_outward',
                      size: 17, color: PanergoColors.disabled),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn, required this.onOpenRequest});

  final AssistantTurn turn;
  final VoidCallback onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return switch (turn) {
      UserAsked(:final text) => _UserBubble(text: text),
      AssistantThinking() => const _ThinkingRow(),
      AssistantFailed(:final error) => _AssistantRow(
          child: _FailureNote(error: error),
        ),
      AssistantReplied(:final answer, :final category, :final neighborhood) =>
        _AssistantRow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The observation is null whenever the model is switched off
              // server-side, which is the default — so the results have to
              // stand on their own without it.
              if (answer.observation != null &&
                  answer.observation!.trim().isNotEmpty) ...[
                Text(answer.observation!.trim(),
                    style: context.type.bodySmall.copyWith(height: 1.55)),
                const SizedBox(height: Space.s12),
              ] else if (answer.providers.isNotEmpty) ...[
                Text(
                  '${answer.providers.length} prestataire'
                  '${answer.providers.length > 1 ? 's' : ''} '
                  '${answer.providers.length > 1 ? 'actifs' : 'actif'} à '
                  '$neighborhood.',
                  style: context.type.bodySmall.copyWith(height: 1.55),
                ),
                const SizedBox(height: Space.s12),
              ],
              if (answer.providers.isEmpty)
                _NoResults(
                  category: category,
                  neighborhood: neighborhood,
                  onOpenRequest: onOpenRequest,
                )
              else ...[
                for (final result in answer.providers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s10),
                    child: _ResultCard(result: result),
                  ),
                const SizedBox(height: Space.xs),
                _PostRequestNote(onOpenRequest: onOpenRequest),
              ],
            ],
          ),
        ),
    };
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.gutterTight),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: Space.s10),
            decoration: BoxDecoration(
              color: context.brand.fill,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radii.bubbleTail,
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Text(
              text,
              style: context.type.bodySmall.copyWith(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The assistant speaks as plain text beside its mark, never in a bubble — it
/// is the room's narrator, not another participant.
class _AssistantRow extends StatelessWidget {
  const _AssistantRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.gutterTight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantMark(size: 30, radius: 9, iconSize: 17),
          const SizedBox(width: Space.s10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    return _AssistantRow(
      child: Padding(
        padding: const EdgeInsets.only(top: Space.s6),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Space.s10),
            Text('Recherche en cours…', style: context.type.metaSmall),
          ],
        ),
      ),
    );
  }
}

/// One provider, with the numbers the backend actually holds. Anything it had
/// no data for is named as missing rather than quietly omitted.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final AssistantResult result;

  void _openReviews(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReviewsScreen(
        providerId: result.providerId,
        providerName: result.name,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final missing = result.dataMissing.toSet();

    return PanergoCard(
      padding: const EdgeInsets.all(14),
      radius: Radii.card,
      onTap: () => _openReviews(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                  name: result.name, photoUrl: result.photoUrl, size: 44),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.cardTitleSmall),
                    const SizedBox(height: 2),
                    Text(result.category.label, style: context.type.metaSmall),
                  ],
                ),
              ),
              RatingBadge(
                rating: result.avgRating,
                reviewCount: result.completedBookings,
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          const Divider(height: 1, color: PanergoColors.border),
          const SizedBox(height: Space.s12),
          Wrap(
            spacing: Space.s18,
            runSpacing: Space.s10,
            children: [
              _Stat(
                icon: 'task_alt',
                label: 'Missions',
                value: '${result.completedBookings}',
              ),
              _Stat(
                icon: 'schedule',
                label: 'Réponse',
                value: missing.contains('avg_response_time_hours')
                    ? null
                    : '${Formats.rating(result.avgResponseTimeHours ?? 0)} h',
              ),
              _Stat(
                icon: 'sell',
                label: 'Dernier prix',
                value: missing.contains('price_from_last_offer') ||
                        result.priceFromLastOffer == null
                    ? null
                    : Formats.money(result.priceFromLastOffer!),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single figure. A null [value] is stated as unavailable — the assistant's
/// whole premise is that it does not invent what it does not have.
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final String icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final known = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            MaterialSymbol(icon, size: 14, color: PanergoColors.subtle),
            const SizedBox(width: Space.xs),
            Text(label, style: context.type.metaSmall),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          known ? value! : 'Non disponible',
          style: context.type.labelSmall.copyWith(
            color: known ? PanergoColors.ink : PanergoColors.faint,
            fontStyle: known ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Nothing matched. The scope is stated plainly, because "no results" without
/// it reads as "nobody exists" rather than "nobody here, in this trade".
class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.category,
    required this.neighborhood,
    required this.onOpenRequest,
  });

  final ServiceCategory? category;
  final String neighborhood;
  final VoidCallback onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final trade = category?.label.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trade == null
              ? 'Je n’ai pas reconnu le métier concerné, donc je n’ai trouvé '
                  'personne à $neighborhood.'
              : 'Aucun prestataire en $trade actif à $neighborhood en ce '
                  'moment.',
          style: context.type.bodySmall.copyWith(height: 1.55),
        ),
        const SizedBox(height: Space.s12),
        PanergoCard(
          padding: const EdgeInsets.all(Space.s14),
          radius: Radii.card,
          onTap: onOpenRequest,
          child: Row(
            children: [
              MaterialSymbol('campaign', size: 20, color: context.brand.link),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Publier une demande',
                        style: context.type.cardTitleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Les prestataires du quartier vous répondent avec un '
                      'prix et un délai.',
                      style: context.type.metaSmall.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              const MaterialSymbol('chevron_right',
                  size: 20, color: PanergoColors.disabled),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostRequestNote extends StatelessWidget {
  const _PostRequestNote({required this.onOpenRequest});

  final VoidCallback onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onOpenRequest,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: Space.s6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
      ),
      child: Text(
        'Ou publiez une demande et laissez-les vous proposer un prix →',
        style: context.type.labelSmall.copyWith(color: context.brand.link),
      ),
    );
  }
}

class _FailureNote extends StatelessWidget {
  const _FailureNote({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MaterialSymbol(error.isOffline ? 'cloud_off' : 'error',
            size: 17, color: PanergoColors.errorIcon),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Text(
            error.isOffline
                ? 'Vous êtes hors ligne. Réessayez dès que le réseau revient.'
                : error.message,
            style: context.type.bodySmall.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// The composer: a category scope, the input, and send. The mic keeps its place
/// as the accessibility keystone even though dictation is not wired yet.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.category,
    required this.busy,
    required this.onCategoryChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final ServiceCategory? category;
  final bool busy;
  final ValueChanged<ServiceCategory?> onCategoryChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Space.s14,
        Space.s10,
        Space.s14,
        MediaQuery.viewInsetsOf(context).bottom > 0 ? Space.s10 : Space.s16,
      ),
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        border: Border(top: BorderSide(color: PanergoColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScopeChip(category: category, onChanged: onCategoryChanged),
          const SizedBox(height: Space.s10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: PanergoColors.surface,
                    border: Border.all(color: PanergoColors.borderStrong),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.s16, vertical: Space.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !busy,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          style: context.type.body.copyWith(
                              fontSize: 14, color: PanergoColors.ink),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: Space.s8),
                            hintText: 'Décrivez votre besoin…',
                            hintStyle: context.type.body.copyWith(
                                fontSize: 14,
                                color: PanergoColors.placeholder),
                          ),
                        ),
                      ),
                      // The accessibility keystone of the product: prominent
                      // even while dictation is still to be wired.
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.s6),
                        child: Semantics(
                          button: true,
                          enabled: false,
                          label: 'Décrire vocalement',
                          child: MaterialSymbol('mic',
                              size: 21, color: brand.link),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final ready = value.text.trim().isNotEmpty && !busy;
                  return Semantics(
                    button: true,
                    enabled: ready,
                    label: 'Rechercher',
                    child: InkWell(
                      onTap: ready ? onSend : null,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ready
                              ? brand.fill
                              : PanergoColors.disabledButton,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: MaterialSymbol(
                            'arrow_upward',
                            size: 21,
                            color: ready
                                ? Colors.white
                                : PanergoColors.disabledLabel,
                            filled: true,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Narrows the search to one trade. Left alone, the backend reads the trade out
/// of the words instead.
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.category, required this.onChanged});

  final ServiceCategory? category;
  final ValueChanged<ServiceCategory?> onChanged;

  Future<void> _pick(BuildContext context) async {
    // Dismissing returns null; clearing the scope returns a choice that holds
    // null. Without the wrapper the two are indistinguishable.
    final picked = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      backgroundColor: PanergoColors.page,
      shape: const RoundedRectangleBorder(borderRadius: Radii.brSheet),
      isScrollControlled: true,
      builder: (context) => _CategorySheet(selected: category),
    );
    if (picked != null) onChanged(picked.category);
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final scoped = category != null;

    return Semantics(
      button: true,
      label: 'Choisir un métier',
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: Radii.brChip,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s12, vertical: Space.s6),
          decoration: BoxDecoration(
            color: scoped ? brand.soft : PanergoColors.fill,
            borderRadius: Radii.brChip,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MaterialSymbol(
                scoped ? category!.iconName : 'tune',
                size: 15,
                color: scoped ? brand.link : PanergoColors.muted,
              ),
              const SizedBox(width: Space.s6),
              Text(
                scoped ? category!.label : 'Tous les métiers',
                style: context.type.metaSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scoped ? brand.link : PanergoColors.muted,
                ),
              ),
              const SizedBox(width: Space.xs),
              MaterialSymbol('expand_more',
                  size: 15,
                  color: scoped ? brand.link : PanergoColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A choice actually made in the sheet — `category` null means "every trade".
class _CategoryChoice {
  const _CategoryChoice(this.category);

  final ServiceCategory? category;
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.selected});

  final ServiceCategory? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Space.s12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: PanergoColors.borderDashed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Space.gutterTight),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Row(
                children: [
                  Text('Métier', style: context.type.h3),
                ],
              ),
            ),
            const SizedBox(height: Space.s12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                children: [
                  _Row(
                    label: 'Tous les métiers',
                    icon: 'tune',
                    active: selected == null,
                    onTap: () => Navigator.of(context)
                        .pop(const _CategoryChoice(null)),
                  ),
                  for (final category in ServiceCategory.values)
                    _Row(
                      label: category.label,
                      icon: category.iconName,
                      active: selected == category,
                      onTap: () =>
                          Navigator.of(context).pop(_CategoryChoice(category)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brTile,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s12, vertical: 13),
        child: Row(
          children: [
            MaterialSymbol(icon,
                size: 19,
                color: active ? brand.link : PanergoColors.muted),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(
                label,
                style: context.type.bodySmall.copyWith(
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? brand.link : PanergoColors.ink,
                ),
              ),
            ),
            if (active)
              MaterialSymbol('check', size: 19, color: brand.link),
          ],
        ),
      ),
    );
  }
}
