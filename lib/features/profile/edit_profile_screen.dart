import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../onboarding/place_pickers.dart';
import '../onboarding/quartier_picker_screen.dart';

/// Editing who you are, after signing up.
///
/// The details collected at the welcome screen were only editable by signing up
/// again, which is to say not at all. Same fields, same pickers — the difference
/// is that everything starts filled and nothing is mandatory to leave.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;

  String? _countryCode;
  String? _city;
  String? _cityId;
  String? _quartier;

  File? _newPhoto;
  String? _photoUrl;
  bool _uploading = false;

  bool _dirty = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _countryCode = user?.countryCode;
    _city = user?.city;
    _quartier = user?.neighborhood;
    _photoUrl = user?.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _valid => _nameController.text.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Mes informations',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.s8, Space.gutter, Space.s20),
                  children: [
                    _PhotoHeader(
                      photo: _newPhoto,
                      photoUrl: _photoUrl,
                      initials: user?.initials ?? '?',
                      uploading: _uploading,
                      onTap: _pickPhoto,
                    ),
                    const SizedBox(height: Space.s26),
                    const _Label('Votre nom'),
                    const SizedBox(height: Space.s8),
                    _TextField(
                      controller: _nameController,
                      hint: 'Comment vous appelle-t-on ?',
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                    const SizedBox(height: Space.s20),
                    const _Label('Votre pays'),
                    const SizedBox(height: Space.s8),
                    _Row(
                      icon: 'public',
                      value: _countryName(user),
                      onTap: _pickCountry,
                    ),
                    const SizedBox(height: Space.s20),
                    const _Label('Votre ville'),
                    const SizedBox(height: Space.s8),
                    _Row(icon: 'location_city', value: _city, onTap: _pickCity),
                    const SizedBox(height: Space.s20),
                    const _Label('Votre quartier'),
                    const SizedBox(height: Space.s8),
                    _Row(
                      icon: 'location_on',
                      value: _quartier,
                      onTap: _pickQuartier,
                    ),
                    const SizedBox(height: Space.s20),
                    // Not editable, and worth saying why rather than showing a
                    // field that refuses to change.
                    const _Label('Votre numéro'),
                    const SizedBox(height: Space.s8),
                    _ReadOnlyRow(
                      icon: 'phone',
                      value: user?.phoneNumber ?? '',
                      note: 'Votre numéro identifie votre compte.',
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
              if (_dirty)
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.s12, Space.gutter, Space.s18),
                  decoration: const BoxDecoration(
                    color: PanergoColors.page,
                    border:
                        Border(top: BorderSide(color: PanergoColors.border)),
                  ),
                  child: Column(
                    children: [
                      if (!_valid)
                        const ValidationHint('Votre nom est nécessaire.'),
                      PanergoButton(
                        label: 'Enregistrer',
                        enabled: _valid,
                        loading: _busy || _uploading,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _countryName(AppUser? user) =>
      _countryCode == null ? null : (_countryCode == 'CM' ? 'Cameroun' : _countryCode);

  Future<void> _pickCountry() async {
    final picked = await PlacePickers.country(context, selected: _countryCode);
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.code != _countryCode) {
        // Everything below narrows from this, so a change clears it rather than
        // leaving a town that is no longer in the chosen country.
        _city = null;
        _cityId = null;
        _quartier = null;
      }
      _countryCode = picked.code;
      _dirty = true;
    });
  }

  Future<void> _pickCity() async {
    if (_countryCode == null) return;
    final picked = await PlacePickers.city(context,
        countryCode: _countryCode!, selected: _city);
    if (picked == null || !mounted) return;
    setState(() {
      _city = picked.name;
      _cityId = picked.id;
      _quartier = null;
      _dirty = true;
    });
  }

  Future<void> _pickQuartier() async {
    final picked = await QuartierPickerScreen.show(context,
        selected: _quartier, cityId: _cityId);
    if (picked == null || !mounted) return;
    setState(() {
      _quartier = picked.name;
      _city = picked.city;
      _cityId = picked.cityId;
      _dirty = true;
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1440, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _newPhoto = File(picked.path);
      _uploading = true;
      _dirty = true;
    });
    try {
      final url = await ref.read(apiProvider).uploadImage(File(picked.path));
      if (mounted) setState(() => _photoUrl = url);
    } catch (_) {
      if (mounted) {
        setState(() {
          _newPhoto = null;
          _error = 'L’envoi de la photo a échoué.';
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            countryCode: _countryCode,
            city: _city,
            neighborhood: _quartier,
            photoUrl: _photoUrl,
          );
      if (mounted) Navigator.of(context).pop();
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
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.photo,
    required this.photoUrl,
    required this.initials,
    required this.uploading,
    required this.onTap,
  });

  final File? photo;
  final String? photoUrl;
  final String initials;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Center(
      child: GestureDetector(
        onTap: uploading ? null : onTap,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: PanergoColors.fillAlt,
                    shape: BoxShape.circle,
                    image: photo != null
                        ? DecorationImage(
                            image: FileImage(photo!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: uploading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : photo == null
                          ? Center(
                              child: Text(initials,
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: PanergoColors.body)),
                            )
                          : null,
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: brand.fill,
                    shape: BoxShape.circle,
                    border: Border.all(color: PanergoColors.page, width: 2),
                  ),
                  child: const Center(
                    child: MaterialSymbol('photo_camera',
                        size: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s8),
            Text('Changer la photo',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: brand.link)),
          ],
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
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PanergoColors.ink));
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
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
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 15, color: PanergoColors.placeholder),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.value, required this.onTap});

  final String icon;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = value != null && value!.isNotEmpty;

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
            MaterialSymbol(icon,
                size: 19,
                color: chosen ? context.brand.link : PanergoColors.subtle),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(
                chosen ? value! : 'Non renseigné',
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

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.icon,
    required this.value,
    required this.note,
  });

  final String icon;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: PanergoColors.fill,
            borderRadius: Radii.brInput,
            border: Border.all(color: PanergoColors.border),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s14, vertical: Space.s14),
          child: Row(
            children: [
              MaterialSymbol(icon, size: 19, color: PanergoColors.subtle),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PanergoColors.muted)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s6),
        Text(note,
            style: const TextStyle(fontSize: 12, color: PanergoColors.faint)),
      ],
    );
  }
}