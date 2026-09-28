import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/enums.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/photo_source_sheet.dart';
import '../../core/widgets/panergo_button.dart';

/// Publishing into the merged feed.
///
/// Two things can be posted and they are not variants of one form: a neighbour
/// asks a question in words, an artisan shows a finished job in a photograph.
/// The sheet asks which first, rather than presenting one form with a
/// half-relevant half — and only an artisan is offered the photograph, because
/// only a provider account may publish one.
class ComposeSheet extends ConsumerStatefulWidget {
  const ComposeSheet({
    super.key,
    required this.canPublishWork,
    this.onAskForWork,
  });

  /// Whether this account may post a réalisation.
  final bool canPublishWork;

  /// Opens the tender form instead, for somebody who came here to ask
  /// neighbours about a job they actually want done. Null where the caller has
  /// no route to that form, and then the suggestion is shown without a link.
  final VoidCallback? onAskForWork;

  static Future<bool?> show(
    BuildContext context, {
    required bool canPublishWork,
    VoidCallback? onAskForWork,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComposeSheet(
        canPublishWork: canPublishWork,
        onAskForWork: onAskForWork,
      ),
    );
  }

  @override
  ConsumerState<ComposeSheet> createState() => _ComposeSheetState();
}

/// What is being written.
///
/// [work] and [advice] are the design's « Réalisation » and « Conseil », and the
/// photo is what separates them: a réalisation with a photo reaches the public
/// feed, a conseil without one stays on the artisan's own profile. The rule is
/// stated on the screen rather than left to be discovered.
enum _Mode { choosing, question, work, advice }

class _ComposeSheetState extends ConsumerState<ComposeSheet> {
  late _Mode _mode =
      widget.canPublishWork ? _Mode.choosing : _Mode.question;

  final _body = TextEditingController();
  QuartierPostKind _kind = QuartierPostKind.question;
  File? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _valid => switch (_mode) {
        _Mode.question => _body.text.trim().isNotEmpty,
        // A réalisation must show the work: a claim to have finished something
        // with nothing to show is the one post this product refuses.
        _Mode.work => _photo != null,
        // A conseil is words. The photo is optional and changes where it lands.
        _Mode.advice => _body.text.trim().isNotEmpty,
        _Mode.choosing => false,
      };

