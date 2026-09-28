import '../network/json.dart';

/// The 18 trades Panergo covers. Wire values are enforced by a database
/// constraint, so the spellings here must match exactly.
enum ServiceCategory implements WireEnum {
  plomberie('PLOMBERIE', 'Plomberie', 'plumbing'),
  electricite('ELECTRICITE', 'Électricité', 'bolt'),
  electromenager('ELECTROMENAGER', 'Électroménager', 'kitchen'),
  nettoyage('NETTOYAGE', 'Nettoyage', 'cleaning_services'),
  couture('COUTURE', 'Couture', 'checkroom'),
  peinture('PEINTURE', 'Peinture', 'format_paint'),
  menuiserie('MENUISERIE', 'Menuiserie', 'carpenter'),
  maconnerie('MACONNERIE', 'Maçonnerie', 'foundation'),
  climatisation('CLIMATISATION', 'Climatisation', 'ac_unit'),
  jardinage('JARDINAGE', 'Jardinage', 'grass'),
  coiffure('COIFFURE', 'Coiffure', 'content_cut'),
  informatique('INFORMATIQUE', 'Informatique', 'computer'),
  serrurerie('SERRURERIE', 'Serrurerie', 'lock'),
  demenagement('DEMENAGEMENT', 'Déménagement', 'local_shipping'),
  mecaniqueAuto('MECANIQUE_AUTO', 'Mécanique auto', 'build'),
  carrelage('CARRELAGE', 'Carrelage', 'grid_view'),
  vitrerie('VITRERIE', 'Vitrerie', 'window'),
  soudure('SOUDURE', 'Soudure', 'construction');

  const ServiceCategory(this.wire, this.label, this.iconName);

  @override
  final String wire;

  /// French display name.
  final String label;

  /// Material Symbols identifier from the design.
  final String iconName;

  /// Index into the five-tint palette, so a category keeps one colour app-wide.
  int get tintIndex => ServiceCategory.values.indexOf(this);
}

/// When the client needs the job done, as picked on the request form.
///
/// [now] is the one with consequences: it routes to direct dispatch instead of
/// opening a tender.
enum Urgency implements WireEnum {
  now('NOW', 'Tout de suite'),
  today('TODAY', 'Aujourd’hui'),
  week('WEEK', 'Cette semaine'),
  flex('FLEX', 'Peu importe');

