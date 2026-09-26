import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_prompt.dart';

import '../../core/models/enums.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../assistant/assistant_screen.dart';
import 'categories_screen.dart';
import 'new_request_screen.dart';

/// Accueil — the client's entry point (home layout variant B).
///
/// The assistant card is the primary way in (ADR-03), and the mic inside it is
/// the accessibility keystone of the product, so it stays prominent. Sponsored
/// content sits below the organic content and never moves above the fold.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _assistantQuery = TextEditingController();

  ServiceCategory? _assistantCategory;

  @override
  void dispose() {
    _assistantQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final firstName = (user?.name ?? '').split(' ').first;
    final quartier =
        (user?.neighborhood.isNotEmpty ?? false) ? user!.neighborhood : 'Douala';

    return FadeUp(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s6, Space.gutter,
            Space.s26 + Clearance.askButton),
        children: [
          _TopRow(
              quartier: quartier,
              name: user?.name ?? '',
              photoUrl: user?.photoUrl),
          const SizedBox(height: Space.s22),
          _Headline(firstName: firstName),
          const SizedBox(height: Space.s18),
          _AssistantCard(
            controller: _assistantQuery,
            category: _assistantCategory,
            onCategoryChanged: (value) =>
                setState(() => _assistantCategory = value),
            onSearch: _openAssistant,
            onAttach: _attach,
          ),
          const SizedBox(height: Space.s26),
          _SectionHeader(
            label: 'Catégories',
            actionLabel: 'Voir tout',
            onAction: _openCategories,
          ),
          const SizedBox(height: Space.s12),
          _CategoryStrip(onSelected: _openRequestFor, onSeeAll: _openCategories),
          const SizedBox(height: Space.s10),
          const _CoverageNote(),

        ],
      ),
    );
  }

  void _openCategories() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoriesScreen(onSelected: _openRequestFor),
    ));
  }

  /// The assistant is the primary entry (ADR-03), so the card opens it rather
  /// than skipping ahead to the tender form.
  ///
  /// Whatever was typed on the card travels with it: the assistant screen asks
  /// on arrival rather than showing an empty composer somebody has already
  /// filled in once.
  void _openAssistant() {
    final query = _assistantQuery.text.trim();

    Navigator.of(context)
        .push(AssistantScreen.route(
          initialCategory: _assistantCategory,
          initialQuery: query.isEmpty ? null : query,
        ))
        // Cleared on the way out, not on the way in: coming back to a card
        // still holding the last question invites asking it twice.
        .then((_) {
          if (mounted) setState(_assistantQuery.clear);
        });
  }

  /// The three buttons under the composer.
  ///
  /// None of them attaches anything to the assistant, and that is not an
  /// oversight: the assistant matches artisans on the words of the question,
  /// so a photograph or a recording would change nothing it answers. Rather
  /// than pretend otherwise, each says what it can and cannot do yet.
  void _attach(AssistantAttachment kind) {
    final message = switch (kind) {
      AssistantAttachment.photo =>
        'Une photo aide surtout l’artisan à chiffrer. Décrivez d’abord votre '
            'besoin, vous pourrez l’ajouter à votre demande.',
      AssistantAttachment.file =>
        'Les pièces jointes arrivent bientôt. Décrivez votre besoin en '
            'quelques mots pour l’instant.',
      AssistantAttachment.voice =>
        'La description vocale arrive bientôt. En attendant, écrivez votre '
            'besoin — même en une ligne.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  void _openRequestFor(ServiceCategory? category) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewRequestScreen(initialCategory: category),
    ));
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.quartier, required this.name, this.photoUrl});

  final String quartier;
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Row(
      children: [
        MaterialSymbol('location_on',
            size: 19, color: brand.link, filled: true),
        const SizedBox(width: Space.s6),
        Text(quartier,
            style: context.type.body.copyWith(
                fontWeight: FontWeight.w700, color: PanergoColors.ink)),
        const Spacer(),
        InitialsAvatar(name: name, photoUrl: photoUrl, size: 40, radius: null),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return RichText(
      text: TextSpan(
        style: type.display,
        children: [
          const TextSpan(text: 'Quel service vous\nfaut-il'),
          if (firstName.isNotEmpty) ...[
            const TextSpan(text: ', '),
            TextSpan(
              text: firstName,
              style: type.display.copyWith(color: context.brand.link),
            ),
          ],
          const TextSpan(text: ' ?'),
        ],
      ),
    );
  }
}

/// The assistant entry point: a prompt line, a category picker, and the
/// camera / attach / mic row above the search action.
class _AssistantCard extends StatefulWidget {
  const _AssistantCard({
    required this.controller,
    required this.category,
    required this.onCategoryChanged,
    required this.onSearch,
    required this.onAttach,
  });

  final TextEditingController controller;
  final ServiceCategory? category;
  final ValueChanged<ServiceCategory?> onCategoryChanged;
  final VoidCallback onSearch;
  final ValueChanged<AssistantAttachment> onAttach;

