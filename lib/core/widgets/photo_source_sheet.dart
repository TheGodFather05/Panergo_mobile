import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'panergo_button.dart';

/// Where a photo comes from.
///
/// « Appareil photo ou galerie » — the camera leads, because most photos in this
/// product are of work just finished or an article on a shelf, and both are taken
/// on the spot rather than found in a library.
///
/// Extracted from the provider onboarding screen, which was the only place that
/// offered the choice: the compose sheet went straight to the gallery, so an
/// artisan photographing a finished job had to leave the app, take the picture,
/// come back and find it.
abstract final class PhotoSourceSheet {
  static Future<ImageSource?> show(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x6B18110A),
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brSheet,
        ),
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s20, Space.gutter, Space.s26),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PanergoButton(
                label: 'Prendre une photo',
                icon: 'photo_camera',
                onPressed: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: Space.s8),
              PanergoOutlinedButton(
                label: 'Choisir dans la galerie',
                icon: 'photo_library',
                onPressed: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
