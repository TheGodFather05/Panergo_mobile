import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';

/// Making a group.
///
/// A sheet rather than a screen: it asks for a name and one choice, and pushing
/// a page for that would put the list you were reading off the stack.
///
/// The one real decision is *scope* — a quartier group or a city-wide one — and
/// it is drawn as two options rather than a quartier picker, because those are
/// the only two shapes a group here actually takes and a free-text place would
/// file the room where nobody finds it.
class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  static Future<GroupSummary?> show(BuildContext context) {
    return showModalBottomSheet<GroupSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateGroupSheet(),
    );
  }

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  /// True for « mon quartier », false for « toute la ville ».
  bool _local = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  Future<void> _create() async {
    if (!_valid || _saving) return;
    final mine = ref.read(currentUserProvider)?.neighborhood;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final group = await ref.read(apiProvider).createGroup(
            name: _name.text.trim(),
            description: _description.text.trim(),
            // Null is "the whole city", which is a real answer rather than a
            // missing one — a trade group pinned to one quartier is a lie
            // about who it is for.
            neighborhood: _local ? mine : null,
            iconName: _local ? 'groups' : 'handyman',
          );
      if (mounted) Navigator.of(context).pop(group);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Le groupe n’a pas pu être créé.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(currentUserProvider)?.neighborhood;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PanergoColors.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s12, Space.gutter, Space.gutter),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PanergoColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Space.s16),
              const Text('Créer un groupe',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink)),
              const SizedBox(height: Space.s6),
              const Text(
                'Vous en serez le créateur : c’est vous qui accepterez les '
                'demandes pour y entrer.',
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: PanergoColors.body),
              ),
              const SizedBox(height: Space.s18),

              const _Label('NOM DU GROUPE'),
              _Field(
                controller: _name,
                hint: 'Ex. : Quartier Bonamoussadi',
                maxLength: 80,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.s14),

              const _Label('DE QUOI S’AGIT-IL ? (FACULTATIF)'),
              _Field(
                controller: _description,
                hint: 'Entraide entre voisins, bons plans, alertes…',
                maxLength: 500,
                lines: 2,
              ),
              const SizedBox(height: Space.s18),

              const _Label('QUI EST-CE POUR ?'),
              _Choice(
                icon: 'home_work',
                title: mine == null || mine.isEmpty
                    ? 'Mon quartier'
                    : 'Mon quartier · $mine',
                body: 'Les voisins le verront en premier dans la liste.',
                selected: _local,
                // Nothing to file it under without a quartier on the account.
                enabled: mine != null && mine.isNotEmpty,
                onTap: () => setState(() => _local = true),
              ),
              const SizedBox(height: Space.s8),
              _Choice(
                icon: 'public',
                title: 'Toute la ville',
                body: 'Pour un métier ou un sujet qui dépasse un quartier.',
                selected: !_local,
                enabled: true,
                onTap: () => setState(() => _local = false),
              ),

              if (_error != null) ...[
                const SizedBox(height: Space.s12),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 12.5, color: PanergoColors.danger)),
              ],

              const SizedBox(height: Space.s18),
              GestureDetector(
                // Disabled until the name is there (RM-07), and the disabled
                // look says so rather than failing on tap.
                onTap: _valid && !_saving ? _create : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _valid
                        ? context.brand.fill
                        : PanergoColors.disabledButton,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Créer le groupe',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _valid
                                    ? Colors.white
                                    : PanergoColors.disabledLabel)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s8, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: PanergoColors.faint)),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.lines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int lines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brInput,
        border: Border.all(color: PanergoColors.borderInput),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLength: maxLength,
        minLines: lines,
        maxLines: lines,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
            fontSize: 14.5, height: 1.4, color: PanergoColors.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(
              fontSize: 14, color: PanergoColors.placeholder),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String body;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final on = selected && enabled;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(Space.s14),
          decoration: BoxDecoration(
            color: on ? brand.soft : PanergoColors.surface,
            borderRadius: Radii.brCard,
            border: Border.all(
                color: on ? brand.fill : PanergoColors.border,
                width: on ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MaterialSymbol(icon,
                  size: 20,
                  color: on ? brand.link : PanergoColors.subtle),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: on ? brand.link : PanergoColors.ink)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: PanergoColors.muted)),
                  ],
                ),
              ),
              // A check as well as the tint, so the choice is not carried by
              // colour alone (RM-16).
              if (on)
                MaterialSymbol('check_circle',
                    size: 20, color: brand.link, filled: true),
            ],
          ),
        ),
      ),
    );
  }
}
