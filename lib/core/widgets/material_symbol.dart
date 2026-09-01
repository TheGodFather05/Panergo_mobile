import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Renders a Material Symbols Rounded glyph by its identifier.
///
/// The design names icons the way the icon font does (`plumbing`,
/// `auto_awesome`, `cloud_off`), so screens can be transcribed from the handoff
/// without a lookup table. Unknown names fall back to a neutral glyph rather
/// than throwing.
class MaterialSymbol extends StatelessWidget {
  const MaterialSymbol(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.filled = false,
  });

  final String name;
  final double size;
  final Color? color;

  /// The design uses the filled variant for icons that read as objects
  /// (a star, a verified badge) and the outlined one for actions.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _resolve(name, filled: filled),
      size: size,
      color: color ?? PanergoColors.ink,
    );
  }

  static IconData _resolve(String name, {required bool filled}) {
    final icon = filled ? _filled[name] : _outlined[name];
    return icon ?? _outlined[name] ?? Icons.circle_outlined;
  }

  // Material Symbols identifiers mapped onto the bundled Material Icons font.
  // Only the glyphs the design actually uses are listed.
  static const _outlined = <String, IconData>{
    // Navigation & chrome
    'home': Icons.home_outlined,
    'arrow_back': Icons.arrow_back,
    'arrow_forward': Icons.arrow_forward,
    'chevron_right': Icons.chevron_right,
    'expand_more': Icons.expand_more,
    'close': Icons.close,
    'search': Icons.search,
    'apps': Icons.apps,
    'sort': Icons.sort,
    'more_horiz': Icons.more_horiz,
    'edit': Icons.edit_outlined,
    'add': Icons.add,
    'add_circle': Icons.add_circle_outline,
    'settings': Icons.settings_outlined,
    'help': Icons.help_outline,
    'info': Icons.info_outline,
    'check': Icons.check,
    'check_circle': Icons.check_circle_outline,
    'cancel': Icons.cancel_outlined,
    'refresh': Icons.refresh,
    'wifi': Icons.wifi,
    'cloud_off': Icons.cloud_off,
    'error_outline': Icons.error_outline,
    'hourglass_empty': Icons.hourglass_empty,
    'schedule': Icons.schedule,
    'notifications': Icons.notifications_outlined,
    'notifications_active': Icons.notifications_active_outlined,
    'campaign': Icons.campaign_outlined,
    'groups': Icons.groups_outlined,
    'person': Icons.person_outline,
    'logout': Icons.logout,
    'star': Icons.star_border,
    'favorite': Icons.favorite_border,
    'location_on': Icons.location_on_outlined,
    'send': Icons.send,
    'call': Icons.call_outlined,
    'photo_camera': Icons.photo_camera_outlined,
    'attach_file': Icons.attach_file,
    'mic': Icons.mic_none,
    'add_a_photo': Icons.add_a_photo_outlined,
    'photo_library': Icons.photo_library_outlined,
    'image': Icons.image_outlined,
    'auto_awesome': Icons.auto_awesome_outlined,
    'verified': Icons.verified_outlined,
    'workspace_premium': Icons.workspace_premium_outlined,
    'sell': Icons.sell_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'local_offer': Icons.local_offer_outlined,
    'payments': Icons.payments_outlined,
    'account_balance_wallet': Icons.account_balance_wallet_outlined,
    'event_available': Icons.event_available_outlined,
    'qr_code': Icons.qr_code,
    'qr_code_scanner': Icons.qr_code_scanner,
    'lightbulb': Icons.lightbulb_outline,
    'solar_power': Icons.solar_power_outlined,
    'hardware': Icons.hardware_outlined,

    // Service categories
    'plumbing': Icons.plumbing_outlined,
    'bolt': Icons.bolt_outlined,
    'kitchen': Icons.kitchen_outlined,
    'cleaning_services': Icons.cleaning_services_outlined,
    'checkroom': Icons.checkroom_outlined,
    'format_paint': Icons.format_paint_outlined,
    'carpenter': Icons.carpenter_outlined,
    'foundation': Icons.foundation_outlined,
    'ac_unit': Icons.ac_unit_outlined,
    'grass': Icons.grass_outlined,
    'content_cut': Icons.content_cut,
    'computer': Icons.computer_outlined,
    'lock': Icons.lock_outline,
    'local_shipping': Icons.local_shipping_outlined,
    'build': Icons.build_outlined,
    'grid_view': Icons.grid_view_outlined,
    'window': Icons.window_outlined,
    'construction': Icons.construction_outlined,
  };

  static const _filled = <String, IconData>{
    'star': Icons.star,
    'check': Icons.check,
    'check_circle': Icons.check_circle,
    'verified': Icons.verified,
    'location_on': Icons.location_on,
    'auto_awesome': Icons.auto_awesome,
    'mic': Icons.mic,
    'workspace_premium': Icons.workspace_premium,
    'notifications': Icons.notifications,
    'favorite': Icons.favorite,
    'campaign': Icons.campaign,
    'groups': Icons.groups,
    'person': Icons.person,
  };
}
