import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/features/referral/question_vocabulary.dart';

/// The four question screens serve shops and artisans from one layout, so the
/// vocabulary is the only thing keeping them apart. These pin the distinctions
/// the design is explicit about — the ones that would be invisible in a
/// screenshot and wrong in production.
void main() {
  const shop = QuestionAudience.shop;
  const trade = QuestionAudience.trade;

  test('an artisan is told this is not an offer', () {
    // The load-bearing sentence of the whole feature. Without it an artisan
    // reads a question as a commitment and either over-promises or stops
    // answering.
    expect(trade.reassurance, contains('Ce n’est pas une offre'));
    expect(trade.reassurance, contains('vous ferez votre offre à ce moment-là'));

    // A shop is making no such promise, so it gets the other reassurance.
    expect(shop.reassurance, isNot(contains('offre')));
    expect(shop.reassurance, contains('Vous ne vous engagez à rien'));
  });

  test('the word « offre » never appears on the shop side', () {
    for (final s in [
      shop.yesLabel,
      shop.noLabel,
      shop.answerTitle,
      shop.priceLabel,
      shop.chipsLabel,
      shop.answerInfo,
      shop.reassurance,
    ]) {
      expect(s.toLowerCase(), isNot(contains('offre')),
          reason: 'a shop does not make offers: "$s"');
    }
  });

  test('an artisan\'s price is labelled indicative, a shop\'s is not', () {
    expect(trade.priceLabel, 'Tarif indicatif, à partir de');
    expect(shop.priceLabel, 'Votre prix');
  });

  test('the chips are a time for an artisan and a quantity for a shop', () {
    // Different columns in the database for exactly this reason: showing one
    // where the other belongs reads as a bug rather than as data.
    expect(trade.chipsFor(null),
        containsAll(['Aujourd’hui', 'Cette semaine', 'À convenir']));
    expect(trade.chipsLabel, 'Quand pourriez-vous passer ?');

    expect(shop.chipsLabel, 'Par');
    expect(shop.chipsFor('le sac').first, 'le sac',
        reason: 'the catalogue unit leads, so nobody retypes « le sac »');
  });

  test('a shop with no catalogue still gets usable units', () {
    final chips = shop.chipsFor(null);
    expect(chips, isNotEmpty);
    expect(chips, isNot(contains(null)));
  });

  test('the two buttons say different things', () {
    expect(shop.yesLabel, 'J’en ai');
    expect(shop.noLabel, 'Je n’en ai pas');
    expect(trade.yesLabel, 'Je peux le faire');
    expect(trade.noLabel, 'Ce n’est pas pour moi');
  });

  test('a sent answer reads back in that audience\'s own words', () {
    expect(shop.answerSummary(yes: true, price: 4500, chip: 'le sac'),
        'Vous en avez · 4500 FCFA le sac');
    expect(shop.answerSummary(yes: false), 'Vous n’en avez pas');

    expect(trade.answerSummary(yes: true, price: 15000, chip: 'Cette semaine'),
        'Vous pouvez le faire · dès 15000 FCFA · cette semaine');
    expect(trade.answerSummary(yes: false), 'Pas pour vous');
  });

  test('answering without a price still reads as an answer', () {
    // « Oui, passez voir » is a real reply, so it must render as one rather
    // than as a blank.
    expect(shop.answerSummary(yes: true), 'Vous en avez');
    expect(trade.answerSummary(yes: true), 'Vous pouvez le faire');
  });

  test('the frequency line is phrased, not invented', () {
    // The number comes from the server; this only words it. Zero says so
    // plainly rather than printing « environ 0 par semaine ».
    expect(shop.frequency(4), 'Environ 4 par semaine en ce moment');
    expect(trade.frequency(6), 'Environ 6 par semaine en ce moment');
    expect(shop.frequency(0), 'Aucune question ces dernières semaines');
  });

  test('the nudge points at the right place for each side', () {
    expect(shop.nudgeCta, 'Ajouter au catalogue');
    expect(trade.nudgeCta, 'Ajouter à mes services');
    expect(shop.nudgeIcon, 'inventory_2');
    expect(trade.nudgeIcon, 'home_repair_service');
  });
}
