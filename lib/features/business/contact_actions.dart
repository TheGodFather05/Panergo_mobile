import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import 'business_providers.dart';

/// Ouvert / Fermé.
///
/// The fact a directory card exists to deliver. Carried by the word first —
/// a dot alone says nothing to someone who cannot tell the two greens apart,
/// and this is the one line that decides whether a person crosses town (RM-16).
class OpenStatePill extends StatelessWidget {
  const OpenStatePill({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: open ? PanergoColors.statusDoneTint : PanergoColors.fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        open ? 'Ouvert' : 'Fermé',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: open ? PanergoColors.statusDoneInk : PanergoColors.muted,
        ),
      ),
    );
  }
}

/// Appeler · WhatsApp — the two ways a Douala business already takes enquiries.
///
/// Only the buttons the listing can actually honour are drawn. A dead "Appeler"
/// on a business with no number is worse than one button: it fails after the
/// tap, when the person has already decided.
class ContactRow extends ConsumerWidget {
  const ContactRow({
    super.key,
    required this.businessId,
    this.compact = false,
  });

  final String businessId;

  /// On a list card, where the row shares space with everything else.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(businessProvider(businessId)).value;
    final phone = detail?.phoneNumber;
    final whatsapp = detail?.whatsappNumber;

    // Nothing to draw yet, or nothing to draw at all. An empty row is better
    // than two buttons that appear and then change their mind.
    if (detail == null || (phone == null && whatsapp == null)) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (phone != null)
          Expanded(
            child: _Action(
              icon: 'call',
              label: 'Appeler',
              primary: true,
              compact: compact,
              onTap: () => _open(Uri.parse('tel:$phone')),
            ),
          ),
        if (phone != null && whatsapp != null) const SizedBox(width: Space.s8),
        if (whatsapp != null)
          Expanded(
            child: _Action(
              icon: 'forum',
              label: 'WhatsApp',
              primary: false,
              compact: compact,
              onTap: () => _open(Uri.parse(
                  'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}')),
            ),
          ),
      ],
    );
  }

  Future<void> _open(Uri uri) async {
    // Silent on failure by design: the alternative is a snackbar explaining
    // that the phone has no dialler, which tells nobody anything they can act
    // on.
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.primary,
    required this.compact,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool primary;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 9 : 12),
        decoration: BoxDecoration(
          color: primary ? brand.soft : PanergoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: primary ? brand.soft : PanergoColors.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol(icon,
                size: compact ? 17 : 19,
                color: primary ? brand.link : PanergoColors.body),
            const SizedBox(width: Space.s6),
            Text(label,
                style: TextStyle(
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.w800,
                    color: primary ? brand.link : PanergoColors.body)),
          ],
        ),
      ),
    );
  }
}