  @override
  State<_AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends State<_AssistantCard> {
  final _focus = FocusNode();
  final _prompt = GlobalKey<AssistantPromptState>();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    // Stops the examples the moment somebody means to type.
    if (_focus.hasFocus) _prompt.currentState?.stop();
    setState(() {});
  }

  /// Rebuilds for the send button, which turns from outline to filled on the
  /// first character.
  void _onTextChange() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hasText = widget.controller.text.trim().isNotEmpty;

    return PanergoCard(
      elevated: true,
      radius: Radii.assistant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brand.soft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: MaterialSymbol('auto_awesome',
                    size: 19, color: brand.link, filled: true),
              ),
              const SizedBox(width: 9),
              Text('Assistant Panergo',
                  style: type.cardTitleSmall.copyWith(fontSize: 13.5)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: Space.s8, vertical: 3),
                decoration: BoxDecoration(
                  color: brand.soft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('IA',
                    style: type.microTight
                        .copyWith(fontSize: 9.5, color: brand.link, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: Space.s12),

          // The well is the whole answer to "it does not look like it wants
          // anything from you": a sunken ground with a visible caret reads as
          // somewhere to write, for everybody and on every open. The moving
          // examples only teach *what* to ask, which is why they stop.
          GestureDetector(
            onTap: () {
              _prompt.currentState?.stop();
              _focus.requestFocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(Space.s14),
              decoration: BoxDecoration(
                color: PanergoColors.fill,
                borderRadius: BorderRadius.circular(14),
                // Inset, so focus changes nothing's position — the card must
                // not move while the keyboard is already moving.
                border: Border.all(
                  color: _focus.hasFocus
                      ? PanergoColors.ink
                      : PanergoColors.border,
                  width: _focus.hasFocus ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.search,
                    cursorColor: brand.link,
                    onSubmitted: (_) => widget.onSearch(),
                    style: type.bodyLarge.copyWith(
                      fontSize: 16,
                      color: PanergoColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  // Drawn rather than a hintText, because it carries the caret
                  // and the rotation. Hidden the moment there is real text.
                  if (!hasText)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: widget.category == null
                            ? AssistantPrompt(
                                key: _prompt,
                                showCaret: !_focus.hasFocus,
                                style: type.bodyLarge.copyWith(
                                  fontSize: 16,
                                  color: PanergoColors.placeholder,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            // With a trade chosen the examples would contradict
                            // it, so the invitation names the trade instead.
                            : Text(
                                'Votre besoin en '
                                '${widget.category!.label.toLowerCase()}…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.bodyLarge.copyWith(
                                  fontSize: 16,
                                  color: PanergoColors.placeholder,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // With animations reduced the examples never play, so the same
          // teaching is said once, in a fixed line.
          if (reduced && !hasText) ...[
            const SizedBox(height: Space.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                'Par exemple : une fuite dans la cuisine, un électricien ce soir.',
                style: type.metaSmall.copyWith(height: 1.4),
              ),
            ),
          ],

          const SizedBox(height: Space.s14),
          _CategoryPicker(
              value: widget.category, onChanged: widget.onCategoryChanged),
          const SizedBox(height: Space.s14),
          const Divider(height: 1, color: PanergoColors.fillAlt),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              // A photograph belongs on the demande, where an artisan reading
              // it can act on it — the assistant matches on the words alone,
              // so attaching one here would change nothing it answers.
              _ToolButton(
                icon: 'photo_camera',
                semanticLabel: 'Ajouter une photo à votre demande',
                onTap: () => widget.onAttach(AssistantAttachment.photo),
              ),
              const SizedBox(width: Space.s8),
              _ToolButton(
                icon: 'attach_file',
                semanticLabel: 'Joindre un fichier à votre demande',
                onTap: () => widget.onAttach(AssistantAttachment.file),
              ),
              const SizedBox(width: Space.s8),
              // The mic is the accessibility keystone — kept prominent.
              _ToolButton(
                icon: 'mic',
                semanticLabel: 'Décrire vocalement',
                filled: true,
                onTap: () => widget.onAttach(AssistantAttachment.voice),
              ),
              const Spacer(),
              _SearchButton(enabled: hasText, onPressed: widget.onSearch),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.value, required this.onChanged});

  final ServiceCategory? value;
  final ValueChanged<ServiceCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Semantics(
      button: true,
      label: 'Catégorie : ${value?.label ?? 'toutes les catégories'}',
      child: InkWell(
        borderRadius: Radii.brTile,
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 13, vertical: Space.s12),
          decoration: BoxDecoration(
            color: PanergoColors.fill,
            borderRadius: Radii.brTile,
          ),
          child: Row(
            children: [
              MaterialSymbol(value?.iconName ?? 'apps',
                  size: 19, color: brand.link),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  value?.label ?? 'Toutes les catégories',
                  overflow: TextOverflow.ellipsis,
                  style: context.type.body.copyWith(
                      fontWeight: FontWeight.w700, color: PanergoColors.ink),
                ),
              ),
              const MaterialSymbol('expand_more',
                  size: 20, color: PanergoColors.subtle),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final selected = await showModalBottomSheet<ServiceCategory?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CategorySheet(),
    );
    if (selected != null) onChanged(selected);
  }
}

/// Searchable list of the 18 categories.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet();

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = ServiceCategory.values.where((c) {
      if (_query.isEmpty) return true;
      return _normalize(c.label).contains(_normalize(_query));
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        borderRadius: Radii.brSheet,
      ),
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s12, Space.gutter, 0),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: Space.s16),
            decoration: BoxDecoration(
              color: PanergoColors.disabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TextField(
            autofocus: false,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Rechercher une catégorie',
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
          const SizedBox(height: Space.s12),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Text('Aucune catégorie trouvée',
                        style: context.type.bodySmall
                            .copyWith(color: PanergoColors.faint)),
                  )
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final category = matches[index];
                      final tint = CategoryTints.at(category.tintIndex);
                      return ListTile(
                        leading: MaterialSymbol(category.iconName,
                            size: 22, color: tint.foreground),
                        title: Text(category.label, style: context.type.body),
                        onTap: () => Navigator.of(context).pop(category),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');
}

/// What the three buttons under the composer offer.
enum AssistantAttachment { photo, file, voice }

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.filled = false,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PanergoColors.fill,
          borderRadius: Radii.brTile,
        ),
          child: MaterialSymbol(icon,
              size: 20, color: context.brand.link, filled: filled),
        ),
      ),
    );
  }
}

