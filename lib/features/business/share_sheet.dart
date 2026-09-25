import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';

/// What a shopkeeper is sharing.
enum ShareScope { product, catalogue, shop }

/// « Partager » — one sheet that knows where it was opened from.
///
/// The scope is preselected and can only be *widened*: from an article to the
/// catalogue to the whole shop. Narrowing would mean picking an article at
/// random from a sheet, which is not a choice anybody makes here.
///
/// The preview occupies the middle, because the WhatsApp card is what actually
/// gets sent — everyone in the conversation sees it, and only some tap through.
/// A shopkeeper who cannot see it before sending sends blind once and does not
/// come back.
class ShareSheet extends StatefulWidget {
  const ShareSheet({
    super.key,
    required this.business,
    required this.origin,
    this.product,
  });

  final BusinessDetail business;

  /// Where the sheet was opened from — the widest thing it cannot narrow past.
  final ShareScope origin;

  /// Present when opened from an article.
  final BusinessProduct? product;

  static Future<void> show(
    BuildContext context, {
    required BusinessDetail business,
    required ShareScope origin,
    BusinessProduct? product,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(
        business: business,
        origin: origin,
        product: product,
      ),
    );
  }

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  late ShareScope _scope = widget.origin;

  bool get _publishable => widget.business.status == BusinessStatus.published;

  /// The scopes offered, from the origin outwards.
  List<ShareScope> get _scopes => switch (widget.origin) {
        ShareScope.product => ShareScope.values,
        ShareScope.catalogue => const [ShareScope.catalogue, ShareScope.shop],
        ShareScope.shop => const [ShareScope.shop],
      };

  String get _url {
    final slug = widget.business.slug ?? '';
    final base = '${ApiConfig.shareBaseUrl}/b/$slug';
    return switch (_scope) {
      ShareScope.shop => base,
      ShareScope.catalogue => '$base/catalogue',
      ShareScope.product => '$base/${widget.product?.slug ?? ''}',
    };
  }

  /// The message the shopkeeper sends — in their voice, never Panergo's.
  String get _message => switch (_scope) {
        ShareScope.shop => '${widget.business.name} — $_url',
        ShareScope.catalogue =>
          'Le catalogue de ${widget.business.name} — $_url',
        ShareScope.product =>
          '${widget.product?.name ?? ''} — $_url',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s12, Space.gutter, Space.gutter),
      child: SingleChildScrollView(
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
            const Text('Partager',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s14),

            if (!_publishable)
              const _NotPublished()
            else ...[
              if (_scopes.length > 1) ...[
                _ScopeTabs(
                  scopes: _scopes,
                  selected: _scope,
                  onSelect: (s) => setState(() => _scope = s),
                ),
                const SizedBox(height: Space.s18),
              ],
              const _Label('CE QUE VERRA LA PERSONNE'),
              _Preview(
                business: widget.business,
                product: _scope == ShareScope.product ? widget.product : null,
                scope: _scope,
                url: _url,
              ),
              const SizedBox(height: Space.s10),
              _Note(scope: _scope, hasPhoto: widget.product?.photoUrl != null),
              const SizedBox(height: Space.s18),
              _Actions(
                onWhatsApp: _whatsApp,
                onCopy: _copy,
                onOther: _other,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _whatsApp() async {
    final uri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(_message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp n’est pas installé.')),
      );
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié.')),
    );
  }

  Future<void> _other() async {
    await SharePlus.instance.share(ShareParams(text: _message));
  }
}

/// « Cet article · Le catalogue · La boutique » — widening only.
class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.scopes,
    required this.selected,
    required this.onSelect,
  });

  final List<ShareScope> scopes;
  final ShareScope selected;
  final ValueChanged<ShareScope> onSelect;

  static String _label(ShareScope scope) => switch (scope) {
        ShareScope.product => 'Cet article',
        ShareScope.catalogue => 'Le catalogue',
        ShareScope.shop => 'La boutique',
      };

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final scope in scopes)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(scope),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scope == selected ? brand.fill : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_label(scope),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: scope == selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: scope == selected
                              ? Colors.white
                              : PanergoColors.body)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The WhatsApp card, as it will look in the conversation.
