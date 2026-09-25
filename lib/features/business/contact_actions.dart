import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../messages/chat_screen.dart';
import '../messages/messages_screen.dart';
import 'business_providers.dart';

/// Ouvert / Fermé.
///
/// The fact a directory card exists to deliver. Carried by the word first —
/// a dot alone says nothing to someone who cannot tell the two greens apart,
/// and this is the one line that decides whether a person crosses town (RM-16).
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

    // Two actions, never three. The design gives the shop page a pair of
    // full-width buttons, and a third squeezes all of them below the width a
    // label needs. WhatsApp is therefore the *fallback* for « Écrire » rather
    // than a button of its own: a business with nobody watching the in-app
    // inbox is better reached on the number they already read.
    final canWrite = detail.canMessage || whatsapp != null;

    return Row(
      children: [
        if (canWrite)
          Expanded(
            child: _Action(
              icon: 'forum',
              // Named for where it lands, so nobody taps expecting WhatsApp
              // and finds a Panergo thread, or the reverse.
              label: detail.canMessage ? 'Écrire' : 'WhatsApp',
              primary: true,
              compact: compact,
              onTap: detail.canMessage
                  ? () => _write(context, ref, businessId)
                  : () => _open(Uri.parse(
                      'https://wa.me/${whatsapp!.replaceAll(RegExp(r'[^0-9]'), '')}')),
            ),
          ),
        if (canWrite && phone != null) SizedBox(width: compact ? Space.s8 : 10),
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
      ],
    );
  }

  /// Opens the thread, or the one already open, and goes to it.
  Future<void> _write(BuildContext context, WidgetRef ref, String id) async {
    try {
      final conversation =
          await ref.read(apiProvider).openBusinessConversation(id);

      // The inbox is now a thread out of date. Invalidated the moment the
      // thread exists rather than on the way back, so it is already there if
      // the reader switches tabs instead of using the back arrow.
      ref.invalidate(conversationsProvider);

      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversationId: conversation.conversationId,
          peerName: conversation.peerName,
          peerPhotoUrl: conversation.peerPhotoUrl,
        ),
      ));

      // And again on the way out: a message sent in there moves the thread to
      // the top, which the list cannot know by itself.
      ref.invalidate(conversationsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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

    // On the shop page these are the page's main act, so they are solid brand
    // with white on them. On a list card the same pair must not outshout the
    // name of the business, so they take the soft tint instead.
    final solid = !compact;
    final ink = solid ? Colors.white : brand.link;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
        decoration: BoxDecoration(
          color: solid ? brand.fill : brand.soft,
          borderRadius: BorderRadius.circular(compact ? 11 : 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol(icon, size: compact ? 18 : 20, color: ink),
            SizedBox(width: compact ? Space.s6 : Space.s8),
            Text(label,
                style: TextStyle(
                    fontSize: compact ? 12.5 : 14,
                    fontWeight: FontWeight.w800,
                    color: ink)),
          ],
        ),
      ),
    );
  }
}