/// « Rechercher » — outline until there is something to send.
///
/// Outline to filled is a change of *form*, not only of colour (RM-16): the
/// button gains a ground rather than merely a brighter one, which reads at a
/// glance and in sunlight.
///
/// The arrow pops at the moment the button becomes usable. Safe to move: the
/// finger is on the keyboard then, not on the button.
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final ink = enabled ? Colors.white : PanergoColors.disabledLabel;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Rechercher',
      child: GestureDetector(
        // Inert rather than absent when empty: a button that vanishes takes
        // the row's shape with it.
        onTap: enabled ? onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : Motion.fadeUp,
          curve: Curves.easeOut,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: Space.s16),
          decoration: BoxDecoration(
            color: enabled ? brand.fill : Colors.transparent,
            borderRadius: Radii.brTile,
            border: enabled
                ? null
                : Border.all(color: PanergoColors.borderStrong, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rechercher',
                  style: context.type.cardTitleSmall
                      .copyWith(fontSize: 13.5, color: ink)),
              const SizedBox(width: 7),
              _PoppingArrow(enabled: enabled, colour: ink, reduced: reduced),
            ],
          ),
        ),
      ),
    );
  }
}

/// The arrow, which pops once as the button becomes usable.
class _PoppingArrow extends StatelessWidget {
  const _PoppingArrow({
    required this.enabled,
    required this.colour,
    required this.reduced,
  });

  final bool enabled;
  final Color colour;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final arrow = MaterialSymbol('arrow_forward', size: 19, color: colour);

    if (!enabled || reduced) return arrow;

    return TweenAnimationBuilder<double>(
      // Keyed on the state so it plays on the transition, not on every
      // keystroke after it.
      key: const ValueKey('enabled'),
      tween: Tween(begin: 0.85, end: 1),
      duration: Motion.pop,
      curve: Curves.elasticOut,
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: arrow,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label.toUpperCase(), style: context.type.micro),
        if (actionLabel != null && onAction != null)
          InkWell(
            onTap: onAction,
            child: Row(
              children: [
                Text(actionLabel!,
                    style: context.type.meta.copyWith(
                        fontWeight: FontWeight.w700, color: context.brand.link)),
                MaterialSymbol('chevron_right',
                    size: 15, color: context.brand.link),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.onSelected, required this.onSeeAll});

  final ValueChanged<ServiceCategory> onSelected;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final featured = ServiceCategory.values.take(6).toList();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: featured.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: Space.s14),
        itemBuilder: (context, index) {
          if (index == featured.length) {
            return _SeeAllTile(onTap: onSeeAll);
          }
          final category = featured[index];
          return SizedBox(
            width: 74,
            child: InkWell(
              onTap: () => onSelected(category),
              child: Column(
                children: [
                  CategoryTile(category: category),
                  const SizedBox(height: Space.s8),
                  Text(
                    category.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: context.type.metaSmall.copyWith(
                      color: PanergoColors.body,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SeeAllTile extends StatelessWidget {
  const _SeeAllTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PanergoColors.fillWarm,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: PanergoColors.borderDashed,
                  width: 1.5,
                ),
              ),
              child: const MaterialSymbol('apps',
                  size: 28, color: PanergoColors.subtle),
            ),
            const SizedBox(height: Space.s8),
            Text('Voir tout',
                style: context.type.metaSmall
                    .copyWith(color: PanergoColors.body)),
          ],
        ),
      ),
    );
  }
}

/// Says plainly where Panergo actually operates, rather than implying it covers
/// everywhere.
class _CoverageNote extends StatelessWidget {
  const _CoverageNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaterialSymbol('info', size: 16, color: PanergoColors.faint),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Panergo couvre les artisans et réparations à Bonamoussadi, '
            'Makepe et Bonapriso.',
            style: context.type.metaSmall.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}