  const Urgency(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

/// Optional budget hint, in FCFA.
enum BudgetBracket implements WireEnum {
  under5000('LT_5000', 'moins de 5 000'),
  from5000to10000('B_5000_10000', '5 000 – 10 000'),
  from10000to25000('B_10000_25000', '10 000 – 25 000'),
  over25000('GT_25000', 'plus de 25 000');

  const BudgetBracket(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

/// How soon a provider says they can intervene.
enum TimelineLabel implements WireEnum {
  aujourdHui('AUJOURD_HUI', 'Aujourd’hui'),
  demain('DEMAIN', 'Demain'),
  sous2Jours('SOUS_2_JOURS', 'Sous 2 jours'),
  cetteSemaine('CETTE_SEMAINE', 'Cette semaine');

  const TimelineLabel(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

enum RequestStatus implements WireEnum {
  open('OPEN', 'Ouverte'),
  offerSelected('OFFER_SELECTED', 'En cours'),
  completed('COMPLETED', 'Terminée'),
  cancelled('CANCELLED', 'Annulée');

  const RequestStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

enum OfferStatus implements WireEnum {
  pending('PENDING', 'En attente'),
  selected('SELECTED', 'Acceptée'),
  rejected('REJECTED', 'Refusée'),

  /// The artisan took it back before the client chose.
  ///
  /// Not « refusée »: nobody chose against it. The distinction is what lets the
  /// screen say « vous pouvez en envoyer une nouvelle », and what keeps it off
  /// their response rate.
  withdrawn('WITHDRAWN', 'Retirée');

  const OfferStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;

  /// Still waiting on the client.
  bool get isLive => this == pending;

  /// Over, one way or another — nothing more will happen to it.
  bool get isSettled => this == selected || this == rejected;
}

enum BookingStatus implements WireEnum {
  awaitingArrival('AWAITING_ARRIVAL', 'En attente d’arrivée'),
  arrived('ARRIVED', 'Prestataire arrivé'),
  completed('COMPLETED', 'Terminée'),
  cancelled('CANCELLED', 'Annulée'),

  /// The provider never came. Kept apart from [cancelled] because it is the one
  /// ending that says something about the provider rather than about the job.
  noShow('NO_SHOW', 'Prestataire absent');

  const BookingStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

/// Badge on a provider's inbox card. Derived server-side from the request's age
/// and the client's chosen urgency — never uppercase in the UI.
enum UrgencyLabel implements WireEnum {
  urgent('URGENT', 'Urgent'),
  recent('RECENT', 'Récente'),
  standard('STANDARD', 'Cette semaine');

  const UrgencyLabel(this.wire, this.label);

  @override
  final String wire;
  final String label;
}


enum PostType implements WireEnum {
  realisation('REALISATION', 'Réalisation'),
  conseil('CONSEIL', 'Conseil');

  const PostType(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

/// What a neighbourhood post is for.
enum QuartierPostKind implements WireEnum {
  // Icons and hints from the design's kind picker. Its third kind is
  // « Information »; the server's is PRESTATAIRE, and the server's list is the
  // contract — so the hint describes what this one actually posts.
  question('QUESTION', 'Question', 'help',
      'Vous cherchez un conseil ou un prestataire'),
  prestataire('PRESTATAIRE', 'Prestataire', 'handyman',
      'Vous proposez vos services au quartier'),
  recommandation('RECOMMANDATION', 'Recommandation', 'thumb_up',
      'Vous voulez citer quelqu’un de bien');

  const QuartierPostKind(this.wire, this.label, this.iconName, this.hint);

  @override
  final String wire;
  final String label;

  /// The glyph beside the label in the kind picker.
  final String iconName;

  /// What choosing this kind means, shown under the picker so the three are
  /// distinguishable before anything is typed.
  final String hint;
}


/// Where one round of a price negotiation ended up.
///
/// [withdrawn] is not a refusal: nobody turned the price down, the provider
/// simply arrived before it was answered. The copy has to keep that distinction
/// — "refusé" would put a decision in the record that nobody made.
enum ProposalStatus implements WireEnum {
  pending('PENDING', 'En attente'),
  accepted('ACCEPTED', 'Accepté'),
  countered('COUNTERED', 'Contré'),
  withdrawn('WITHDRAWN', 'Sans réponse avant l’arrivée');

  const ProposalStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

/// Which side of the table someone is on.
enum PartyRole implements WireEnum {
  user('USER', 'Client'),
  provider('PROVIDER', 'Prestataire'),
  // Both reachable: a business conversation resolves the shopkeeper to BUSINESS
  // and a group resolves a participant to MEMBER. Absent here they parsed as
  // « Client » through the fallback, silently — nothing reads senderRole yet, so
  // the first screen that does would have inherited the wrong answer.
  business('BUSINESS', 'Commerce'),
  member('MEMBER', 'Membre');

  const PartyRole(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

/// Why a metric has no number.
///
/// A refusal is a first-class state, not an error and not a blank: a rate over
/// three offers is noise with a percent sign, and shown to an artisan it becomes
/// a fact about them they will act on.
enum MetricUnavailability implements WireEnum {
  notEnoughData('NOT_ENOUGH_DATA', 'Pas encore assez de données'),
  notMeasurableYet('NOT_MEASURABLE_YET', 'Bientôt disponible'),
  noActivityInPeriod('NO_ACTIVITY_IN_PERIOD', 'Aucune activité sur la période');

  const MetricUnavailability(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

/// The window a revenue figure covers.
enum RevenuePeriod implements WireEnum {
  allTime('ALL_TIME', 'Tout'),
  thisMonth('THIS_MONTH', 'Ce mois'),
  lastMonth('LAST_MONTH', 'Mois dernier'),
  last30Days('LAST_30_DAYS', '30 jours');

  const RevenuePeriod(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

// ---------------------------------------------------------- relayed search ---

/// Why the assistant said nothing.
///
/// Four of these five are deliberate restraint and one is a fault, and the
/// screen has to tell them apart: [unavailable] is the only one that earns the
/// error dressing and a retry (design 2B), while [notEnoughProviders] and
/// [notEnoughHistory] can arrive with a full list of open shops beside them.
/// Rendering any silence as "nothing found" would hide a pharmacy open now.
enum AssistantSilence implements WireEnum {
  disabled('DISABLED'),
  notEnoughProviders('NOT_ENOUGH_PROVIDERS'),
  notEnoughHistory('NOT_ENOUGH_HISTORY'),
  unavailable('UNAVAILABLE'),

  /// Nothing matched at all — the one value a screen may draw as empty, and the
  /// one that carries the offer to ask the shops instead.
  nothingFound('NOTHING_FOUND');

  const AssistantSilence(this.wire);

  @override
  final String wire;

  static AssistantSilence? fromWire(String? wire) {
    if (wire == null) return null;
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return null;
  }

  /// Whether this is a breakage rather than a choice.
  bool get isFault => this == unavailable;
}

/// Which market a relayed question went to.
enum ReferralTarget implements WireEnum {
  /// An artisan, through the tender: a price to come and do the work.
  trade('TRADE', 'Un artisan', 'Vous recevrez des offres avec un prix.'),

  /// A shop, through a stock question: whether it is worth walking over.
  shop('SHOP', 'Un commerce', 'Vous saurez qui en a, et à quel prix.');

  const ReferralTarget(this.wire, this.label, this.outcome);

  @override
  final String wire;
  final String label;

  /// What happens next if this is chosen. Design 3C puts it under each option,
  /// because « une offre » and « un déplacement » are different commitments.
  final String outcome;
}

/// What became of a question the server routed.
enum ReferralKind implements WireEnum {
  trade('TRADE'),
  shop('SHOP'),

  /// Nothing was created: the words point at both markets, and guessing would
  /// send the question to half the people who could answer it.
  ambiguous('AMBIGUOUS');

  const ReferralKind(this.wire);

  @override
  final String wire;

  static ReferralKind fromWire(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return shop;
  }
}

/// Who a relayed question was put to.
///
/// One or the other, never both: « 4 500 le sac » and « je peux passer jeudi »
/// answer different questions, and a list mixing them is unreadable. When the
/// words point both ways the design asks the person to choose rather than
/// running both searches and merging them.
enum InquiryAudienceKind implements WireEnum {
  shops('SHOPS'),
  providers('PROVIDERS');

  const InquiryAudienceKind(this.wire);

  @override
  final String wire;

  static InquiryAudienceKind fromWire(String? wire) =>
      wire == 'PROVIDERS' ? providers : shops;
}

/// How wide a relayed question was actually sent.
enum InquiryScope implements WireEnum {
  quartier('QUARTIER'),
  city('CITY');

  const InquiryScope(this.wire);

  @override
  final String wire;

  static InquiryScope fromWire(String? wire) =>
      wire == 'CITY' ? city : quartier;
}

/// Where a relayed question stands.
enum InquiryStatus implements WireEnum {
  open('OPEN'),
  closed('CLOSED'),
  expired('EXPIRED');

  const InquiryStatus(this.wire);

  @override
  final String wire;

  static InquiryStatus fromWire(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return open;
  }
}
