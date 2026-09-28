import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'material_symbol.dart';

/// Picks one of the 18 trades.
///
/// Extracted from the home screen, where it was private and had already been
/// copied into the assistant. A third caller — the « + » of Mes demandes —
/// made one shared copy cheaper than a third divergence.
abstract final class TradePicker {
  static Future<ServiceCategory?> show(BuildContext context) {
    return showModalBottomSheet<ServiceCategory>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CategorySheet(),
    );
  }
}

/// Searchable list of the 18 categories.
class CategorySheet extends StatefulWidget {
  const CategorySheet({super.key});

  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
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
