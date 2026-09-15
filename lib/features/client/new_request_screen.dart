import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'confirmation_screen.dart';
import 'direct_dispatch_screen.dart';

/// Demander — the tender form.
///
/// Two rules from the design shape this screen: the send button is inert and
/// visually muted until a description of at least 10 characters and an urgency
/// are present (RM-07), and picking "Tout de suite" routes to direct dispatch
/// rather than opening a tender (ADR-02).
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({
    super.key,
    this.initialCategory,
    this.fromPost,
  });

  final ServiceCategory? initialCategory;

  /// The réalisation this request was started from, when it was.
  ///
  /// It fills in the trade, seeds the description, and travels with the request
  /// as its photo. The request is otherwise ordinary and still goes out to
  /// tender: a direct quote would give the client one price with nothing to
  /// compare it to, and the product exists to get them three.
  final StreamPost? fromPost;

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  static const _descriptionLimit = 280;
  static const _minDescription = 10;

  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final origin = widget.fromPost;
    if (origin != null) {
      _descriptionController.text =
          'J’ai besoin du même travail que sur la photo de '
          '${origin.authorName.split(' ').first}.';
    }
  }

  late ServiceCategory _category = widget.fromPost?.category ??
      widget.initialCategory ??
      ServiceCategory.plomberie;

  /// Detachable — the origin can be dropped and the request becomes ordinary,
  /// so nobody is trapped in a path they opened out of curiosity.
  late StreamPost? _origin = widget.fromPost;
  Urgency? _urgency;
  BudgetBracket? _budget;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String get _description => _descriptionController.text.trim();

  bool get _valid =>
      _description.length >= _minDescription && _urgency != null;

  Future<void> _submit() async {
    if (!_valid) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final api = ref.read(apiProvider);
    final user = ref.read(currentUserProvider);
    // Onboarding guarantees a real quartier now, so this is unreachable — but it
    // used to fall back to the literal word "Douala", which no provider's
    // quartier ever equals, and routing compares them exactly. Those requests
    // went to nobody behind a success screen. Failing loudly beats that.
    final neighborhood = user?.neighborhood ?? '';
    if (neighborhood.trim().isEmpty) {
      setState(() => _error =
          'Choisissez votre quartier dans votre profil avant d’envoyer une demande.');
      return;
    }

    try {
      if (_urgency == Urgency.now) {
        // Urgent: straight to one provider, with an estimate.
        final match = await api.createDirectRequest(
          category: _category,
          neighborhood: neighborhood,
          description: _description,
          budget: _budget,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => DirectDispatchScreen(match: match),
        ));
      } else {
        final requestId = await api.createRequest(
          category: _category,
          neighborhood: neighborhood,
          description: _description,
          urgency: _urgency!,
          budget: _budget,
          // The photo that convinced them travels with the request, so the
          // artisan who took it knows why they are being called.
          photoUrl: _origin?.photoUrl,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ConfirmationScreen(
            requestId: requestId,
            category: _category,
            neighborhood: neighborhood,
          ),
        ));
      }
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
    final type = context.type;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Nouvelle demande',
                subtitle: _origin == null ? null : 'D’après une réalisation',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.xs, Space.gutter, Space.s22),
                  children: [
                    if (_origin != null) ...[
                      _OriginCard(
                        post: _origin!,
                        onRemove: () => setState(() => _origin = null),
                      ),
                      const SizedBox(height: Space.s18),
                    ],
                    Text('Catégorie', style: type.label),
                    const SizedBox(height: Space.s10),
                    _CategoryChips(
                      selected: _category,
                      onSelected: (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: Space.s22),
                    _RequiredLabel(
                      label: 'Décrivez votre besoin',
                      trailing: Formats.counter(
                          _descriptionController.text.length, _descriptionLimit),
                    ),
                    const SizedBox(height: Space.s10),
                    _DescriptionField(
                      controller: _descriptionController,
                      limit: _descriptionLimit,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Space.s22),
                    _RequiredLabel(label: 'Quand ?'),
                    const SizedBox(height: Space.xs),
                    Text(
                      '« Tout de suite » envoie la demande au prestataire '
                      'disponible le plus proche, sans attendre les offres.',
                      style: type.metaSmall.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: Space.s10),
                    _UrgencyPills(
                      selected: _urgency,
                      onSelected: (value) => setState(() => _urgency = value),
                    ),
                    const SizedBox(height: Space.s22),
                    Text('Votre budget', style: type.label),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Facultatif, mais les offres reçues restent comparables.',
                      style: type.metaSmall.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: Space.s10),
                    _BudgetPills(
                      selected: _budget,
                      onSelected: (value) => setState(
                          () => _budget = _budget == value ? null : value),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.s16),
                      Text(_error!,
                          style: type.bodySmall
                              .copyWith(color: PanergoColors.danger)),
                    ],
                  ],
                ),
              ),
              _StickyFooter(
                valid: _valid,
                busy: _busy,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A field label with the red asterisk that marks it required.
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: context.type.label,
            children: [
              TextSpan(text: '$label '),
              const TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFC2451F)),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(trailing!,
              style: context.type.metaSmall.copyWith(color: PanergoColors.faint)),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final ServiceCategory selected;
  final ValueChanged<ServiceCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ServiceCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: Space.s8),
        itemBuilder: (context, index) {
          final category = ServiceCategory.values[index];
          final isSelected = category == selected;
          final tint = CategoryTints.at(category.tintIndex);

          return InkWell(
            borderRadius: Radii.brChip,
            onTap: () => onSelected(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.s14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? brand.fill : PanergoColors.surface,
                borderRadius: Radii.brChip,
                border: Border.all(
                  color: isSelected ? brand.fill : PanergoColors.borderStrong,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MaterialSymbol(
                    category.iconName,
                    size: 18,
                    color: isSelected ? Colors.white : tint.foreground,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    category.label,
                    style: context.type.labelSmall.copyWith(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : PanergoColors.body,
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

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({
    required this.controller,
    required this.limit,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int limit;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.borderStrong),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: null,
        maxLength: limit,
        minLines: 4,
        style: context.type.bodyLarge
            .copyWith(color: PanergoColors.ink, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          // The design shows its own counter above the field.
          counterText: '',
          hintText: 'Décrivez le problème, le lieu et depuis quand',
          hintStyle: context.type.bodyLarge
              .copyWith(color: PanergoColors.placeholder),
        ),
      ),
    );
  }
}

class _UrgencyPills extends StatelessWidget {
  const _UrgencyPills({required this.selected, required this.onSelected});

  final Urgency? selected;
  final ValueChanged<Urgency> onSelected;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        for (final urgency in Urgency.values)
          _Pill(
            label: urgency.label,
            selected: urgency == selected,
            selectedColor: brand.fill,
            onTap: () => onSelected(urgency),
          ),
      ],
    );
  }
}

