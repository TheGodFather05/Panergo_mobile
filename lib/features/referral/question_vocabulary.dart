import '../../core/models/enums.dart';

/// The words one audience uses for the same four screens.
///
/// The design builds `m_questions`/`m_question`/`m_qanswer`/`m_qsettings` and
/// their `p_` twins from one markup block and a single `isShopQ` flag: the
/// structure is identical and only the vocabulary changes. That is not a saving
/// of markup, it is the product decision — a shopkeeper and an artisan are both
/// being asked « is this something you can help with », and the answer is worth
/// the same three taps either way.
///
/// What differs is what they are promising. A shop says whether the thing is on
/// the shelf; an artisan says whether the work is in their range. Hence the one
/// line that matters most here, and which the design sets out in full for the
/// trade: « Ce n'est pas une offre. »
enum QuestionAudience {
  /// A shopkeeper, answering about stock.
  shop(
    yesLabel: 'J’en ai',
    noLabel: 'Je n’en ai pas',
    yesIcon: 'check_circle',
    answerTitle: 'Vous en avez',
    priceLabel: 'Votre prix',
    chipsLabel: 'Par',
    notePlaceholder: 'Marque, quantité en stock…',
    reassurance: 'Vous ne vous engagez à rien : dites seulement si vous en '
        'avez. Le client passera, ou vous appellera.',
    answerInfo: 'Le client voit votre boutique, ce prix et votre mot. Rien '
        'n’est mis de côté : il passe, ou il appelle.',
    nudgeIcon: 'inventory_2',
    nudgeCta: 'Ajouter au catalogue',
  ),

  /// An artisan, answering about whether the work is theirs.
  ///
  /// The reassurance is the whole reason this audience exists separately: an
  /// answer here is emphatically not an offer, and the artisan is told so on
  /// the screen before they tap. The real offer comes later, against a real
  /// request, with a real price.
  trade(
    yesLabel: 'Je peux le faire',
    noLabel: 'Ce n’est pas pour moi',
    yesIcon: 'handyman',
    answerTitle: 'Vous pouvez le faire',
    priceLabel: 'Tarif indicatif, à partir de',
    chipsLabel: 'Quand pourriez-vous passer ?',
    notePlaceholder: 'Ce qui est compris, ce qu’il faut prévoir…',
    reassurance: 'Ce n’est pas une offre. Dites si c’est dans vos cordes : si '
        'votre réponse l’intéresse, le client vous enverra une demande, et '
        'vous ferez votre offre à ce moment-là.',
    answerInfo: 'Le client voit votre profil, votre note et ce tarif '
        'indicatif. S’il est intéressé, il vous envoie une demande directe.',
    nudgeIcon: 'home_repair_service',
    nudgeCta: 'Ajouter à mes services',
  );

  const QuestionAudience({
    required this.yesLabel,
    required this.noLabel,
    required this.yesIcon,
    required this.answerTitle,
    required this.priceLabel,
    required this.chipsLabel,
    required this.notePlaceholder,
    required this.reassurance,
    required this.answerInfo,
    required this.nudgeIcon,
    required this.nudgeCta,
  });

  final String yesLabel;
  final String noLabel;
  final String yesIcon;
  final String answerTitle;

  /// « Votre prix » for a shop; for an artisan the price is explicitly
  /// indicative, and the label says so rather than leaving it to be inferred.
  final String priceLabel;

  /// « Par » (le sac, le kg) against « Quand pourriez-vous passer ? » — one is
  /// a quantity, the other a time, which is why they are separate columns in
  /// the database rather than one reused field.
  final String chipsLabel;

  final String notePlaceholder;

  /// Shown above the two buttons, before anything is committed.
  final String reassurance;

  /// Shown on the answer screen, saying exactly what the client will see.
  final String answerInfo;

  final String nudgeIcon;
  final String nudgeCta;

  /// Roughly how many questions arrive, measured rather than guessed.
  ///
  /// The design writes « environ 4 par semaine » for shops and « environ 6 »
  /// for artisans, but those are its fixtures — the real figure comes from the
  /// server, and this only phrases it.
  String frequency(int perWeek) => perWeek == 0
      ? 'Aucune question ces dernières semaines'
      : 'Environ $perWeek par semaine en ce moment';

  /// The chips offered on the answer screen.
  ///
  /// A shop's units come from the article it is answering about, so they are
  /// passed in; an artisan's windows are the same three every time.
  List<String> chipsFor(String? suggestedUnit) => switch (this) {
        QuestionAudience.trade => const [
            'Aujourd’hui',
            'Cette semaine',
            'À convenir',
          ],
        QuestionAudience.shop => [
            if (suggestedUnit != null && suggestedUnit.isNotEmpty) suggestedUnit,
            'la pièce',
            'le kg',
          ],
      };

  /// How a sent answer reads back in the list.
  String answerSummary({
    required bool yes,
    int? price,
    String? chip,
  }) {
    if (!yes) {
      return this == QuestionAudience.shop
          ? 'Vous n’en avez pas'
          : 'Pas pour vous';
    }
    if (this == QuestionAudience.shop) {
      return price == null
          ? 'Vous en avez'
          : 'Vous en avez · $price FCFA${chip == null ? '' : ' $chip'}';
    }
    return 'Vous pouvez le faire'
        '${price == null ? '' : ' · dès $price FCFA'}'
        '${chip == null ? '' : ' · ${chip.toLowerCase()}'}';
  }

  /// Which audience a question belongs to, read off the inquiry itself.
  static QuestionAudience of(InquiryAudienceKind kind) =>
      kind == InquiryAudienceKind.providers ? trade : shop;
}
