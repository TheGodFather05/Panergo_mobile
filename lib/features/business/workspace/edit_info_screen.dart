import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/material_symbol.dart';
import '../../../core/widgets/panergo_button.dart';
import '../business_providers.dart';

/// Nom, adresse, services, liens.
///
/// Not the category or the quartier: both decide where the listing is found,
/// and a shop that quietly becomes a pharmacy in another quartier after review
/// defeats the point of reviewing it.
class EditInfoScreen extends ConsumerStatefulWidget {
  const EditInfoScreen({super.key, required this.business});

  final BusinessDetail business;

  @override
  ConsumerState<EditInfoScreen> createState() => _EditInfoScreenState();
}

class _EditInfoScreenState extends ConsumerState<EditInfoScreen> {
  late final _name = TextEditingController(text: widget.business.name);
  late final _address =
      TextEditingController(text: widget.business.addressLine ?? '');
  late final _description =
      TextEditingController(text: widget.business.description ?? '');
  final _service = TextEditingController();

  late List<String> _services = [...widget.business.services];
  late List<BusinessLink> _links = [
    for (final l in widget.business.links) BusinessLink(kind: l.kind, url: l.url)
  ];

  bool _addingLink = false;
  BusinessLinkKind _linkKind = BusinessLinkKind.facebook;
  final _linkUrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    _service.dispose();
    _linkUrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _address.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(apiProvider).updateBusiness(
            widget.business.id,
            name: _name.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            addressLine: _address.text.trim(),
            phoneNumber: widget.business.phoneNumber,
            whatsappNumber: widget.business.whatsappNumber,
            photoUrl: widget.business.photoUrl,
            bannerUrl: widget.business.bannerUrl,
            services: _services,
            links: _links,
          );
      ref.invalidate(myBusinessesProvider);
      ref.invalidate(businessProvider(widget.business.id));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible d’enregistrer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addService() {
    final label = _service.text.trim();
    if (label.isEmpty || _services.contains(label)) return;
    setState(() {
      _services = [..._services, label];
      _service.clear();
    });
  }

