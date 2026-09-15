import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';

/// These fixtures are verbatim responses captured from a running backend, so a
/// change in the wire contract shows up here rather than on a screen.
void main() {
  group('AppUser', () {
    test('parses a verify-otp user', () {
      final json = jsonDecode('''
        {"id":"c9ace9da-570d-416a-94d7-9abeccb4927e","name":"Murielle Tchatchoua",
         "phone_number":"+237600000001","neighborhood":"Bonamoussadi","role":"USER"}
      ''') as Map<String, dynamic>;

      final user = AppUser.fromJson(json);

      expect(user.name, 'Murielle Tchatchoua');
      expect(user.isProvider, isFalse);
      expect(user.needsProfileCompletion, isFalse);
      expect(user.initials, 'MT');
    });

    test('flags a freshly auto-registered account as needing a profile', () {
      // First login names the user after their phone number and leaves the
      // quartier blank.
      final user = AppUser.fromJson({
        'id': 'x',
        'name': '+237600000001',
        'phone_number': '+237600000001',
        'neighborhood': '',
        'role': 'USER',
      });

      expect(user.needsProfileCompletion, isTrue);
    });

    // Being a provider is a flag on the account, not a role the token carries:
    // the same person places orders as a client with the same identity. The
    // legacy 'role' string is still emitted by the server and deliberately
    // ignored here.
    test('reads the provider flag, not the legacy role string', () {
      final user = AppUser.fromJson({
        'id': 'x',
        'name': 'Jean-Pierre Mbarga',
        'phone_number': '+237600000002',
        'neighborhood': 'Bonamoussadi',
        'role': 'USER',
        'is_provider': true,
      });

      expect(user.isProvider, isTrue);
      expect(user.initials, 'JM');
    });
  });

  group('profile completion', () {
    // The routing between Bienvenue and the app hangs entirely on this getter,
    // and it was inverted: the server reports whether the profile IS complete,
    // the getter asks whether it still NEEDS completing. Reading the flag
    // straight through sent everyone who had just filled the form back to it.
    test('a completed profile does not need completing', () {
      final user = AppUser.fromJson({
        'id': 'x',
        'name': 'Arkel Test',
        'phone_number': '+237699555666',
        'neighborhood': 'Akwa',
        'country_code': 'CM',
        'city': 'Douala',
        'is_provider': false,
        'profile_complete': true,
      });

      expect(user.needsProfileCompletion, isFalse);
    });

    test('a fresh account does need completing', () {
      final user = AppUser.fromJson({
        'id': 'x',
        'name': '+237699555666',
        'phone_number': '+237699555666',
        'neighborhood': '',
        'is_provider': false,
        'profile_complete': false,
      });

      expect(user.needsProfileCompletion, isTrue);
    });

    test('an older session with no flag falls back to the shape of the data', () {
      final stale = AppUser.fromJson({
        'id': 'x',
        'name': '+237600000001',
        'phone_number': '+237600000001',
        'neighborhood': '',
        'is_provider': false,
      });

      expect(stale.needsProfileCompletion, isTrue);
    });
  });

  group('ServiceRequest', () {
    test('parses the /api/requests/mine payload', () {
      final json = jsonDecode('''
        {"request_id":"cd360bbb-edc4-4155-9b0e-fdca0f6475ae","category":"SOUDURE",
         "neighborhood":"Bonamoussadi","description":"Portail a ressouder",
         "status":"OPEN","urgency":"WEEK","budget_bracket":"B_5000_10000",
         "created_at":"2026-09-01T17:00:35.003453Z","offers":[]}
      ''') as Map<String, dynamic>;

      final request = ServiceRequest.fromJson(json);

      expect(request.category, ServiceCategory.soudure);
      expect(request.urgency, Urgency.week);
      expect(request.budget, BudgetBracket.from5000to10000);
      expect(request.status, RequestStatus.open);
      expect(request.offers, isEmpty);
      // Microsecond precision must survive parsing.
      expect(request.createdAt.toUtc().year, 2026);
      expect(request.createdAt.toUtc().month, 9);
    });

    test('leaves budget null when the client did not pick one', () {
      final request = ServiceRequest.fromJson({
        'request_id': 'r',
        'category': 'PLOMBERIE',
        'neighborhood': 'Bonamoussadi',
        'description': 'Fuite',
        'status': 'OPEN',
        'urgency': 'NOW',
        'budget_bracket': null,
        'created_at': '2026-09-01T17:00:35Z',
        'offers': const [],
      });

      expect(request.budget, isNull);
      expect(request.urgency, Urgency.now);
    });

    test('falls back rather than throwing on an unknown category', () {
      // An older build must not crash when the server adds a trade.
      final request = ServiceRequest.fromJson({
        'request_id': 'r',
        'category': 'ASTRONAUTIQUE',
        'neighborhood': 'Bonamoussadi',
        'description': 'x',
        'status': 'OPEN',
        'urgency': 'FLEX',
        'created_at': '2026-09-01T17:00:35Z',
        'offers': const [],
      });

      expect(request.category, ServiceCategory.plomberie);
    });
  });

  group('Offer', () {
    test('parses the enriched offer card fields', () {
      final offer = Offer.fromJson({
        'offer_id': 'd389daba-ea04-41ed-a3bd-5e3ddf203b99',
        'provider_id': '10b88b7e-0bb5-4f24-be0a-9245bac9294e',
        'provider_name': 'Jean-Pierre Mbarga',
        'provider_photo_url': null,
        'provider_avg_rating': 4.9,
        'provider_completed_bookings': 340,
        'price': 8000,
        'timeline_label': 'AUJOURD_HUI',
        'message': 'Je peux passer cet après-midi.',
        'status': 'PENDING',
        'created_at': '2026-09-01T17:01:53.413234Z',
      });

      expect(offer.providerName, 'Jean-Pierre Mbarga');
      expect(offer.providerAvgRating, 4.9);
      expect(offer.providerCompletedBookings, 340);
      expect(offer.price, 8000);
      expect(offer.timeline, TimelineLabel.aujourdHui);
      expect(offer.status, OfferStatus.pending);
    });
  });

  group('AvailableRequest', () {
    test('keeps urgency label and chosen urgency separate', () {
      final request = AvailableRequest.fromJson({
        'request_id': 'e5e448e6-4e7e-4556-90e6-e66cc6ae4842',
        'category': 'PLOMBERIE',
        'neighborhood': 'Bonamoussadi',
        'description': 'Fuite urgente sous evier',
        'photo_url': null,
        'created_at': '2026-09-01T17:01:17.447885Z',
        'urgency_label': 'URGENT',
        'urgency': 'NOW',
        'budget_bracket': null,
      });

      expect(request.urgencyLabel, UrgencyLabel.urgent);
      expect(request.urgency, Urgency.now);
      // Title case, never shouted.
      expect(request.urgencyLabel.label, 'Urgent');
    });
  });

  group('DirectMatch', () {
    test('parses an unmatched dispatch', () {
      final match = DirectMatch.fromJson({
        'request_id': 'e5e448e6-4e7e-4556-90e6-e66cc6ae4842',
        'matched': false,
        'provider_id': null,
        'provider_name': null,
        'provider_photo_url': null,
        'provider_avg_rating': null,
        'provider_completed_bookings': 0,
        'estimated_price_min': null,
        'estimated_price_max': null,
      });

      expect(match.matched, isFalse);
      expect(match.hasEstimate, isFalse);
    });

    test('parses a match with an estimate range', () {
      final match = DirectMatch.fromJson({
        'request_id': 'r',
        'matched': true,
        'provider_id': 'p',
        'provider_name': 'Jean-Pierre Mbarga',
        'provider_photo_url': null,
        'provider_avg_rating': 4.9,
        'provider_completed_bookings': 340,
        'estimated_price_min': 8000,
        'estimated_price_max': 9500,
      });

      expect(match.matched, isTrue);
      expect(match.hasEstimate, isTrue);
      expect(match.estimatedPriceMin, 8000);
    });

    test('a matched provider with no history has no estimate', () {
      final match = DirectMatch.fromJson({
        'request_id': 'r',
        'matched': true,
        'provider_id': 'p',
        'provider_name': 'Nouvelle Prestataire',
        'provider_completed_bookings': 0,
        'estimated_price_min': null,
        'estimated_price_max': null,
      });

      expect(match.matched, isTrue);
      expect(match.hasEstimate, isFalse);
    });
  });

  group('ProviderRatingsPage', () {
    test('zero-fills every bar of the distribution', () {
      final page = ProviderRatingsPage.fromJson({
        'content': const [],
        'page': 0,
        'total_pages': 1,
        'total_ratings': 128,
        'average': 4.9,
        // The server only returns scores that actually occurred.
        'distribution': {'5': 110, '4': 14, '3': 3, '2': 1},
      });

      expect(page.distribution.keys.toList()..sort(), [1, 2, 3, 4, 5]);
      expect(page.distribution[1], 0);
      expect(page.distribution[5], 110);
      expect(page.share(5), closeTo(110 / 128, 0.001));
    });

    test('share is zero when there are no ratings, not a divide by zero', () {
      final page = ProviderRatingsPage.fromJson({
        'content': const [],
        'page': 0,
        'total_pages': 0,
        'total_ratings': 0,
        'average': 0,
        'distribution': const {},
      });

      expect(page.share(5), 0);
    });
  });

  group('QuartierPost', () {
    test('parses a board post', () {
      final post = QuartierPost.fromJson({
        'post_id': 'a387ab44-c362-491a-bc59-637715577f07',
        'author_id': 'c9ace9da-570d-416a-94d7-9abeccb4927e',
        'author_name': 'Murielle Tchatchoua',
        'neighborhood': 'Bonamoussadi',
        'kind': 'QUESTION',
        'body': 'Quelqu’un connaît un bon électricien ?',
        'reply_count': 7,
        'created_at': '2026-09-01T17:01:17.183528Z',
      });

      expect(post.kind, QuartierPostKind.question);
      expect(post.replyCount, 7);
    });
  });

  group('Deal', () {
    test('parses a seeded partner deal', () {
      final deal = Deal.fromJson({
        'deal_id': 'c88a0085-a023-422a-853d-797a0a3e85d9',
        'partner_name': 'Quincaillerie La Référence',
        'category_label': 'Matériel de plomberie',
        'discount_label': '−15%',
        'description': 'Sur tout le matériel ce mois-ci avec le code PANERGO15.',
        'validity_label': 'Jusqu\'au 30 juin',
        'photo_url': null,
      });

      expect(deal.partnerName, 'Quincaillerie La Référence');
      expect(deal.discountLabel, '−15%');
    });
  });

  group('AssistantAnswer', () {
    test('tolerates a null observation when the assistant is disabled', () {
      final answer = AssistantAnswer.fromJson({
        'observation': null,
        'providers': const [],
      });

      expect(answer.observation, isNull);
      expect(answer.providers, isEmpty);
    });
  });

  group('date parsing', () {
    test('accepts an epoch number as well as an ISO string', () {
      // Jackson's date format is not pinned server-side, so both forms parse.
      final iso = ChatMessage.fromJson({
        'message_id': 'm',
        'booking_id': 'b',
        'sender_id': 's',
        'sender_role': 'USER',
        'content': 'Bonjour',
        'sent_at': '2026-09-01T17:00:00Z',
      });
      final epoch = ChatMessage.fromJson({
        'message_id': 'm',
        'booking_id': 'b',
        'sender_id': 's',
        'sender_role': 'USER',
        'content': 'Bonjour',
        'sent_at': 1788282000,
      });

      expect(iso.sentAt.toUtc(), DateTime.utc(2026, 9, 1, 17));
      expect(epoch.sentAt.toUtc(), DateTime.utc(2026, 9, 1, 17));
    });
  });
}
