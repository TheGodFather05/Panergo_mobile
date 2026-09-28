import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/app_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../../core/widgets/photo_source_sheet.dart';
import '../client/categories_screen.dart';
import 'place_pickers.dart';

enum _Step { metier, quartier, presentation, recap }

/// Creating a provider profile.
///
/// Four steps rather than one screen, because métier and quartier decide which
/// requests this person will ever see and neither can be changed afterwards
/// without a developer — there is no admin, no support queue, nobody to email.
/// The last step is a read-only review, and it is the only safety net the flow
/// has.
///
/// Nobody is signed out at the end and nobody waits for approval: they finish
/// and can receive work.
class BecomeProviderScreen extends ConsumerStatefulWidget {
  const BecomeProviderScreen({super.key});

  @override
  ConsumerState<BecomeProviderScreen> createState() =>
      _BecomeProviderScreenState();
}

class _BecomeProviderScreenState extends ConsumerState<BecomeProviderScreen> {
  _Step _step = _Step.metier;

  ServiceCategory? _category;
  Quartier? _quartier;
  final _bioController = TextEditingController();
  File? _photo;
  String? _photoUrl;
  bool _uploading = false;
  bool _photoFailed = false;

  /// How much of the photo has gone out, 0–1. Real progress from Dio rather
  /// than an animation: the design puts a percentage next to « vous pouvez
  /// continuer sans attendre », and a made-up number next to that sentence
  /// would be the one part of it that was a lie.
  double _photoProgress = 0;

  bool _busy = false;
  String? _error;

  /// Resolved lazily — the quartier list narrows to the town on their account.
  String? _cityId;

  static const _bioLimit = 300;

  @override
  void initState() {
    super.initState();
    // Work is most often where you live, so start there — and say it can differ.
    final home = ref.read(currentUserProvider)?.neighborhood;
    if (home != null && home.trim().isNotEmpty) {
      final city = ref.read(currentUserProvider)?.city ?? 'Douala';
      _quartier = Quartier(name: home, city: city, cityId: '');
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  bool get _stepValid => switch (_step) {
        _Step.metier => _category != null,
        _Step.quartier => _quartier != null,
        _Step.presentation => true,
        _Step.recap => true,
      };

  String? get _hint => switch (_step) {
        _Step.metier when _category == null => 'Choisissez votre métier pour continuer.',
        _Step.quartier when _quartier == null =>
          'Choisissez le quartier où vous travaillez.',
        _ => null,
      };

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
                title: 'Devenir prestataire',
                onBack: _back,
              ),
              _StepDots(current: _step.index),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.s14, Space.gutter, Space.s20),
                  children: [
                    switch (_step) {
                      _Step.metier => _MetierStep(
                          category: _category,
                          onPick: _pickCategory,
                        ),
                      _Step.quartier => _QuartierStep(
                          quartier: _quartier,
                          onPick: _pickQuartier,
                        ),
                      _Step.presentation => _PresentationStep(
                          controller: _bioController,
                          limit: _bioLimit,
                          photo: _photo,
                          uploading: _uploading,
                          progress: _photoProgress,
                          failed: _photoFailed,
                          onChanged: (_) => setState(() {}),
                          onPickPhoto: _pickPhoto,
                          onRetryPhoto: _uploadPhoto,
                          onRemovePhoto: () => setState(() {
                            _photo = null;
                            _photoUrl = null;
                            _photoFailed = false;
                          }),
                        ),
                      _Step.recap => _RecapStep(
                          category: _category!,
                          quartier: _quartier!,
                          bio: _bioController.text.trim(),
                          photo: _photo,
                          onEdit: (step) => setState(() => _step = step),
                        ),
                    },
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
                    Space.gutter, Space.s12, Space.gutter, Space.s18),
                decoration: const BoxDecoration(
                  color: PanergoColors.page,
                  border: Border(top: BorderSide(color: PanergoColors.border)),
                ),
                child: Column(
                  children: [
                    if (_hint != null) ValidationHint(_hint!),
                    PanergoButton(
                      label: _step == _Step.recap
                          ? 'Commencer à travailler'
                          : 'Continuer',
                      enabled: _stepValid,
                      loading: _busy || _uploading,
                      onPressed: _step == _Step.recap ? _submit : _next,
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

  void _next() {
    if (!_stepValid) return;
    setState(() => _step = _Step.values[_step.index + 1]);
  }

  void _back() {
    if (_step == _Step.metier) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step = _Step.values[_step.index - 1]);
  }

  Future<void> _pickCategory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoriesScreen(
          onSelected: (c) => setState(() => _category = c),
        ),
      ),
    );
  }

  Future<void> _pickQuartier() async {
    // Scoped to the town on their account: an artisan works where they are.
    final picked = await PlacePickers.quartier(context,
        cityId: _cityId, selected: _quartier?.name);
    if (picked != null && mounted) setState(() => _quartier = picked);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    // Compressed on the way out: an untouched phone photo is a forty-second
    // upload on a Douala connection, against an 8 MB ceiling at the other end.
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1440, imageQuality: 85);
    if (picked == null) return;

    setState(() => _photo = File(picked.path));
    await _uploadPhoto();
  }

  /// Sends whatever [_photo] holds.
  ///
  /// Separate from picking so a failed upload can be retried with the file
  /// already chosen. Re-picking was the only way out before, which on a slow
  /// connection meant opening the camera again to replace a photo that was
  /// never the problem.
  Future<void> _uploadPhoto() async {
    final file = _photo;
    if (file == null) return;

    setState(() {
      _uploading = true;
      _photoFailed = false;
      _photoProgress = 0;
    });

    try {
      final url = await ref.read(apiProvider).uploadImage(
            file,
            onProgress: (f) {
              if (mounted) setState(() => _photoProgress = f);
            },
          );
      if (mounted) setState(() => _photoUrl = url);
    } catch (_) {
      // Never blocks the wizard — the photo is optional and initials cover it.
      if (mounted) setState(() => _photoFailed = true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).becomeProvider(
            category: _category!,
            neighborhood: _quartier!.name,
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            photoUrl: _photoUrl,
          );
      await ref.read(activeModeProvider.notifier).set(AppMode.provider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de créer votre profil pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          for (var i = 0; i < _Step.values.length; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                    right: i == _Step.values.length - 1 ? 0 : 5),
                decoration: BoxDecoration(
                  color: i <= current ? brand.fill : PanergoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetierStep extends StatelessWidget {
  const _MetierStep({required this.category, required this.onPick});

  final ServiceCategory? category;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Quel est votre métier ?',
      // The design leads with the limit rather than burying it: somebody who
      // does two trades needs to know now, not after choosing.
      subtitle: 'Un seul métier pour l’instant. Il décide des demandes que '
          'vous recevrez.',
      child: _PickerRow(
        icon: category?.iconName ?? 'handyman',
        label: category?.label ?? 'Choisir votre métier',
        chosen: category != null,
        onTap: onPick,
      ),
    );
  }
}

class _QuartierStep extends StatelessWidget {
  const _QuartierStep({required this.quartier, required this.onPick});

  final Quartier? quartier;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Où travaillez-vous ?',
      // Says what it costs, and that it will not fix itself. The design's
      // wording is a warning rather than a description, because this is the
      // field people get wrong and then wonder why the inbox is empty.
      subtitle: 'Vous ne verrez que les demandes de ce quartier. Ce choix ne '
          'se modifie pas seul ensuite — vérifiez-le avant de terminer.',
      child: _PickerRow(
        icon: 'location_on',
        label: quartier?.name ?? 'Choisir le quartier',
        chosen: quartier != null,
        onTap: onPick,
      ),
    );
  }
}

