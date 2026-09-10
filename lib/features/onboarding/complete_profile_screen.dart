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
import 'place_pickers.dart';
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
  Country? _country;
  City? _city;
  Quartier? _quartier;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameController.text.trim().length >= 2 &&
      _country != null &&
      _city != null &&
      _quartier != null;

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).completeProfile(
            name: _nameController.text.trim(),
            countryCode: _country!.code,
            city: _city!.name,
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
                      const _RequiredLabel('Votre pays'),
                      const SizedBox(height: Space.s8),
                      _PlaceField(
                        icon: 'public',
                        value: _country?.name,
                        placeholder: 'Choisir votre pays',
                        onTap: _pickCountry,
                      ),
                      const SizedBox(height: Space.s20),
                      const _RequiredLabel('Votre ville'),
                      const SizedBox(height: Space.s8),
                      _PlaceField(
                        icon: 'location_city',
                        value: _city?.name,
                        placeholder: _country == null
                            ? 'Choisissez d’abord un pays'
                            : 'Choisir votre ville',
                        enabled: _country != null,
                        onTap: _pickCity,
                      ),
                      const SizedBox(height: Space.s20),
                      const _RequiredLabel('Votre quartier'),
                      const SizedBox(height: Space.s8),
                      _PlaceField(
                        icon: 'location_on',
                        value: _quartier?.name,
                        placeholder: _city == null
                            ? 'Choisissez d’abord une ville'
                            : 'Choisir votre quartier',
                        enabled: _city != null,
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
                            'Votre nom et votre localisation sont nécessaires pour continuer.'),
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

  Future<void> _pickCountry() async {
    final picked = await PlacePickers.country(context, selected: _country?.code);
    if (picked == null || !mounted) return;
    setState(() {
      _country = picked;
      // Everything below narrows from this, so a change clears them rather
      // than leaving a town that is no longer in the chosen country.
      if (picked.code != _country?.code) {
        _city = null;
        _quartier = null;
      }
    });
  }

  Future<void> _pickCity() async {
    if (_country == null) return;
    final picked = await PlacePickers.city(context,
        countryCode: _country!.code, selected: _city?.name);
    if (picked == null || !mounted) return;
    setState(() {
      _city = picked;
      _quartier = null;
    });
  }

  Future<void> _pickQuartier() async {
    if (_city == null) return;
    final picked = await QuartierPickerScreen.show(context,
        selected: _quartier?.name, cityId: _city!.id);
    if (picked != null && mounted) setState(() => _quartier = picked);
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


class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.enabled = true,
  });

  final String icon;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  /// False while an earlier step is unanswered — the row says why rather than
  /// opening a list that could only be empty.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final chosen = value != null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
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
              MaterialSymbol(icon,
                  size: 19,
                  color: chosen ? context.brand.link : PanergoColors.subtle),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Text(
                  chosen ? value! : placeholder,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: chosen ? FontWeight.w700 : FontWeight.w400,
                    color: chosen
                        ? PanergoColors.ink
                        : PanergoColors.placeholder,
                  ),
                ),
              ),
              const MaterialSymbol('chevron_right',
                  size: 20, color: PanergoColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}
