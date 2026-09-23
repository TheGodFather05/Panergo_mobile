import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/messages/chat_screen.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/network/api_exception.dart';
import 'package:panergo_mobile/core/network/chat_socket.dart';
import 'package:panergo_mobile/features/messages/chat_providers.dart';

ChatMessage message(
  String id, {
  String sender = 'user-1',
  PartyRole role = PartyRole.user,
  String? content = 'Bonjour',
  String? photoUrl,
  DateTime? sentAt,
}) =>
    ChatMessage(
      id: id,
      conversationId: 'booking-1',
      senderId: sender,
      senderRole: role,
      content: content,
      photoUrl: photoUrl,
      sentAt: sentAt ?? DateTime(2026, 9, 3, 16, 4),
    );

void main() {
  group('ChatMessage', () {
    test('parses a message off the topic', () {
      final parsed = ChatMessage.fromJson(const {
        'message_id': 'm-1',
        'conversation_id': 'c-1',
        'sender_id': 'u-1',
        'sender_role': 'USER',
        'content': 'Je suis devant le portail',
        'photo_url': null,
        'sent_at': '2026-09-03T16:04:00Z',
      });

      expect(parsed.id, 'm-1');
      expect(parsed.conversationId, 'c-1');
      expect(parsed.senderRole, PartyRole.user);
      expect(parsed.content, 'Je suis devant le portail');
      expect(parsed.isPhoto, isFalse);
    });

    test('a photo message carries no content', () {
      final parsed = ChatMessage.fromJson(const {
        'message_id': 'm-2',
        'conversation_id': 'b-1',
        'sender_id': 'u-1',
        'sender_role': 'PROVIDER',
        'content': null,
        'photo_url': 'https://cdn.panergo.cm/fuite.jpg',
        'sent_at': '2026-09-03T16:05:00Z',
      });

      expect(parsed.isPhoto, isTrue);
      expect(parsed.senderRole, PartyRole.provider);
    });

    test('an empty photo url is not a photo message', () {
      expect(message('m-3', photoUrl: '').isPhoto, isFalse);
    });
  });

  group('ChatThread', () {
    test('sending is only offered while the socket is connected', () {
      const connected = ChatThread(connection: ChatConnection.connected);
      const connecting = ChatThread(connection: ChatConnection.connecting);
      const dropped = ChatThread(connection: ChatConnection.disconnected);

      expect(connected.canSend, isTrue);
      expect(connecting.canSend, isFalse,
          reason: 'a message sent before CONNECT would be dropped silently');
      expect(dropped.canSend, isFalse);
    });

    test('a thread with no messages is empty', () {
      expect(const ChatThread().isEmpty, isTrue);
      expect(ChatThread(messages: [message('m-1')]).isEmpty, isFalse);
    });

    test('copyWith clears an error rather than carrying it forward', () {
      final failed = ChatThread(
        isLoading: false,
        error: const ApiException(code: 'OFFLINE', message: 'Hors ligne'),
      );

      expect(failed.copyWith(clearError: true).error, isNull);
      expect(failed.copyWith(isLoading: true).error, isNotNull,
          reason: 'an unrelated update must not silently drop the error');
    });
  });

  group('Conversation', () {
    // isOpenable is gone with the concept behind it. A thread used to be keyed
    // by booking, so a row could exist before there was anything to open; a
    // conversation exists because somebody opened it, and every row navigates.
    test('parses a business thread', () {
      final conversation = Conversation.fromJson({
        'conversation_id': 'c-1',
        'kind': 'BUSINESS',
        'peer_name': 'Quincaillerie Bonanjo',
        'subtitle': 'Quincaillerie',
        'business_id': 'b-9',
        'last_message_at': '2026-09-22T16:04:00Z',
      });

      expect(conversation.kind, ConversationKind.business);
      expect(conversation.businessId, 'b-9');
      expect(conversation.bookingId, isNull);
      expect(conversation.subtitle, 'Quincaillerie');
    });

    test('parses a booking thread', () {
      final conversation = Conversation.fromJson({
        'conversation_id': 'c-2',
        'kind': 'BOOKING',
        'peer_name': 'Jean-Pierre Mballa',
        'subtitle': 'PLOMBERIE',
        'booking_id': 'bk-3',
      });

      expect(conversation.kind, ConversationKind.booking);
      expect(conversation.bookingId, 'bk-3');
      expect(conversation.businessId, isNull);
      // A thread nobody has spoken in yet: the inbox sorts these last rather
      // than first, which a null would otherwise do.
      expect(conversation.lastMessageAt, isNull);
    });
  });

  group('ChatScreen', () {
    setUpAll(() => initializeDateFormatting('fr_FR'));

    Widget wrap(ChatThread thread) => ProviderScope(
          overrides: [
            chatControllerProvider('b1')
                .overrideWith(() => _StubChatController(thread)),
          ],
          child: MaterialApp(
            theme: AppTheme.build(BrandDirection.braise),
            locale: const Locale('fr', 'FR'),
            home: const ChatScreen(conversationId: 'b1', peerName: 'Jean-Pierre'),
          ),
        );

    testWidgets('renders the thread with a composer', (tester) async {
      await tester.pumpWidget(wrap(ChatThread(
        isLoading: false,
        connection: ChatConnection.connected,
        messages: [
          message('m1', sender: 'them', content: 'Je passe vers 16h.'),
          message('m2', sender: 'me', content: 'Parfait, merci.'),
        ],
      )));
      await tester.pump();

      expect(find.text('Jean-Pierre'), findsOneWidget);
      expect(find.text('Je passe vers 16h.'), findsOneWidget);
      expect(find.text('Parfait, merci.'), findsOneWidget);
      expect(find.text('Écrire un message…'), findsOneWidget);
    });

    testWidgets('the presence line reports the socket, not a guess',
        (tester) async {
      await tester.pumpWidget(wrap(ChatThread(
        isLoading: false,
        connection: ChatConnection.disconnected,
        messages: [message('m1')],
      )));
      await tester.pump();

      // Claiming "En ligne" while the socket is down would be a lie the user
      // only discovers when their message vanishes.
      expect(find.text('Hors ligne'), findsOneWidget);
      expect(find.text('En ligne'), findsNothing);
    });

    testWidgets('an empty thread invites the first message', (tester) async {
      await tester.pumpWidget(wrap(const ChatThread(
        isLoading: false,
        connection: ChatConnection.connected,
      )));
      await tester.pump();

      expect(find.text('Dites bonjour'), findsOneWidget);
      // Panergo introduces, it does not transact — the empty state says so.
      expect(find.textContaining('aucune commission'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry rather than a blank thread',
        (tester) async {
      await tester.pumpWidget(wrap(const ChatThread(
        isLoading: false,
        error: ApiException.offline(),
      )));
      await tester.pump();

      expect(find.text('Vous êtes hors ligne'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}

/// Serves a fixed thread so the widget tests never open a socket.
class _StubChatController extends ChatController {
  _StubChatController(this._thread) : super('b1');

  final ChatThread _thread;

  @override
  Future<ChatThread> build() async => _thread;
}