  Future<void> _pickPhoto() async {
    // The camera first. A réalisation is usually photographed on the spot, and
    // going straight to the gallery meant leaving the app to take the picture.
    final source = await PhotoSourceSheet.show(context);
    if (source == null || !mounted) return;

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _publish() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      if (_mode == _Mode.question) {
        await api.createQuartierPost(kind: _kind, body: _body.text.trim());
      } else if (_mode == _Mode.advice) {
        // The photo is optional here, and its absence is the point: without one
        // this stays on the profile rather than reaching the public feed.
        final url = _photo == null ? null : await api.uploadImage(_photo!);
        await api.createFeedPost(
          postType: PostType.conseil,
          photoUrl: url,
          caption: _body.text.trim(),
        );
      } else {
        // The photo has to exist on the server before the post can name it.
        final url = await api.uploadImage(_photo!);
        await api.createFeedPost(
          photoUrl: url,
          postType: PostType.realisation,
          caption: _body.text.trim().isEmpty ? null : _body.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'La publication n’est pas partie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PanergoColors.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(
            Space.gutterTight, Space.s12, Space.gutterTight, Space.s20),
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
            if (_mode == _Mode.choosing) ..._chooser() else ..._form(),
            if (_error != null) ...[
              const SizedBox(height: Space.s10),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12.5, color: PanergoColors.danger)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _chooser() => [
        const Text('Publier',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
        const SizedBox(height: Space.s14),
        _Choice(
          icon: 'forum',
          title: 'Une question à mes voisins',
          detail: 'Un conseil, une recommandation, un besoin',
          onTap: () => setState(() => _mode = _Mode.question),
        ),
        const SizedBox(height: Space.s8),
        _Choice(
          icon: 'photo_camera',
          title: 'Un travail terminé',
          detail: 'Une photo de votre réalisation',
          onTap: () => setState(() => _mode = _Mode.work),
        ),
        const SizedBox(height: Space.s8),
        _Choice(
          icon: 'lightbulb',
          title: 'Un conseil',
          detail: 'Ce que vous savez et que les clients ignorent',
          onTap: () => setState(() => _mode = _Mode.advice),
        ),
      ];

  List<Widget> _form() {
    final isWork = _mode == _Mode.work;

    return [
      Row(
        children: [
          if (widget.canPublishWork)
            GestureDetector(
              onTap: () => setState(() => _mode = _Mode.choosing),
              child: const Padding(
                padding: EdgeInsets.only(right: Space.s8),
                child: MaterialSymbol('arrow_back',
                    size: 20, color: PanergoColors.subtle),
              ),
            ),
          Text(
              switch (_mode) {
                _Mode.work => 'Un travail terminé',
                _Mode.advice => 'Un conseil',
                _ => 'Une question à mes voisins',
              },
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink)),
        ],
      ),
      const SizedBox(height: Space.s14),
      // The rule, on the screen where it applies. Somebody choosing between the
      // two needs to know what each one does before they write, not after.
      if (_mode == _Mode.work || _mode == _Mode.advice) ...[
        Container(
          padding: const EdgeInsets.all(Space.s12),
          decoration: BoxDecoration(
            color: PanergoColors.fill,
            borderRadius: Radii.brCard,
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MaterialSymbol('info', size: 15, color: PanergoColors.subtle),
              SizedBox(width: Space.s8),
              Expanded(
                child: Text(
                  'Une réalisation avec photo apparaît dans le Feed public. '
                  'Un conseil sans photo reste sur votre profil.',
                  style: TextStyle(
                      fontSize: 12, height: 1.45, color: PanergoColors.subtle),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s12),
      ],
      if (_mode == _Mode.advice) ...[
        // Optional here, so it reads as an addition rather than a blocker.
        _OptionalPhoto(photo: _photo, onPick: _pickPhoto),
        const SizedBox(height: Space.s12),
      ],
      if (isWork) ...[
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            height: 168,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: PanergoColors.fill,
              borderRadius: Radii.brCard,
              border: Border.all(color: PanergoColors.borderInput),
            ),
            child: _photo == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MaterialSymbol('add_a_photo',
                          size: 26, color: PanergoColors.subtle),
                      SizedBox(height: Space.s6),
                      Text('Choisir une photo',
                          style: TextStyle(
                              fontSize: 13, color: PanergoColors.muted)),
                    ],
                  )
                : Image.file(_photo!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: Space.s12),
      ] else ...[
        // The picker was three unlabelled pills. Named now, as the design does,
        // and each carries its glyph — three words alone do not say what
        // « Prestataire » posts.
        Text('De quoi s’agit-il ?', style: context.type.label),
        const SizedBox(height: Space.s8),
        Wrap(
          spacing: Space.s8,
          runSpacing: Space.s8,
          children: [
            for (final k in QuartierPostKind.values)
              GestureDetector(
                onTap: () => setState(() => _kind = k),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _kind == k
                        ? context.brand.soft
                        : PanergoColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: _kind == k
                            ? context.brand.link
                            : PanergoColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MaterialSymbol(k.iconName,
                          size: 15,
                          color: _kind == k
                              ? context.brand.link
                              : PanergoColors.muted),
                      const SizedBox(width: Space.s6),
                      Text(k.label,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _kind == k
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _kind == k
                                  ? context.brand.link
                                  : PanergoColors.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.s8),
        // What the chosen kind means, so the three are distinguishable before
        // anything is typed.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MaterialSymbol('info', size: 14, color: PanergoColors.faint),
            const SizedBox(width: Space.s6),
            Expanded(
              child: Text(_kind.hint,
                  style: context.type.metaSmall.copyWith(height: 1.4)),
            ),
          ],
        ),
        const SizedBox(height: Space.s14),
        Text('Votre message', style: context.type.label),
        const SizedBox(height: Space.s8),
      ],
      Container(
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brInput,
          border: Border.all(color: PanergoColors.borderInput),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s14, vertical: Space.s12),
        child: TextField(
          controller: _body,
          onChanged: (_) => setState(() {}),
          maxLines: 5,
          minLines: isWork ? 2 : 4,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
              fontSize: 14.5, height: 1.45, color: PanergoColors.ink),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: isWork
                ? 'Décrivez le travail (facultatif)'
                : 'Que voulez-vous demander à votre quartier ?',
            hintStyle: const TextStyle(
                fontSize: 14.5, color: PanergoColors.placeholder),
          ),
        ),
      ),
      // A question to the quartier is not the same tool as a tender, and
      // somebody who needs a plumber today should not be waiting on neighbours
      // to answer. Offered here rather than guessed at: the design puts the
      // alternative where the wrong choice is being made.
      if (_mode == _Mode.question) ...[
        const SizedBox(height: Space.s14),
        _NeedWorkInstead(onTap: _busy ? null : widget.onAskForWork),
      ],
      const SizedBox(height: Space.s16),
      // RM-07: inert, and saying why. A greyed button with no reason reads as
      // broken rather than as waiting for something.
      if (!_valid)
        ValidationHint(_mode == _Mode.question
            ? 'Écrivez au moins une phrase pour publier.'
            : 'Une photo et une description sont nécessaires.'),
      PanergoButton(
        // « dans le fil » for a question: it says where it lands, on the one
        // kind that goes to the neighbours rather than onto a profile.
        label: _busy
            ? 'Publication…'
            : _mode == _Mode.question
                ? 'Publier dans le fil'
                : 'Publier',
        icon: 'send',
        enabled: _valid,
        loading: _busy,
        onPressed: _publish,
      ),
    ];
  }
}

