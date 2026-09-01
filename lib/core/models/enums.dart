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
  rejected('REJECTED', 'Refusée');

  const OfferStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;
}

enum BookingStatus implements WireEnum {
  awaitingArrival('AWAITING_ARRIVAL', 'En attente d’arrivée'),
  arrived('ARRIVED', 'Prestataire arrivé'),
  completed('COMPLETED', 'Terminée');

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

enum UserRole implements WireEnum {
  user('USER'),
  provider('PROVIDER');

  const UserRole(this.wire);

  @override
  final String wire;
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
  question('QUESTION', 'Question'),
  prestataire('PRESTATAIRE', 'Prestataire'),
  recommandation('RECOMMANDATION', 'Recommandation');

  const QuartierPostKind(this.wire, this.label);

  @override
  final String wire;
  final String label;
}
