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
import 'quartier_picker_screen.dart';

/// The rest of signing up.
///
/// An account exists from the first OTP, but it arrives claiming to be called
/// "+237…" and living nowhere — so the app greets people by their phone number
/// and the assistant, which searches by their quartier, has nothing to search.
/// This screen is where that gets fixed, and it blocks, because there is nothing
/// useful behind it.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  // Deliberately not seeded with anything. Showing the phone number here invites
  // people to accept it, which is exactly how every account ended up named after
  // its own number.
  final _nameController = TextEditingController();
  Quartier? _quartier;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameController.text.trim().length >= 2 && _quartier != null;

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).completeProfile(
            name: _nameController.text.trim(),
            neighborhood: _quartier!.name,
          );
      // No navigation: routing is a function of the auth state, and the state
      // just changed.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible d’enregistrer pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    // Nothing behind this screen is usable, so the back gesture must not reach
    // it. "Se déconnecter" below is the deliberate way out for someone who typed
    // the wrong number.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PanergoColors.page,
        body: SafeArea(
          child: FadeUp(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutter, Space.s30, Space.gutter, Space.s20),
                    children: [
                      Text('Bienvenue sur Panergo',
                          style: type.h1.copyWith(color: PanergoColors.ink)),
                      const SizedBox(height: Space.s8),
                      Text(
                        'Dites-nous qui vous êtes pour commencer.',
                        style: type.body.copyWith(
                            color: PanergoColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: Space.s30),
                      const _RequiredLabel('Votre nom'),
                      const SizedBox(height: Space.s8),
                      _NameField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: Space.s20),
                      const _RequiredLabel('Votre quartier'),
                      const SizedBox(height: Space.s8),
                      _QuartierField(
                        quartier: _quartier,
                        onTap: _pickQuartier,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Space.gutterTight),
                        Text(_error!,
                            style: type.bodySmall
                                .copyWith(color: PanergoColors.danger)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.s12, Space.gutter, Space.s12),
                  decoration: const BoxDecoration(
                    color: PanergoColors.page,
                    border:
                        Border(top: BorderSide(color: PanergoColors.border)),
                  ),
                  child: Column(
                    children: [
                      if (!_valid)
                        const ValidationHint(
                            'Votre nom et votre quartier sont nécessaires pour continuer.'),
                      PanergoButton(
                        label: 'Continuer',
                        enabled: _valid,
                        loading: _busy,
                        onPressed: _submit,
                      ),
                      TextButton(
                        onPressed: _busy ? null : _signOut,
                        child: Text('Se déconnecter',
                            style: type.bodySmall
                                .copyWith(color: PanergoColors.faint)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickQuartier() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuartierPickerScreen(
          selected: _quartier?.name,
          onSelected: (q) => setState(() => _quartier = q),
        ),
      ),
    );
  }

  Future<void> _signOut() => ref.read(authProvider.notifier).signOut();
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PanergoColors.ink),
        children: const [
          TextSpan(text: ' *', style: TextStyle(color: PanergoColors.danger)),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brInput,
        border: Border.all(color: PanergoColors.borderInput),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 15, color: PanergoColors.ink),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: 'Comment vous appelle-t-on ?',
          hintStyle: TextStyle(fontSize: 15, color: PanergoColors.placeholder),
        ),
      ),
    );
  }
}

class _QuartierField extends StatelessWidget {
  const _QuartierField({required this.quartier, required this.onTap});

  final Quartier? quartier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = quartier != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brInput,
          border: Border.all(color: PanergoColors.borderInput),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s14, vertical: Space.s14),
        child: Row(
          children: [
            MaterialSymbol('location_on',
                size: 19,
                color: chosen ? context.brand.link : PanergoColors.subtle),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(
                chosen ? quartier!.name : 'Choisir votre quartier',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: chosen ? FontWeight.w700 : FontWeight.w400,
                  color:
                      chosen ? PanergoColors.ink : PanergoColors.placeholder,
                ),
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}