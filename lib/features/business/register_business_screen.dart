import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'business_providers.dart';

/// Inscrire mon commerce.
///
/// The wait is stated before the form rather than after the submit. A listing
/// that goes quiet for two days having promised nothing reads as a system that
/// lost it.
class RegisterBusinessScreen extends ConsumerStatefulWidget {
  const RegisterBusinessScreen({super.key});

  @override
  ConsumerState<RegisterBusinessScreen> createState() =>
      _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState
    extends ConsumerState<RegisterBusinessScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();

  String? _categoryCode;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _categoryCode != null &&
      _phone.text.trim().isNotEmpty;

  /// Says which thing is still missing, rather than that something is.
  String get _hint {
    if (_name.text.trim().isEmpty) return 'Donnez le nom du commerce.';
    if (_categoryCode == null) return 'Choisissez une catégorie.';
    return 'Donnez un numéro pour qu’on puisse vous joindre.';
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      await ref.read(apiProvider).registerBusiness(
            name: _name.text.trim(),
            categoryCode: _categoryCode!,
            neighborhood: user?.neighborhood ?? '',
            addressLine:
                _address.text.trim().isEmpty ? null : _address.text.trim(),
            phoneNumber: _phone.text.trim(),
          );
      ref.invalidate(myBusinessesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'L’inscription n’est pas partie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final categories =
        ref.watch(businessCategoriesProvider).value ?? const <BusinessCategory>[];

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Inscrire mon commerce',
              subtitle: 'Gratuit · vérifié avant publication',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.xs, Space.gutter, Space.s22),
                children: [
                  const _WaitNotice(),
                  const SizedBox(height: Space.s18),

                  _RequiredLabel('Nom du commerce', type: type),
                  const SizedBox(height: Space.s8),
                  _Field(
                    controller: _name,
                    hint: 'Tel qu’il est écrit sur l’enseigne',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Space.s18),

                  _RequiredLabel('Catégorie', type: type),
                  const SizedBox(height: Space.s8),
                  _Categories(
                    categories: categories,
                    selected: _categoryCode,
                    onPick: (code) => setState(() => _categoryCode = code),
                  ),
                  const SizedBox(height: Space.s18),

                  _RequiredLabel('Téléphone', type: type),
                  const SizedBox(height: Space.s8),
                  _Field(
                    controller: _phone,
                    hint: '+237 6 XX XX XX XX',
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Space.s18),

                  Text('Où vous trouver', style: type.label),
                  const SizedBox(height: 3),
                  const Text(
                    'Décrivez le lieu comme vous l’indiqueriez à quelqu’un : un '
                    'repère vaut mieux qu’un nom de rue.',
                    style: TextStyle(
                        fontSize: 12, height: 1.45, color: PanergoColors.muted),
                  ),
                  const SizedBox(height: Space.s8),
                  _Field(
                    controller: _address,
                    hint: 'En face de la station Tradex, carrefour Bonamoussadi',
                    maxLines: 3,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: Space.s12),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5, color: PanergoColors.danger)),
                  ],

                  const SizedBox(height: Space.s22),
                  if (!_valid) ValidationHint(_hint),
                  PanergoButton(
                    label: _busy ? 'Envoi…' : 'Envoyer pour vérification',
                    enabled: _valid && !_busy,
                    onPressed: _submit,
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

/// What happens next, said before the form rather than after it.
class _WaitNotice extends StatelessWidget {
  const _WaitNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.warningBg,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('schedule',
              size: 19, color: PanergoColors.warningIcon),
          const SizedBox(width: Space.s10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Votre fiche n’apparaît pas tout de suite',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.warningInk)),
                SizedBox(height: 3),
                Text(
                  'Nous vérifions que le commerce existe et se trouve bien à '
                  'l’adresse indiquée. Comptez deux jours ouvrés. Vous pourrez '
                  'préparer votre catalogue en attendant.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: PanergoColors.warningInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({
    required this.categories,
    required this.selected,
    required this.onPick,
  });

  final List<BusinessCategory> categories;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        for (final category in categories)
          GestureDetector(
            onTap: () => onPick(category.code),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected == category.code
                    ? brand.soft
                    : PanergoColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: selected == category.code
                        ? brand.link
                        : PanergoColors.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MaterialSymbol(category.iconName,
                      size: 17,
                      color: selected == category.code
                          ? brand.link
                          : PanergoColors.subtle),
                  const SizedBox(width: Space.s6),
                  Text(category.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selected == category.code
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected == category.code
                              ? brand.link
                              : PanergoColors.body)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text, {required this.type});

  final String text;
  final PanergoTypography type;

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(
      style: type.label,
      children: [
        TextSpan(text: text),
        TextSpan(text: ' *', style: TextStyle(color: context.brand.fill)),
      ],
    ));
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brInput,
        border: Border.all(color: PanergoColors.borderInput),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: Space.s14, vertical: Space.s12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
            fontSize: 14.5, height: 1.4, color: PanergoColors.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(
              fontSize: 14.5, color: PanergoColors.placeholder),
        ),
      ),
    );
  }
}
