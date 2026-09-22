import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/material_symbol.dart';
import '../../../core/widgets/panergo_button.dart';
import '../business_providers.dart';

/// Photo et bannière.
///
/// Both optional, and the screen says so at the top: a listing works without
/// either, and a shopkeeper who has no logo should not feel stopped here.
class EditMediaScreen extends ConsumerStatefulWidget {
  const EditMediaScreen({super.key, required this.business});

  final BusinessDetail business;

  @override
  ConsumerState<EditMediaScreen> createState() => _EditMediaScreenState();
}

class _EditMediaScreenState extends ConsumerState<EditMediaScreen> {
  late String? _photoUrl = widget.business.photoUrl;
  late String? _bannerUrl = widget.business.bannerUrl;

  bool _busy = false;
  String? _error;

  Future<void> _pick({required bool banner}) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ref.read(apiProvider).uploadImage(File(picked.path));
      setState(() {
        if (banner) {
          _bannerUrl = url;
        } else {
          _photoUrl = url;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'L’image n’est pas partie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(apiProvider).updateBusiness(
            widget.business.id,
            name: widget.business.name,
            description: widget.business.description,
            addressLine: widget.business.addressLine,
            phoneNumber: widget.business.phoneNumber,
            whatsappNumber: widget.business.whatsappNumber,
            photoUrl: _photoUrl,
            bannerUrl: _bannerUrl,
            services: widget.business.services,
            links: widget.business.links,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Photo et bannière',
              subtitle: 'Facultatif · votre fiche vit sans',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s22),
                children: [
                  const _SectionLabel('Aperçu de votre fiche'),
                  _Preview(
                    business: widget.business,
                    photoUrl: _photoUrl,
                    bannerUrl: _bannerUrl,
                  ),
                  const SizedBox(height: Space.s20),

                  const _SectionLabel('Photo de profil'),
                  _Slot(
                    url: _photoUrl,
                    icon: 'add_a_photo',
                    addLabel: 'Ajouter une photo',
                    addDetail: 'Votre enseigne, votre logo, ou vous',
                    addedLabel: 'Photo ajoutée',
                    addedDetail: 'Visible dans l’annuaire et sur vos articles',
                    onPick: () => _pick(banner: false),
                    onRemove: () => setState(() => _photoUrl = null),
                  ),
                  const SizedBox(height: Space.s8),
                  const _Note(
                    'Sans photo, vos initiales s’affichent sur la teinte de '
                    'votre catégorie. Rien ne vous bloque.',
                  ),
                  const SizedBox(height: Space.s20),

                  const _SectionLabel('Bannière'),
                  _Slot(
                    url: _bannerUrl,
                    icon: 'panorama',
                    addLabel: 'Ajouter une bannière',
                    addDetail: 'Une photo large de votre devanture',
                    addedLabel: 'Bannière ajoutée',
                    addedDetail: 'En tête de votre fiche',
                    onPick: () => _pick(banner: true),
                    onRemove: () => setState(() => _bannerUrl = null),
                  ),
                  const SizedBox(height: Space.s8),
                  const _Note(
                    'Une photo de la devanture aide quelqu’un qui est déjà '
                    'passé devant à reconnaître l’endroit.',
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
                    enabled: !_busy,
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

/// What the listing will look like — the reason to bother at all.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.business,
    required this.photoUrl,
    required this.bannerUrl,
  });

  final BusinessDetail business;
  final String? photoUrl;
  final String? bannerUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bannerUrl != null)
            Image.network(ApiConfig.absolute(bannerUrl!),
                height: 96, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(height: 96, color: PanergoColors.fill))
          else
            Container(
              height: 96,
              color: PanergoColors.fill,
              alignment: Alignment.center,
              child: const Text('Sans bannière',
                  style: TextStyle(
                      fontSize: 12, color: PanergoColors.subtle)),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.s12),
            child: Row(
              children: [
                InitialsAvatar(
                    name: business.name,
                    photoUrl: photoUrl,
                    size: 44,
                    radius: 13),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(business.name,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: PanergoColors.ink)),
                      Text(
                          '${business.categoryLabel} · '
                          '${business.neighborhood}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PanergoColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.url,
    required this.icon,
    required this.addLabel,
    required this.addDetail,
    required this.addedLabel,
    required this.addedDetail,
    required this.onPick,
    required this.onRemove,
  });

  final String? url;
  final String icon;
  final String addLabel;
  final String addDetail;
  final String addedLabel;
  final String addedDetail;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final has = url != null;

    return GestureDetector(
      onTap: has ? null : onPick,
      child: Container(
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(
              color: has ? PanergoColors.border : PanergoColors.borderDashed),
        ),
        child: Row(
          children: [
            if (has)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(ApiConfig.absolute(url!),
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 44, height: 44, color: PanergoColors.fill)),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PanergoColors.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: MaterialSymbol(icon,
                      size: 20, color: context.brand.link),
                ),
              ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(has ? addedLabel : addLabel,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  Text(has ? addedDetail : addDetail,
                      style: const TextStyle(
                          fontSize: 11.5, color: PanergoColors.muted)),
                ],
              ),
            ),
            if (has)
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
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaterialSymbol('info', size: 15, color: PanergoColors.faint),
        const SizedBox(width: Space.s6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.45, color: PanergoColors.faint)),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: PanergoColors.faint)),
    );
  }
}