class _PresentationStep extends StatelessWidget {
  const _PresentationStep({
    required this.controller,
    required this.limit,
    required this.photo,
    required this.uploading,
    required this.progress,
    required this.failed,
    required this.onChanged,
    required this.onPickPhoto,
    required this.onRetryPhoto,
    required this.onRemovePhoto,
  });

  final TextEditingController controller;
  final int limit;
  final File? photo;
  final bool uploading;
  final double progress;
  final bool failed;
  final ValueChanged<String> onChanged;
  final ValueChanged<ImageSource> onPickPhoto;

  /// Sends the already-chosen file again, after a failure.
  final VoidCallback onRetryPhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Présentez-vous en quelques mots',
      subtitle:
          'Les clients choisissent souvent la personne dont ils ont lu le message. '
          'Tout est facultatif ici.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoRow(
            photo: photo,
            uploading: uploading,
            progress: progress,
            failed: failed,
            onPick: () => _choosePhotoSource(context),
            onRetry: onRetryPhoto,
            onRemove: onRemovePhoto,
          ),
          const SizedBox(height: Space.s20),
          Row(
            children: [
              const Text('Votre message',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: PanergoColors.ink)),
              const Spacer(),
              Text('${controller.text.length} / $limit',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.faint)),
            ],
          ),
          const SizedBox(height: Space.s8),
          Container(
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
              maxLength: limit,
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: PanergoColors.ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText:
                    'Plombier depuis 12 ans à Akwa. Fuites, chauffe-eau, '
                    'installations…',
                hintStyle:
                    TextStyle(fontSize: 14, color: PanergoColors.placeholder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _choosePhotoSource(BuildContext context) async {
    // The shared sheet, so the compose flow and this one stay in step.
    final source = await PhotoSourceSheet.show(context);
    if (source != null) onPickPhoto(source);
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photo,
    required this.uploading,
    required this.progress,
    required this.failed,
    required this.onPick,
    required this.onRetry,
    required this.onRemove,
  });

  final File? photo;
  final bool uploading;
  final double progress;
  final bool failed;
  final VoidCallback onPick;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: uploading ? null : onPick,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: PanergoColors.fill,
              borderRadius: Radii.brCard,
              border: Border.all(color: PanergoColors.borderDashed),
              image: photo == null
                  ? null
                  : DecorationImage(
                      image: FileImage(photo!), fit: BoxFit.cover),
            ),
            child: uploading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      // Determinate, from the same fraction the percentage
                      // reads. An indeterminate spinner beside « 62 % » would
                      // have the two halves of one state disagreeing.
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress > 0 ? progress : null),
                    ),
                  )
                : photo == null
                    ? const Center(
                        child: MaterialSymbol('add_a_photo',
                            size: 22, color: PanergoColors.subtle),
                      )
                    : null,
          ),
        ),
        const SizedBox(width: Space.s14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uploading
                    ? 'Envoi en cours…'
                    : failed
                        ? 'L’envoi a échoué'
                        : photo == null
                            ? 'Votre photo (facultatif)'
                            : 'Votre photo',
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: PanergoColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                failed
                    ? 'Connexion trop lente. Rien n’est perdu.'
                    : uploading
                        ? '${(progress * 100).round()} % · vous pouvez '
                            'continuer sans attendre'
                        : photo == null
                            // Says what happens without one, rather than what a
                            // photo would do. Somebody hesitating here is
                            // deciding whether skipping costs them anything.
                            ? 'Sans photo, vos initiales s’affichent sur vos '
                                'offres. Rien ne vous bloque.'
                            : 'Les clients la voient sur chacune de vos offres.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: failed
                        ? PanergoColors.danger
                        : PanergoColors.muted),
              ),
              // Two ways out of a failure, as the design draws it. Retry sends
              // the file already chosen; « continuer sans photo » is the same
              // act as removing it, named for what it means here — the wizard
              // was never blocked, and somebody staring at an error should be
              // told that rather than left to work it out.
              if (photo != null && !uploading)
                Row(
                  children: [
                    if (failed)
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 32),
                            alignment: Alignment.centerLeft),
                        child: Text('Réessayer',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: context.brand.link)),
                      ),
                    if (failed) const SizedBox(width: Space.s14),
                    TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 32),
                          alignment: Alignment.centerLeft),
                      child: Text(failed ? 'Continuer sans photo' : 'Retirer',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: PanergoColors.subtle)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The last look before committing.
