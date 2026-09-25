import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/material_symbol.dart';
import '../../../core/widgets/panergo_button.dart';
import '../share_sheet.dart';

/// Adding or changing one line of the price list.
class EditProductScreen extends ConsumerStatefulWidget {
  const EditProductScreen({super.key, required this.business, this.product});

  final BusinessDetail business;

  /// Null when adding.
  final BusinessProduct? product;

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price =
      TextEditingController(text: widget.product?.price?.toString() ?? '');
  late final _unit = TextEditingController(text: widget.product?.unit ?? '');
  late final _description =
      TextEditingController(text: widget.product?.description ?? '');

  late bool _available = widget.product?.available ?? true;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.product == null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _unit.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(apiProvider).saveProduct(
            widget.business.id,
            productId: widget.product?.id,
            name: _name.text.trim(),
            description:
                _description.text.trim().isEmpty ? null : _description.text.trim(),
            // Empty means « prix sur demande », which is a real answer rather
            // than a missing one — so it is sent as null, not skipped.
            price: _price.text.trim().isEmpty
                ? null
                : int.tryParse(_price.text.trim()),
            unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
            available: _available,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible d’enregistrer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Retirer cet article ?',
      body: 'Il disparaîtra de votre catalogue. Pour le cacher sans le perdre, '
          'marquez-le épuisé.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(apiProvider)
          .deleteProduct(widget.business.id, widget.product!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de retirer l’article.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: _isNew ? 'Nouvel article' : 'Modifier',
              onBack: () => Navigator.of(context).pop(),
              // Only for an article that exists: there is nothing to link to
              // until it has been saved and has a slug of its own.
              trailing: _isNew
                  ? null
                  : GestureDetector(
                      onTap: () => ShareSheet.show(
                        context,
                        business: widget.business,
                        origin: ShareScope.product,
                        product: widget.product,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PanergoColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: PanergoColors.border),
                        ),
                        child: Center(
                          child: MaterialSymbol('share',
                              size: 19, color: context.brand.link),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.xs, Space.gutter, Space.s22),
                children: [
                  Text('Nom', style: type.label),
                  const SizedBox(height: Space.s8),
                  _Field(controller: _name, hint: 'Sac de ciment 50 kg',
                      onChanged: (_) => setState(() {})),
                  const SizedBox(height: Space.s18),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prix (FCFA)', style: type.label),
                            const SizedBox(height: Space.s8),
                            _Field(
                              controller: _price,
                              hint: 'Laisser vide',
                              keyboardType: TextInputType.number,
                              formatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unité', style: type.label),
                            const SizedBox(height: Space.s8),
                            _Field(controller: _unit, hint: 'le sac'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s6),
                  const Text(
                    'Sans prix, l’article s’affiche « Prix sur demande ».',
                    style: TextStyle(fontSize: 11.5, color: PanergoColors.faint),
                  ),
                  const SizedBox(height: Space.s18),

                  Text('Description', style: type.label),
                  const SizedBox(height: Space.s8),
                  _Field(
                      controller: _description,
                      hint: 'Facultatif',
                      maxLines: 3),
                  const SizedBox(height: Space.s18),

                  _AvailableRow(
                    available: _available,
                    onChanged: (v) => setState(() => _available = v),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: Space.s12),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5, color: PanergoColors.danger)),
                  ],

                  const SizedBox(height: Space.s22),
                  PanergoButton(
                    label: _busy ? 'Enregistrement…' : 'Enregistrer',
                    enabled: _valid && !_busy,
                    onPressed: _save,
                  ),

                  if (!_isNew) ...[
                    const SizedBox(height: Space.s12),
                    TextButton(
                      onPressed: _busy ? null : _delete,
                      child: const Text('Retirer du catalogue',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: PanergoColors.danger)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Épuisé hides a line without losing it.
class _AvailableRow extends StatelessWidget {
  const _AvailableRow({required this.available, required this.onChanged});

  final bool available;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!available),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(available ? 'En stock' : 'Épuisé',
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: PanergoColors.ink)),
                  Text(
                    available
                        ? 'Les clients voient cet article'
                        : 'Caché des clients, gardé dans votre catalogue',
                    style: const TextStyle(
                        fontSize: 12, color: PanergoColors.muted),
                  ),
                ],
              ),
            ),
            Switch(
              value: available,
              onChanged: onChanged,
              activeTrackColor: context.brand.fill,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.formatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
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
        inputFormatters: formatters,
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