class _BudgetPills extends StatelessWidget {
  const _BudgetPills({required this.selected, required this.onSelected});

  final BudgetBracket? selected;
  final ValueChanged<BudgetBracket> onSelected;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        for (final bracket in BudgetBracket.values)
          _Pill(
            label: bracket.label,
            suffix: 'FCFA',
            selected: bracket == selected,
            // Budget is a softer selection than urgency: tinted, not solid.
            selectedColor: brand.soft,
            selectedTextColor: brand.link,
            onTap: () => onSelected(bracket),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    this.suffix,
    this.selectedTextColor = Colors.white,
  });

  final String label;
  final String? suffix;
  final bool selected;
  final Color selectedColor;
  final Color selectedTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: Radii.brChip,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedColor : PanergoColors.surface,
            borderRadius: Radii.brChip,
            border: Border.all(
              color: selected ? brand.fill : PanergoColors.borderInput,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.type.labelSmall.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? selectedTextColor : PanergoColors.body,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: Space.xs),
                Text(suffix!,
                    style: context.type.currency
                        .copyWith(color: PanergoColors.faint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The pinned footer: an inline hint while invalid, then the send button.
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.valid,
    required this.busy,
    required this.onSubmit,
  });

  final bool valid;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s12, Space.gutter, Space.s18),
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        border: Border(top: BorderSide(color: PanergoColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!valid)
            const ValidationHint(
                'Description et délai sont nécessaires pour envoyer.'),
          PanergoButton(
            label: 'Envoyer ma demande',
            icon: 'send',
            enabled: valid,
            loading: busy,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}


/// The réalisation a request was started from.
///
/// Removable: dropping it turns this back into an ordinary request rather than
/// leaving someone stuck in a path they opened out of curiosity.
class _OriginCard extends StatelessWidget {
  const _OriginCard({required this.post, required this.onRemove});

  final StreamPost post;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PanergoColors.surface,
            borderRadius: Radii.brCard,
            border: Border.all(color: PanergoColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: post.photoUrl == null
                    ? const SizedBox(width: 56, height: 56)
                    : Image.network(
                        ApiConfig.absolute(post.photoUrl!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: PanergoColors.skeleton),
                      ),
              ),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'D’après le travail de '
                      '${post.authorName.split(' ').first}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.category?.label ?? ''} · ${post.neighborhood}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: PanergoColors.faint),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: MaterialSymbol('close',
                      size: 19, color: PanergoColors.subtle),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s10),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: PanergoColors.fill,
            borderRadius: Radii.brCard,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MaterialSymbol('group',
                  size: 19, color: PanergoColors.muted),
              const SizedBox(width: Space.s8),
              Expanded(
                child: Text(
                  '${post.authorName.split(' ').first} recevra votre demande '
                  'avec la photo qui vous a décidé. D’autres artisans de votre '
                  'quartier pourront aussi répondre — vous comparerez les prix '
                  'avant de choisir.',
                  style: const TextStyle(
                      fontSize: 12, height: 1.45, color: PanergoColors.body),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