/// « Besoin d'une intervention plutôt que d'un avis ? »
///
/// Null [onTap] leaves it as plain text rather than a dead control: whoever
/// opened this sheet may have no route to the request form from here.
class _NeedWorkInstead extends StatelessWidget {
  const _NeedWorkInstead({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return Container(
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.fillWarm,
        borderRadius: Radii.brTile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Besoin d’une intervention plutôt que d’un avis ?',
              style: type.labelSmall),
          const SizedBox(height: Space.xs),
          Text(
            'Une demande vous apporte des prix à comparer au lieu de réponses '
            'à attendre.',
            style: type.metaSmall.copyWith(height: 1.4),
          ),
          if (onTap != null) ...[
            const SizedBox(height: Space.s6),
            InkWell(
              onTap: onTap,
              child: Text('Faites une demande',
                  style: type.labelSmall.copyWith(color: context.brand.link)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            MaterialSymbol(icon, size: 22, color: context.brand.link),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: PanergoColors.ink)),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
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

/// A photo slot that is plainly optional.
///
/// Deliberately smaller and quieter than the réalisation's full-width well: on a
/// conseil the photo changes the destination rather than being the content, and
/// a 168-high empty box would read as something still to do.
class _OptionalPhoto extends StatelessWidget {
  const _OptionalPhoto({required this.photo, required this.onPick});

  final File? photo;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: Radii.brCard,
      child: Container(
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.borderInput),
        ),
        child: Row(
          children: [
            if (photo == null)
              const MaterialSymbol('add_a_photo',
                  size: 20, color: PanergoColors.subtle)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.badge),
                child: Image.file(photo!,
                    width: 38, height: 38, fit: BoxFit.cover),
              ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(
                photo == null
                    ? 'Photos (facultatif)'
                    : 'Photo jointe · ce conseil ira aussi dans le Feed',
                style: context.type.metaSmall.copyWith(height: 1.4),
              ),
            ),
            if (photo == null)
              Text('Ajouter',
                  style: context.type.labelSmall
                      .copyWith(color: context.brand.link)),
          ],
        ),
      ),
    );
  }
}
