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
import '../../core/widgets/panergo_button.dart';

/// Publishing into the merged feed.
///
/// Two things can be posted and they are not variants of one form: a neighbour
/// asks a question in words, an artisan shows a finished job in a photograph.
/// The sheet asks which first, rather than presenting one form with a
/// half-relevant half — and only an artisan is offered the photograph, because
/// only a provider account may publish one.
class ComposeSheet extends ConsumerStatefulWidget {
  const ComposeSheet({super.key, required this.canPublishWork});

  /// Whether this account may post a réalisation.
  final bool canPublishWork;

  static Future<bool?> show(BuildContext context, {required bool canPublishWork}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComposeSheet(canPublishWork: canPublishWork),
    );
  }

  @override
  ConsumerState<ComposeSheet> createState() => _ComposeSheetState();
}

enum _Mode { choosing, question, work }

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
        _Mode.work => _photo != null,
        _Mode.choosing => false,
      };

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
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
          Text(isWork ? 'Un travail terminé' : 'Une question à mes voisins',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink)),
        ],
      ),
      const SizedBox(height: Space.s14),
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
        Wrap(
          spacing: Space.s8,
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
                  child: Text(k.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _kind == k
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: _kind == k
                              ? context.brand.link
                              : PanergoColors.muted)),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.s12),
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
      const SizedBox(height: Space.s16),
      PanergoButton(
        label: _busy ? 'Publication…' : 'Publier',
        onPressed: _valid && !_busy ? _publish : null,
      ),
    ];
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