///
/// No price and no « ouvert maintenant »: both are read three days later in a
/// family group, and both would be wrong by then.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.business,
    required this.product,
    required this.scope,
    required this.url,
  });

  final BusinessDetail business;
  final BusinessProduct? product;
  final ShareScope scope;
  final String url;

  String get _title => switch (scope) {
        ShareScope.product =>
          '${product?.name ?? ''} — ${business.name}',
        ShareScope.catalogue => 'Catalogue — ${business.name}',
        ShareScope.shop =>
          '${business.name} · ${business.categoryLabel} à ${business.neighborhood}',
      };

  String get _description => switch (scope) {
        ShareScope.product =>
          'Au rayon chez ${business.name}, ${business.neighborhood}. '
              'Demandez le prix du jour.',
        ShareScope.catalogue =>
          'Les articles de ${business.name} et leurs prix. '
              'Appelez ou écrivez directement.',
        ShareScope.shop =>
          'Adresse, horaires et articles au rayon. '
              'Appelez ou écrivez directement.',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(business: business, product: product, scope: scope),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111))),
                const SizedBox(height: 3),
                Text(_description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF555555))),
                const SizedBox(height: 4),
                Text(Uri.parse(url).host,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8A8A8A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the card shows above the text.
///
/// Almost no listing has a banner at first, so the composed case is the normal
/// one and is drawn as though it were intended — because it is.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.business,
    required this.product,
    required this.scope,
  });

  final BusinessDetail business;
  final BusinessProduct? product;
  final ShareScope scope;

  @override
  Widget build(BuildContext context) {
    final photo = scope == ShareScope.product
        ? product?.photoUrl
        : business.bannerUrl ?? business.photoUrl;

    if (photo != null && photo.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 1200 / 630,
        child: Image.network(
          ApiConfig.absolute(photo),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _Composed(business: business, product: product, scope: scope),
        ),
      );
    }
    return _Composed(business: business, product: product, scope: scope);
  }
}

class _Composed extends StatelessWidget {
  const _Composed({
    required this.business,
    required this.product,
    required this.scope,
  });

  final BusinessDetail business;
  final BusinessProduct? product;
  final ShareScope scope;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final initials = business.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return AspectRatio(
      aspectRatio: 1200 / 630,
      child: Container(
        color: brand.fill,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.s20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (scope == ShareScope.product)
              Text(product?.name ?? '',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white))
            else ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: Space.s8),
              Text(business.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text('${business.categoryLabel} · ${business.neighborhood}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85))),
            ],
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.scope, required this.hasPhoto});

  final ShareScope scope;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final text = switch (scope) {
      ShareScope.product => hasPhoto
          ? 'Le prix n’apparaît pas dans l’aperçu : il se lit sur la page, '
              'à jour.'
          : 'Le prix n’apparaît pas dans l’aperçu : il se lit sur la page, '
              'à jour. L’article n’a pas de photo, son nom en tient lieu.',
      _ => 'Sans bannière, la vignette est composée : aplat violet, initiales, '
          'nom. Elle a l’air voulue parce qu’elle l’est.',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaterialSymbol('info', size: 16, color: PanergoColors.subtle),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.45, color: PanergoColors.muted)),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onWhatsApp,
    required this.onCopy,
    required this.onOther,
  });

  final VoidCallback onWhatsApp;
  final VoidCallback onCopy;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Column(
      children: [
        GestureDetector(
          onTap: onWhatsApp,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: brand.fill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MaterialSymbol('chat', size: 20, color: Colors.white),
                SizedBox(width: Space.s8),
                Text('Envoyer sur WhatsApp',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s10),
        Row(
          children: [
            Expanded(
              child: _Secondary(
                  icon: 'link', label: 'Copier le lien', onTap: onCopy),
            ),
            const SizedBox(width: Space.s10),
            Expanded(
              child: _Secondary(
                  icon: 'ios_share', label: 'Autre', onTap: onOther),
            ),
          ],
        ),
      ],
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol(icon, size: 18, color: context.brand.link),
            const SizedBox(width: Space.s8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A link to an unpublished listing would lead to a page that is not there.
class _NotPublished extends StatelessWidget {
  const _NotPublished();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MaterialSymbol('visibility_off',
                size: 22, color: PanergoColors.muted),
            const SizedBox(width: Space.s10),
            const Expanded(
              child: Text('Votre fiche n’est visible par personne',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink)),
            ),
          ],
        ),
        const SizedBox(height: Space.s10),
        const Text(
          'Un lien vers une fiche non publiée mènerait vers une page vide. '
          'Publiez-la d’abord : le partage s’ouvrira aussitôt.',
          style: TextStyle(
              fontSize: 13, height: 1.5, color: PanergoColors.body),
        ),
        const SizedBox(height: Space.s18),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PanergoColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: PanergoColors.border),
            ),
            child: const Text('Plus tard',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.body)),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9, left: 1),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: PanergoColors.muted)),
    );
  }
}
