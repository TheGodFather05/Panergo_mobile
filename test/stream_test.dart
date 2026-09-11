import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';

/// Parsed against a payload captured from the running backend, so the test
/// fails if the wire shape drifts rather than only if the parser does.
void main() {
  group('StreamPage', () {
    const payload = '''
    {"content":[
      {"id":"6c284665-a7a0-42d5-9acb-aac935b68495","kind":"QUARTIER",
       "author_id":"00173596-fcd8-414c-8620-6a899c2c444e","author_name":"Client Test",
       "neighborhood":"Akwa","body":"Qui connait un bon plombier a Akwa ?",
       "post_kind":"QUESTION","reply_count":0,"mark_count":0,"marked":false,
       "created_at":"2026-09-11T22:39:30.355118Z"},
      {"id":"e57ce409-d8c3-4d60-b251-78f94afa1e04","kind":"PROVIDER",
       "author_id":"82013e3e-6181-4262-aad2-77b23178a29f","author_name":"Jean Plombier",
       "neighborhood":"Bonapriso","body":"Salle de bain refaite a neuf",
       "photo_url":"/uploads/12c882c3.jpg","category":"PLOMBERIE",
       "reply_count":2,"mark_count":1,"marked":true,
       "created_at":"2026-09-11T22:40:04.412676Z"}],
     "page":0,"total_pages":1,"total_posts":2,
     "neighborhood":"Akwa","only_mine":false}
    ''';

    test('parses both kinds out of one stream', () {
      final page =
          StreamPage.fromJson(jsonDecode(payload) as Map<String, dynamic>);

      expect(page.content, hasLength(2));
      expect(page.neighborhood, 'Akwa');
      expect(page.onlyMine, isFalse);

      final question = page.content.first;
      expect(question.kind, StreamKind.quartier);
      expect(question.postKind, QuartierPostKind.question);
      // A neighbour's post has no photo and no trade.
      expect(question.photoUrl, isNull);
      expect(question.category, isNull);
      expect(question.isRealisation, isFalse);

      final work = page.content.last;
      expect(work.kind, StreamKind.provider);
      expect(work.isRealisation, isTrue);
      expect(work.photoUrl, isNotNull);
      expect(work.category, isNotNull);
      // A réalisation carries no quartier post kind.
      expect(work.postKind, isNull);
      expect(work.marked, isTrue);
      expect(work.markCount, 1);
      expect(work.replyCount, 2);
    });

    test('each kind marks under its own name', () {
      final page =
          StreamPage.fromJson(jsonDecode(payload) as Map<String, dynamic>);

      // The mark table is keyed by kind, so the card must send the right one or
      // a réalisation and a board post could collide on the same id.
      expect(page.content.first.markKind, 'QUARTIER');
      expect(page.content.last.markKind, 'PROVIDER');
    });
  });
}
