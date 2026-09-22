import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/widgets/material_symbol.dart';

/// Every symbol name the app asks for must resolve to a real glyph.
///
/// An unmapped name falls back to a plain circle. Nothing fails, nothing warns,
/// and the screen ships with a blank dot where an icon should be — which is how
/// fourteen of them reached a device, including the Feed tab and the « Utile »
/// thumb. The compiler cannot catch a missing map entry because the name is a
/// string, so this test stands in for it.
void main() {
  testWidgets('no symbol falls back to the placeholder circle', (tester) async {
    // The names used across the app. Keep in step with MaterialSymbol callers.
    const names = <String>[
      'home', 'arrow_back', 'chevron_right', 'dynamic_feed', 'receipt_long',
      'campaign', 'person', 'thumb_up', 'forum', 'send', 'edit', 'photo_camera',
      'add_a_photo', 'support_agent', 'translate', 'account_circle', 'phone',
      'info', 'logout', 'settings', 'help', 'group', 'handyman', 'task_alt',
      'event_note', 'event_busy', 'hourglass_top', 'mark_email_unread',
      'chat_bubble', 'keyboard', 'arrow_outward', 'image_not_supported',
      'location_on', 'location_city', 'public', 'notifications',
      // Passed as `icon:` strings rather than direct calls — the sweep that
      // found the first batch missed every one of these.
      'block', 'calendar_month', 'chat', 'chevron_left', 'equalizer',
      'flashlight_on', 'insights', 'phone', 'search_off', 'swap_horiz', 'tune',
      // The merged feed's own glyphs.
      'request_quote', 'cloud_off', 'add', 'close',
      // The directory: every icon the seeded business taxonomy names, because a
      // category whose glyph is a blank circle looks like a bug in the data.
      'storefront', 'inventory_2', 'visibility', 'pause_circle',
      'local_pharmacy', 'medical_services', 'hardware', 'restaurant',
      'bakery_dining', 'car_repair', 'local_gas_station', 'smartphone',
      'menu_book', 'checkroom', 'local_laundry_service', 'store', 'content_cut',
      'computer', 'local_shipping', 'add_business', 'near_me', 'panorama',
      'date_range', 'add_link', 'language', 'play_circle',
      'remove_shopping_cart',
    ];

    for (final name in names) {
      for (final filled in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          home: MaterialSymbol(name, filled: filled),
        ));
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(
          icon.icon,
          isNot(Icons.circle_outlined),
          reason: '"$name" (filled: $filled) is not mapped and renders as a '
              'blank circle',
        );
      }
    }
  });
}
