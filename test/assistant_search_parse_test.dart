import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/network/json.dart';

/// Searching « ciment » returned a perfectly good 200 and the app showed
/// « une erreur inattendue est survenue ».
///
/// Json.list casts every element to a Map, and `services` is a list of plain
/// strings — so it threw three layers below the screen, where the only thing
/// left to say was that something unexpected happened. The payload below is
/// what the server actually answered.
const _ciment = r'''
{
  "observation": null,
  "quiet_because": "NOT_ENOUGH_PROVIDERS",
  "providers": [],
  "businesses": [
    {
      "business_id": "05f0257b-222f-4f7a-9202-e2185cbeb58c",
      "name": "Quincaillerie Bonanjo",
      "photo_url": null,
      "category_code": "QUINCAILLERIE",
      "category_label": "Quincaillerie",
      "neighborhood": "Akwa",
      "open_now": false,
      "services": ["Vente de ciment", "Découpe de tôle"],
      "matched_articles": []
    },
    {
      "business_id": "5d8f925b-47d0-470e-9dd8-15cdf207b117",
      "name": "Quincaillerie Logpom",
      "photo_url": "/uploads/x.png",
      "category_code": "QUINCAILLERIE",
      "category_label": "Quincaillerie",
      "neighborhood": "Logpom",
      "open_now": false,
      "services": ["Vente de ciment", "Clés minute"],
      "matched_articles": [
        {"name": "Sac de ciment 50kg", "price": 6500, "unit": "le sac"}
      ]
    }
  ],
  "referral_draft": null
}
''';

void main() {
  group('assistant search', () {
    test('parses the response « ciment » actually returns', () {
      final answer = AssistantAnswer.fromJson(
          jsonDecode(_ciment) as Map<String, dynamic>);

      expect(answer.businesses, hasLength(2));
      expect(answer.businesses.first.services,
          ['Vente de ciment', 'Découpe de tôle']);
      expect(answer.businesses.last.matchedArticles.first.price, 6500);
    });

    test('a shop with no services parses as empty, not as a failure', () {
      final json = jsonDecode(_ciment) as Map<String, dynamic>;
      (json['businesses'] as List).first['services'] = <dynamic>[];

      final answer = AssistantAnswer.fromJson(json);

      expect(answer.businesses.first.services, isEmpty);
    });

    test('a missing services key is empty rather than a crash', () {
      final json = jsonDecode(_ciment) as Map<String, dynamic>;
      (json['businesses'] as List).first.remove('services');

      expect(() => AssistantAnswer.fromJson(json), returnsNormally);
    });

    test('a server that does not send the count hides nothing', () {
      // The fixture above predates matched_article_count — it is exactly what
      // an older server answers. Absent, the count reads 0, and « hidden »
      // must come out 0 rather than negative: an app that announced
      // « et -1 autres références » would be worse than one that said nothing.
      final answer = AssistantAnswer.fromJson(
          jsonDecode(_ciment) as Map<String, dynamic>);

      expect(answer.businesses.last.matchedArticles, hasLength(1));
      expect(answer.businesses.last.hiddenArticleCount, 0);
    });

    test('the count says how many were cut, not how many fitted', () {
      final json = jsonDecode(_ciment) as Map<String, dynamic>;
      // One article shown of fifteen that matched: a deep catalogue, cut.
      (json['businesses'] as List).last['matched_article_count'] = 15;

      final shop = AssistantAnswer.fromJson(json).businesses.last;

      expect(shop.matchedArticles, hasLength(1));
      expect(shop.matchedArticleCount, 15);
      expect(shop.hiddenArticleCount, 14);
    });

    test('a whole list hides nothing', () {
      final json = jsonDecode(_ciment) as Map<String, dynamic>;
      // Everything that matched is shown — the common case.
      (json['businesses'] as List).last['matched_article_count'] = 1;

      expect(AssistantAnswer.fromJson(json).businesses.last.hiddenArticleCount,
          0);
    });
  });

  group('Json.strings', () {
    test('reads a list of plain strings', () {
      expect(Json.strings(['a', 'b']), ['a', 'b']);
    });

    test('is null-safe', () {
      expect(Json.strings(null), isEmpty);
    });

    test('Json.list still refuses a list of strings', () {
      // The distinction is the whole point: list() is for objects, and letting
      // it silently accept strings would hide the next mismatch of this kind.
      expect(() => Json.list(['a']), throwsA(isA<TypeError>()));
    });
  });
}
