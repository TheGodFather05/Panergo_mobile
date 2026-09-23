import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/providers.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/messages/messages_screen.dart';

/// The inbox must draw every kind it is given.
///
/// Reported as "I started discussions with businesses from the annuaire but
/// didn't have them in Messages". The list is split into a group strip and the
/// one-to-one threads below it, and a split is exactly the kind of change that
/// can silently drop whatever it did not think about.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('business threads appear alongside groups', (tester) async {
    final rows = [
      Conversation(
        conversationId: 'c1', kind: ConversationKind.business,
        peerName: 'Quincaillerie Bonanjo', subtitle: 'Quincaillerie',
        businessId: 'b1', lastMessageAt: DateTime(2026, 9, 23, 17, 16),
      ),
      Conversation(
        conversationId: 'c2', kind: ConversationKind.group,
        peerName: 'Quartier Logpom', subtitle: '2 membres',
        groupId: 'g1', iconName: 'groups',
      ),
      Conversation(
        conversationId: 'c3', kind: ConversationKind.business,
        peerName: 'Pharmacie du Rond-Point', subtitle: 'Pharmacie',
        businessId: 'b2', lastMessageAt: DateTime(2026, 9, 23, 10, 24),
      ),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) async => rows),
        currentUserProvider.overrideWith((ref) => const AppUser(
            id: 'u1', name: 'Arkel', phoneNumber: '+237670239279',
            neighborhood: 'Logpom', isProvider: false, isAdmin: false)),
      ],
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        home: const Scaffold(body: MessagesScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Both business threads, below the strip.
    expect(find.text('Quincaillerie Bonanjo'), findsOneWidget);
    expect(find.text('Pharmacie du Rond-Point'), findsOneWidget);
    // And the group, in it.
    expect(find.text('Quartier Logpom'), findsOneWidget);
  });
}