  void _addLink() {
    final url = _linkUrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      // One entry per platform: the table enforces it, and replacing rather
      // than appending is what somebody correcting a typo means.
      _links = [
        ..._links.where((l) => l.kind != _linkKind),
        BusinessLink(kind: _linkKind, url: url),
      ];
      _linkUrl.clear();
      _addingLink = false;
    });
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
              title: 'Nom, adresse, liens',
              subtitle: 'Ce qui identifie votre commerce',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.xs, Space.gutter, Space.s22),
                children: [
                  Text('Nom du commerce', style: type.label),
                  const SizedBox(height: Space.s8),
                  _Field(
                      controller: _name,
                      hint: 'Tel qu’il est écrit sur l’enseigne',
                      onChanged: (_) => setState(() {})),
                  const SizedBox(height: Space.s18),

                  Text('Où vous trouver', style: type.label),
                  const SizedBox(height: 3),
                  const Text('Un repère vaut mieux qu’un nom de rue.',
                      style: TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                  const SizedBox(height: Space.s8),
                  _Field(
                      controller: _address,
                      hint: 'En face de la station Tradex',
                      maxLines: 2,
                      onChanged: (_) => setState(() {})),
                  const SizedBox(height: Space.s18),

                  Row(
                    children: [
                      Text('Description', style: type.label),
                      const Text(' · facultatif',
                          style: TextStyle(
                              fontSize: 12, color: PanergoColors.faint)),
                    ],
                  ),
                  const SizedBox(height: Space.s8),
                  _Field(
                      controller: _description,
                      hint: 'Ce que vous vendez, en une phrase',
                      maxLines: 3),
                  const SizedBox(height: Space.s18),

                  Text('Services', style: type.label),
                  const SizedBox(height: Space.s8),
                  _Chips(
                    values: _services,
                    onRemove: (v) =>
                        setState(() => _services = [..._services]..remove(v)),
                  ),
                  const SizedBox(height: Space.s8),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                            controller: _service,
                            hint: 'Vidange, découpe de tôle…',
                            onSubmitted: (_) => _addService()),
                      ),
                      const SizedBox(width: Space.s8),
                      _SmallButton(label: 'Ajouter', onTap: _addService),
                    ],
                  ),
                  const SizedBox(height: Space.s18),

                  Text('Liens', style: type.label),
                  const SizedBox(height: Space.s8),
                  if (_links.isEmpty && !_addingLink)
                    const Padding(
                      padding: EdgeInsets.only(bottom: Space.s10),
                      child: Text(
                        'Aucun lien pour l’instant. Une page Facebook active '
                        'rassure autant qu’une devanture.',
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: PanergoColors.muted),
                      ),
                    ),
                  for (final link in _links)
                    _LinkRow(
                      link: link,
                      onRemove: () =>
                          setState(() => _links = [..._links]..remove(link)),
                    ),
                  if (_addingLink)
                    _LinkForm(
                      kind: _linkKind,
                      controller: _linkUrl,
                      onKind: (k) => setState(() => _linkKind = k),
                      onCancel: () => setState(() => _addingLink = false),
                      onAdd: _addLink,
                    )
                  else
                    _AddLinkButton(
                        onTap: () => setState(() => _addingLink = true)),

                  if (_error != null) ...[
                    const SizedBox(height: Space.s12),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5, color: PanergoColors.danger)),
                  ],

                  const SizedBox(height: Space.s22),
                  if (!_valid)
                    const ValidationHint(
                        'Le nom et l’adresse sont nécessaires.'),
                  PanergoButton(
                    label: _busy ? 'Enregistrement…' : 'Enregistrer',
                    enabled: _valid && !_busy,
                    onPressed: _save,
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

class _Chips extends StatelessWidget {
  const _Chips({required this.values, required this.onRemove});

  final List<String> values;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        for (final value in values)
          Container(
            padding: const EdgeInsets.only(
                left: 12, right: 6, top: 7, bottom: 7),
            decoration: BoxDecoration(
              color: PanergoColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PanergoColors.borderStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: PanergoColors.body)),
                GestureDetector(
                  onTap: () => onRemove(value),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: MaterialSymbol('close',
                        size: 15, color: PanergoColors.subtle),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.onRemove});

  final BusinessLink link;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s8),
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          MaterialSymbol(link.kind.icon, size: 19, color: context.brand.link),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.kind.label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.ink)),
                Text(link.url,
                    style: const TextStyle(
                        fontSize: 11.5, color: PanergoColors.muted),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(left: Space.s8),
              child: MaterialSymbol('close',
                  size: 18, color: PanergoColors.subtle),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkForm extends StatelessWidget {
  const _LinkForm({
    required this.kind,
    required this.controller,
    required this.onKind,
    required this.onCancel,
    required this.onAdd,
  });

  final BusinessLinkKind kind;
  final TextEditingController controller;
  final ValueChanged<BusinessLinkKind> onKind;
  final VoidCallback onCancel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type de lien',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.faint)),
          const SizedBox(height: Space.s8),
          Wrap(
            spacing: Space.s6,
            runSpacing: Space.s6,
            children: [
              for (final k in BusinessLinkKind.values)
                GestureDetector(
                  onTap: () => onKind(k),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: k == kind ? brand.soft : PanergoColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: k == kind
                              ? brand.link
                              : PanergoColors.borderStrong),
                    ),
                    child: Text(k.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: k == kind
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: k == kind
                                ? brand.link
                                : PanergoColors.body)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.s10),
          _Field(controller: controller, hint: kind.placeholder),
          const SizedBox(height: Space.s6),
          const Row(
            children: [
              MaterialSymbol('info', size: 14, color: PanergoColors.faint),
              SizedBox(width: Space.s6),
              Expanded(
                child: Text('Inutile d’écrire « https:// », nous le complétons.',
                    style: TextStyle(
                        fontSize: 11.5, color: PanergoColors.faint)),
              ),
            ],
          ),
          const SizedBox(height: Space.s10),
          Row(
            children: [
              GestureDetector(
                onTap: onCancel,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Text('Annuler',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PanergoColors.muted)),
                ),
              ),
              const Spacer(),
              _SmallButton(label: 'Ajouter ce lien', onTap: onAdd),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddLinkButton extends StatelessWidget {
  const _AddLinkButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.borderDashed),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol('add_link', size: 18, color: context.brand.link),
            const SizedBox(width: Space.s8),
            Text('Ajouter un lien',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.brand.link)),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.brand.fill,
          borderRadius: Radii.brInput,
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

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
        onChanged: onChanged,
        onSubmitted: onSubmitted,
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
