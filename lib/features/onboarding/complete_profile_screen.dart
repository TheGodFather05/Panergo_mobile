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
                      const _BrandMark(),
                      const SizedBox(height: Space.s22),
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
                      // One question, three narrowing answers — not three
                      // unrelated fields.
                      const _RequiredLabel('Où vivez-vous ?'),
                      const SizedBox(height: Space.s10),
                      _PlaceField(
                        icon: 'public',
                        caption: 'Pays',
                        value: _country?.name,
                        placeholder: 'Choisir',
                        onTap: _pickCountry,
                      ),
                      const SizedBox(height: 9),
                      _PlaceField(
                        icon: 'location_city',
                        caption: 'Ville',
                        value: _city?.name,
                        placeholder: 'Choisir',
                        onTap: _pickCity,
                      ),
                      const SizedBox(height: 9),
                      _PlaceField(
                        icon: 'location_on',
                        caption: 'Quartier',
                        value: _quartier?.name,
                        placeholder: 'Choisir',
                        onTap: _pickQuartier,
                      ),
                      const SizedBox(height: Space.s12),
                      const _Explainer(),
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
    // Reaching for a later step takes you through the one before it, rather
    // than ignoring the tap. A row that does nothing is a dead end.
    if (_country == null) {
      await _pickCountry();
      if (_country == null || !mounted) return;
    }
    final picked = await PlacePickers.city(context,
        countryCode: _country!.code, selected: _city?.name);
    if (picked == null || !mounted) return;
    setState(() {
      _city = picked;
      _quartier = null;
    });
  }

  Future<void> _pickQuartier() async {
    if (_city == null) {
      await _pickCity();
      if (_city == null || !mounted) return;
    }
    final picked = await PlacePickers.quartier(context,
        cityId: _city!.id, selected: _quartier?.name);
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
          hintText: 'Comme vos voisins vous appellent',
          hintStyle: TextStyle(fontSize: 15, color: PanergoColors.placeholder),
        ),
      ),
    );
  }
}

/// The 52 px mark the design opens on.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: context.brand.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('P',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

/// What the quartier is for, and what changing the steps above will do.
///
/// Worth saying out loud: the reset is real behaviour, and finding out about it
/// by watching two fields empty themselves is a poor way to learn.
class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaterialSymbol('info', size: 16, color: PanergoColors.faint),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'Le quartier décide à qui vos demandes sont envoyées. Changer de '
            'pays ou de ville le remet à zéro.',
            style: TextStyle(
                fontSize: 11.5, height: 1.45, color: PanergoColors.subtle),
          ),
        ),
      ],
    );
  }
}

/// One step of the location cascade.
///
/// Always tappable, even before the step above it is answered — the tap walks
/// you through the missing one rather than being swallowed. A row that ignores
/// you teaches nothing.
class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.icon,
    required this.caption,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String icon;

  /// Sits inside the row at a fixed width so the three values line up.
  final String caption;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = value != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: chosen ? PanergoColors.borderStrong : PanergoColors.borderInput),
        ),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            MaterialSymbol(icon, size: 21, color: context.brand.fill),
            const SizedBox(width: 11),
            SizedBox(
              width: 64,
              child: Text(caption,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.subtle)),
            ),
            Expanded(
              child: Text(
                chosen ? value! : placeholder,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                  color: chosen
                      ? PanergoColors.ink
                      : PanergoColors.placeholder,
                ),
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.disabled),
          ],
        ),
      ),
    );
  }
}
