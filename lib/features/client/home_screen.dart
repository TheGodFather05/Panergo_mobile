import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ServiceCategory? _assistantCategory;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final firstName = (user?.name ?? '').split(' ').first;
    final quartier =
        (user?.neighborhood.isNotEmpty ?? false) ? user!.neighborhood : 'Douala';

    return FadeUp(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s6, Space.gutter, Space.s26),
        children: [
          _TopRow(quartier: quartier, name: user?.name ?? ''),
          const SizedBox(height: Space.s22),
          _Headline(firstName: firstName),
          const SizedBox(height: Space.s18),
          _AssistantCard(
            category: _assistantCategory,
            onCategoryChanged: (value) =>
                setState(() => _assistantCategory = value),
            onSearch: _openAssistant,
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
  void _openAssistant() {
    Navigator.of(context).push(
      AssistantScreen.route(initialCategory: _assistantCategory),
    );
  }

  void _openRequestFor(ServiceCategory? category) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewRequestScreen(initialCategory: category),
    ));
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.quartier, required this.name});

  final String quartier;
  final String name;

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
        InitialsAvatar(name: name, size: 40, radius: null),
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
class _AssistantCard extends StatelessWidget {
  const _AssistantCard({
    required this.category,
    required this.onCategoryChanged,
    required this.onSearch,
  });

  final ServiceCategory? category;
  final ValueChanged<ServiceCategory?> onCategoryChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;

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
          GestureDetector(
            onTap: onSearch,
            child: Text(
              category == null
                  ? 'Décrivez votre besoin…'
                  : 'Votre besoin en ${category!.label.toLowerCase()}…',
              style: type.bodyLarge.copyWith(
                fontSize: 16,
                color: PanergoColors.placeholder,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: Space.s14),
          _CategoryPicker(value: category, onChanged: onCategoryChanged),
          const SizedBox(height: Space.s14),
          const Divider(height: 1, color: PanergoColors.fillAlt),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              _ToolButton(icon: 'photo_camera', semanticLabel: 'Ajouter une photo'),
              const SizedBox(width: Space.s8),
              _ToolButton(icon: 'attach_file', semanticLabel: 'Joindre un fichier'),
              const SizedBox(width: Space.s8),
              // The mic is the accessibility keystone — kept prominent.
              _ToolButton(
                icon: 'mic',
                semanticLabel: 'Décrire vocalement',
                filled: true,
              ),
              const Spacer(),
              _SearchButton(onPressed: onSearch),
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.semanticLabel,
    this.filled = false,
  });

  final String icon;
  final String semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
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
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Material(
      color: brand.fill,
      borderRadius: Radii.brTile,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Radii.brTile,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: Space.s16),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rechercher',
                  style: context.type.cardTitleSmall
                      .copyWith(fontSize: 13.5, color: Colors.white)),
              const SizedBox(width: 7),
              const MaterialSymbol('arrow_forward',
                  size: 19, color: Colors.white),
            ],
          ),
        ),
      ),
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
