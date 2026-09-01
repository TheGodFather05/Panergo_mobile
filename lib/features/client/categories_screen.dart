import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

/// All 18 trades, searchable, as a three-column grid.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.onSelected});

  final ValueChanged<ServiceCategory> onSelected;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = ServiceCategory.values
        .where((c) =>
            _query.isEmpty || _normalize(c.label).contains(_normalize(_query)))
        .toList();

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Catégories',
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  // Derived from the list, never a literal.
                  '${matches.length} catégories disponibles',
                  style: context.type.meta,
                ),
              ),
              const SizedBox(height: Space.s14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: TextField(
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
              ),
              const SizedBox(height: Space.s16),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Text('Aucune catégorie trouvée',
                            style: context.type.bodySmall
                                .copyWith(color: PanergoColors.faint)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            Space.gutter, 0, Space.gutter, Space.gutter),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: Space.s18,
                          crossAxisSpacing: Space.s12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final category = matches[index];
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSelected(category);
                            },
                            child: Column(
                              children: [
                                CategoryTile(
                                  category: category,
                                  size: 52,
                                  radius: 16,
                                  iconSize: 26,
                                ),
                                const SizedBox(height: Space.s8),
                                Text(
                                  category.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: context.type.metaSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: PanergoColors.body,
                                    height: 1.2,
                                  ),
                                ),
                              ],
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

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');
}