///
/// Métier and quartier decide which requests this person will ever see, and
/// neither can be changed afterwards without a developer. Every row here jumps
/// back to the step that set it.
class _RecapStep extends StatelessWidget {
  const _RecapStep({
    required this.category,
    required this.quartier,
    required this.bio,
    required this.photo,
    required this.onEdit,
  });

  final ServiceCategory category;
  final Quartier quartier;
  final String bio;
  final File? photo;
  final ValueChanged<_Step> onEdit;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Tout est correct ?',
      // The design's version names the affordance: the rows below are tappable
      // and nothing says so otherwise, so the instruction is the only thing
      // that makes the correction discoverable.
      subtitle: 'Le métier et le quartier décident des demandes que vous '
          'recevrez. Touchez une ligne pour la corriger.',
      child: Column(
        children: [
          _RecapRow(
            icon: category.iconName,
            label: 'Métier',
            value: category.label,
            onTap: () => onEdit(_Step.metier),
          ),
          _RecapRow(
            icon: 'location_on',
            label: 'Quartier',
            value: quartier.name,
            onTap: () => onEdit(_Step.quartier),
          ),
          _RecapRow(
            icon: 'chat',
            label: 'Présentation',
            value: bio.isEmpty ? 'Aucune' : bio,
            onTap: () => onEdit(_Step.presentation),
          ),
          _RecapRow(
            icon: 'photo_camera',
            label: 'Photo',
            value: photo == null ? 'Aucune' : 'Ajoutée',
            onTap: () => onEdit(_Step.presentation),
          ),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MaterialSymbol(icon, size: 19, color: context.brand.link),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: PanergoColors.subtle)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: PanergoColors.ink)),
                ],
              ),
            ),
            const MaterialSymbol('edit', size: 17, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: context.type.h2.copyWith(color: PanergoColors.ink)),
        const SizedBox(height: Space.s6),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 13.5, height: 1.5, color: PanergoColors.muted)),
        const SizedBox(height: Space.s20),
        child,
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s16),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(
              color: chosen ? brand.fill : PanergoColors.border,
              width: chosen ? 1.5 : 1),
        ),
        child: Row(
          children: [
            MaterialSymbol(icon,
                size: 22, color: chosen ? brand.link : PanergoColors.subtle),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: chosen ? FontWeight.w800 : FontWeight.w400,
                    color: chosen
                        ? PanergoColors.ink
                        : PanergoColors.placeholder,
                  )),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}