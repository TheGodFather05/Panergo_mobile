import '../network/json.dart';
import 'enums.dart';

/// The signed-in person.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.neighborhood,
    required this.isProvider,
    this.isAdmin = false,
    this.countryCode,
    this.city,
    this.photoUrl,
    this.profileComplete,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String neighborhood;
  final String? countryCode;
  final String? city;
  final String? photoUrl;

  /// Whether this person has a provider profile.
  ///
  /// A capability, not an identity: the same account is a client when it hires
  /// someone and an artisan when it works. Read from the server, which checks
  /// the database — the token stopped claiming to know.
  final bool isProvider;

  /// May review business listings.
  ///
  /// Read from the server on every profile load rather than remembered, so
  /// withdrawing it takes effect on the next refresh rather than the next
  /// sign-in.
  final bool isAdmin;

  /// The server's answer to whether they have introduced themselves. Null only
  /// for a session stored before the server could say.
  final bool? profileComplete;

  /// Whether to ask who they are before opening the app.
  ///
  /// An account is created by the first OTP with the phone number standing in
  /// for a name and nowhere to route anything to. The string test is the
  /// fallback for a session stored before the server answered this directly —
  /// it is a guess, and it is wrong about anyone genuinely displaying their
  /// number.
  /// Note the negation: the server reports whether the profile IS complete,
  /// and this asks whether it still needs completing. Reading the flag straight
  /// through sent everyone who had just filled the form back to it, because a
  /// successful save answers `profile_complete: true`.
  bool get needsProfileCompletion =>
      profileComplete != null
          ? !profileComplete!
          : (neighborhood.trim().isEmpty || name == phoneNumber);

  /// The initials shown on avatar tiles when there is no photo.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters(2);
    return '${parts.first.characters(1)}${parts.last.characters(1)}';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: Json.str(json['id']),
        name: Json.str(json['name']),
        phoneNumber: Json.str(json['phone_number']),
        neighborhood: Json.str(json['neighborhood']),
        countryCode: Json.strOrNull(json['country_code']),
        city: Json.strOrNull(json['city']),
        photoUrl: Json.strOrNull(json['photo_url']),
        isProvider: Json.boolOf(json['is_provider']),
        isAdmin: Json.boolOf(json['is_admin']),
        profileComplete: json['profile_complete'] == null
            ? null
            : Json.boolOf(json['profile_complete']),
      );
}

extension on String {
  String characters(int count) =>
      (length <= count ? this : substring(0, count)).toUpperCase();
}

/// The result of verifying an OTP.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: Json.str(json['token']),
        user: AppUser.fromJson(Json.obj(json['user'])),
      );
}

/// An offer on a request, as the client sees it in the offers list.
class Offer {
  const Offer({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerPhotoUrl,
    required this.providerAvgRating,
    required this.providerCompletedBookings,
    required this.price,
    required this.timeline,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String? providerPhotoUrl;
  final double providerAvgRating;
  final int providerCompletedBookings;
  final int price;
  final TimelineLabel timeline;
  final String? message;
  final OfferStatus status;
  final DateTime createdAt;

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        id: Json.str(json['offer_id']),
        providerId: Json.str(json['provider_id']),
        providerName: Json.str(json['provider_name']),
        providerPhotoUrl: Json.strOrNull(json['provider_photo_url']),
        providerAvgRating: Json.dbl(json['provider_avg_rating']),
        providerCompletedBookings:
            Json.intOf(json['provider_completed_bookings']),
        price: Json.intOf(json['price']),
        timeline: Json.enumOf(
            json['timeline_label'], TimelineLabel.values, TimelineLabel.demain),
        message: Json.strOrNull(json['message']),
        status: Json.enumOf(json['status'], OfferStatus.values, OfferStatus.pending),
        createdAt: Json.dateTime(json['created_at']),
      );
}

/// One of the provider's own offers, with enough of the request attached to
/// render their list without a second call.
///
/// [bookingId] is what turns a won offer into a job the provider can open: it
/// arrives only once this offer is the selected one.
class MyOffer {
  const MyOffer({
    required this.offerId,
    required this.requestId,
    required this.bookingId,
    required this.category,
    required this.neighborhood,
    required this.requestDescription,
    required this.requestStatus,
    required this.clientName,
    required this.price,
    required this.timeline,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String offerId;
  final String requestId;
  final String? bookingId;
  final ServiceCategory category;
  final String neighborhood;
  final String requestDescription;
  final RequestStatus requestStatus;
  final String clientName;
  final int price;
  final TimelineLabel timeline;
  final String? message;
  final OfferStatus status;
  final DateTime createdAt;

  /// Won, and not cancelled out from under them.
  bool get isWon =>
      status == OfferStatus.selected &&
      requestStatus != RequestStatus.cancelled;

  /// Whether there is a booking to open. A selected offer whose booking has not
  /// landed yet stays visible but inert rather than opening onto nothing.
  bool get isOpenable => bookingId != null && bookingId!.isNotEmpty;

  factory MyOffer.fromJson(Map<String, dynamic> json) => MyOffer(
        offerId: Json.str(json['offer_id']),
        requestId: Json.str(json['request_id']),
        bookingId: Json.strOrNull(json['booking_id']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        neighborhood: Json.str(json['neighborhood']),
        requestDescription: Json.str(json['request_description']),
        requestStatus: Json.enumOf(
            json['request_status'], RequestStatus.values, RequestStatus.open),
        clientName: Json.str(json['client_name']),
        price: Json.intOf(json['price']),
        timeline: Json.enumOf(
            json['timeline_label'], TimelineLabel.values, TimelineLabel.demain),
        message: Json.strOrNull(json['message']),
        status: Json.enumOf(
            json['status'], OfferStatus.values, OfferStatus.pending),
        createdAt: Json.dateTime(json['created_at']),
      );
}

/// A service request the client posted.
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.category,
    required this.neighborhood,
    required this.description,
    required this.photoUrl,
    required this.status,
    required this.urgency,
    required this.budget,
    required this.createdAt,
    required this.offers,
    required this.bookingId,
  });

  final String id;
  final ServiceCategory category;
  final String neighborhood;
  final String description;
  final String? photoUrl;
  final RequestStatus status;
  final Urgency urgency;
  final BudgetBracket? budget;
  final DateTime createdAt;
  final List<Offer> offers;

  /// Null until an offer is accepted; the way back into a live mission.
  final String? bookingId;

  bool get isOpen => status == RequestStatus.open;
  bool get hasOffers => offers.isNotEmpty;

  factory ServiceRequest.fromJson(Map<String, dynamic> json) => ServiceRequest(
        id: Json.str(json['request_id']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        neighborhood: Json.str(json['neighborhood']),
        description: Json.str(json['description']),
        photoUrl: Json.strOrNull(json['photo_url']),
        status: Json.enumOf(json['status'], RequestStatus.values, RequestStatus.open),
        urgency: Json.enumOf(json['urgency'], Urgency.values, Urgency.flex),
        budget: Json.enumOrNull(json['budget_bracket'], BudgetBracket.values),
        createdAt: Json.dateTime(json['created_at']),
        offers: Json.list(json['offers']).map(Offer.fromJson).toList(),
        bookingId: Json.strOrNull(json['booking_id']),
      );
}

/// A request on the provider's job board.
class AvailableRequest {
  const AvailableRequest({
    required this.id,
    required this.category,
    required this.neighborhood,
    required this.description,
    required this.photoUrl,
    required this.createdAt,
    required this.urgencyLabel,
    required this.urgency,
  });

  final String id;
  final ServiceCategory category;
  final String neighborhood;
  final String description;
  final String? photoUrl;
  final DateTime createdAt;
  final UrgencyLabel urgencyLabel;
  final Urgency urgency;

  factory AvailableRequest.fromJson(Map<String, dynamic> json) =>
      AvailableRequest(
        id: Json.str(json['request_id']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        neighborhood: Json.str(json['neighborhood']),
        description: Json.str(json['description']),
        photoUrl: Json.strOrNull(json['photo_url']),
        createdAt: Json.dateTime(json['created_at']),
        urgencyLabel: Json.enumOf(json['urgency_label'], UrgencyLabel.values,
            UrgencyLabel.standard),
        urgency: Json.enumOf(json['urgency'], Urgency.values, Urgency.flex),
      );
}

/// A provider's public profile.
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.category,
    required this.neighborhood,
    required this.bio,
    required this.completedBookings,
    required this.avgRating,
    required this.avgResponseTimeHours,
    required this.lastActiveAt,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final ServiceCategory category;
  final String neighborhood;
  final String? bio;
  final int completedBookings;
  final double avgRating;

  /// Null for a provider who has not yet won a job.
  final double? avgResponseTimeHours;
  final DateTime? lastActiveAt;

  factory ProviderProfile.fromJson(Map<String, dynamic> json) => ProviderProfile(
        id: Json.str(json['id']),
        name: Json.str(json['name']),
        photoUrl: Json.strOrNull(json['photo_url']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        neighborhood: Json.str(json['neighborhood']),
        bio: Json.strOrNull(json['bio']),
        completedBookings: Json.intOf(json['completed_bookings']),
        avgRating: Json.dbl(json['avg_rating']),
        avgResponseTimeHours: Json.dblOrNull(json['avg_response_time_hours']),
        lastActiveAt: Json.dateTimeOrNull(json['last_active_at']),
      );
}

/// One review on a provider's profile.
class ProviderRating {
  const ProviderRating({
    required this.id,
    required this.authorName,
    required this.score,
    required this.comment,
    this.authorPhotoUrl,
    required this.category,
    required this.neighborhood,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String? authorPhotoUrl;
  final int score;
  final String? comment;
  final ServiceCategory category;
  final String neighborhood;
  final DateTime createdAt;

  factory ProviderRating.fromJson(Map<String, dynamic> json) => ProviderRating(
        id: Json.str(json['rating_id']),
        authorName: Json.str(json['author_name']),
        authorPhotoUrl: Json.strOrNull(json['author_photo_url']),
        score: Json.intOf(json['score']),
        comment: Json.strOrNull(json['comment']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        neighborhood: Json.str(json['neighborhood']),
        createdAt: Json.dateTime(json['created_at']),
      );
}

/// A page of reviews plus the summary above them.
class ProviderRatingsPage {
  const ProviderRatingsPage({
    required this.reviews,
    required this.page,
    required this.totalPages,
    required this.totalRatings,
    required this.average,
    required this.distribution,
  });

  final List<ProviderRating> reviews;
  final int page;
  final int totalPages;
  final int totalRatings;
  final double average;

  /// Score (5..1) to count, always all five keys so the chart has every bar.
  final Map<int, int> distribution;

  /// The share of reviews at [score], for the bar widths.
  double share(int score) {
    if (totalRatings == 0) return 0;
    return (distribution[score] ?? 0) / totalRatings;
  }

  factory ProviderRatingsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['distribution'];
    final distribution = <int, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final score = int.tryParse('$key');
        if (score != null) distribution[score] = Json.intOf(value);
      });
    }
    for (var score = 1; score <= 5; score++) {
      distribution.putIfAbsent(score, () => 0);
    }

    return ProviderRatingsPage(
      reviews: Json.list(json['content']).map(ProviderRating.fromJson).toList(),
      page: Json.intOf(json['page']),
      totalPages: Json.intOf(json['total_pages']),
      totalRatings: Json.intOf(json['total_ratings']),
      average: Json.dbl(json['average']),
      distribution: distribution,
    );
  }
}

/// The provider matched by a direct dispatch.
class DirectMatch {
  const DirectMatch({
    required this.requestId,
    required this.matched,
    required this.providerId,
    required this.providerName,
    required this.providerPhotoUrl,
    required this.providerAvgRating,
    required this.providerCompletedBookings,
    required this.estimatedPriceMin,
    required this.estimatedPriceMax,
  });

  final String requestId;

  /// False when nobody in the quartier was available; the screen then offers
  /// the tender instead.
  final bool matched;
  final String? providerId;
  final String? providerName;
  final String? providerPhotoUrl;
  final double? providerAvgRating;
  final int providerCompletedBookings;

  /// Null for a provider with no offer history — show no estimate rather than
  /// inventing one.
  final int? estimatedPriceMin;
  final int? estimatedPriceMax;

  bool get hasEstimate => estimatedPriceMin != null && estimatedPriceMax != null;

  factory DirectMatch.fromJson(Map<String, dynamic> json) => DirectMatch(
        requestId: Json.str(json['request_id']),
        matched: Json.boolOf(json['matched']),
        providerId: Json.strOrNull(json['provider_id']),
        providerName: Json.strOrNull(json['provider_name']),
        providerPhotoUrl: Json.strOrNull(json['provider_photo_url']),
        providerAvgRating: Json.dblOrNull(json['provider_avg_rating']),
        providerCompletedBookings:
            Json.intOf(json['provider_completed_bookings']),
        estimatedPriceMin: Json.intOrNull(json['estimated_price_min']),
        estimatedPriceMax: Json.intOrNull(json['estimated_price_max']),
      );
}

/// A confirmed job.
class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.requestId,
    required this.category,
    required this.neighborhood,
    required this.description,
    required this.offer,
    required this.qrToken,
    required this.arrivedAt,
    required this.completedAt,
  });

  final String id;
  final BookingStatus status;
  final String requestId;
  final ServiceCategory category;
  final String neighborhood;
  final String description;
  final Offer offer;

  /// Only the client receives this — they are the one who presents it.
  final String? qrToken;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: Json.str(json['booking_id']),
        status: Json.enumOf(
            json['status'], BookingStatus.values, BookingStatus.awaitingArrival),
        requestId: Json.str(json['request_id']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        neighborhood: Json.str(json['neighborhood']),
        description: Json.str(json['description']),
        offer: Offer.fromJson(Json.obj(json['offer'])),
        qrToken: Json.strOrNull(json['qr_token']),
        arrivedAt: Json.dateTimeOrNull(json['arrived_at']),
        completedAt: Json.dateTimeOrNull(json['completed_at']),
      );
}

/// A chat message. The same shape arrives over REST history and the STOMP topic.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.photoUrl,
    required this.sentAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final PartyRole senderRole;
  final String? content;
  final String? photoUrl;
  final DateTime sentAt;

  bool get isPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: Json.str(json['message_id']),
        conversationId: Json.str(json['conversation_id']),
        senderId: Json.str(json['sender_id']),
        senderRole:
            Json.enumOf(json['sender_role'], PartyRole.values, PartyRole.user),
        content: Json.strOrNull(json['content']),
        photoUrl: Json.strOrNull(json['photo_url']),
        sentAt: Json.dateTime(json['sent_at']),
      );
}

/// A post on the neighbourhood board.
class QuartierPost {
  const QuartierPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.neighborhood,
    required this.kind,
    this.authorPhotoUrl,
    required this.body,
    required this.replyCount,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String neighborhood;
  final QuartierPostKind kind;
  final String body;
  final int replyCount;
  final DateTime createdAt;

  factory QuartierPost.fromJson(Map<String, dynamic> json) => QuartierPost(
        id: Json.str(json['post_id']),
        authorId: Json.str(json['author_id']),
        authorName: Json.str(json['author_name']),
        authorPhotoUrl: Json.strOrNull(json['author_photo_url']),
        neighborhood: Json.str(json['neighborhood']),
        kind: Json.enumOf(json['kind'], QuartierPostKind.values,
            QuartierPostKind.question),
        body: Json.str(json['body']),
        replyCount: Json.intOf(json['reply_count']),
        createdAt: Json.dateTime(json['created_at']),
      );
}

class QuartierReply {
  const QuartierReply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.authorPhotoUrl,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String body;
  final DateTime createdAt;

  factory QuartierReply.fromJson(Map<String, dynamic> json) => QuartierReply(
        id: Json.str(json['reply_id']),
        authorId: Json.str(json['author_id']),
        authorName: Json.str(json['author_name']),
        authorPhotoUrl: Json.strOrNull(json['author_photo_url']),
        body: Json.str(json['body']),
        createdAt: Json.dateTime(json['created_at']),
      );
}

/// A partner offer on the Deals screen.
class Deal {
  const Deal({
    required this.id,
    required this.partnerName,
    required this.categoryLabel,
    required this.discountLabel,
    required this.description,
    required this.validityLabel,
    required this.photoUrl,
  });

  final String id;
  final String partnerName;
  final String categoryLabel;
  final String discountLabel;
  final String description;
  final String validityLabel;
  final String? photoUrl;

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
        id: Json.str(json['deal_id']),
        partnerName: Json.str(json['partner_name']),
        categoryLabel: Json.str(json['category_label']),
        discountLabel: Json.str(json['discount_label']),
        description: Json.str(json['description']),
        validityLabel: Json.str(json['validity_label']),
        photoUrl: Json.strOrNull(json['photo_url']),
      );
}

/// A provider's post in the public feed.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerPhotoUrl,
    required this.category,
    required this.neighborhood,
    required this.photoUrl,
    required this.caption,
    required this.postType,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String? providerPhotoUrl;
  final ServiceCategory category;
  final String neighborhood;
  final String photoUrl;
  final String? caption;
  final PostType postType;
  final DateTime createdAt;

  /// « Utile » marks and replies. Both were hardcoded to zero on the server
  /// until the profile needed them, so a card showing a figure here is now
  /// showing a real one.
  final int likesCount;
  final int commentsCount;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final provider = Json.obj(json['provider']);
    return FeedPost(
      id: Json.str(json['post_id']),
      providerId: Json.str(provider['id']),
      providerName: Json.str(provider['name']),
      providerPhotoUrl: Json.strOrNull(provider['photo_url']),
      category: Json.enumOf(provider['category'], ServiceCategory.values,
          ServiceCategory.plomberie),
      neighborhood: Json.str(provider['neighborhood']),
      photoUrl: Json.str(json['photo_url']),
      caption: Json.strOrNull(json['caption']),
      postType: Json.enumOf(json['post_type'], PostType.values, PostType.realisation),
      createdAt: Json.dateTime(json['created_at']),
      likesCount: Json.intOf(json['likes_count']),
      commentsCount: Json.intOf(json['comments_count']),
    );
  }
}

/// A provider returned by the assistant search.
class AssistantResult {
  const AssistantResult({
    required this.providerId,
    required this.name,
    required this.photoUrl,
    required this.category,
    required this.completedBookings,
    required this.avgRating,
    required this.avgResponseTimeHours,
    required this.statedAvailability,
    required this.priceFromLastOffer,
    required this.dataMissing,
  });

  final String providerId;
  final String name;
  final String? photoUrl;
  final ServiceCategory category;
  final int completedBookings;
  final double avgRating;
  final double? avgResponseTimeHours;
  final String? statedAvailability;
  final int? priceFromLastOffer;

  /// Field names the backend had no data for. Shown honestly rather than
  /// papered over.
  final List<String> dataMissing;

  factory AssistantResult.fromJson(Map<String, dynamic> json) => AssistantResult(
        providerId: Json.str(json['provider_id']),
        name: Json.str(json['name']),
        photoUrl: Json.strOrNull(json['photo_url']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        completedBookings: Json.intOf(json['completed_bookings']),
        avgRating: Json.dbl(json['avg_rating']),
        avgResponseTimeHours: Json.dblOrNull(json['avg_response_time_hours']),
        statedAvailability: Json.strOrNull(json['stated_availability']),
        priceFromLastOffer: Json.intOrNull(json['price_from_last_offer']),
        dataMissing: Json.strings(json['data_missing']),
      );
}

/// A place from the annuaire among the assistant's answers.
///
/// Never narrated. The assistant speaks about artisans, where it has ratings
/// and completed missions to speak from; a shop's opening hours are facts it
/// lists without comment.
class AssistantBusiness {
  const AssistantBusiness({
    required this.businessId,
    required this.name,
    required this.categoryCode,
    required this.categoryLabel,
    required this.neighborhood,
    required this.openNow,
    required this.services,
    required this.matchedArticles,
    this.photoUrl,
  });

  final String businessId;
  final String name;
  final String? photoUrl;
  final String categoryCode;
  final String categoryLabel;
  final String neighborhood;
  final bool openNow;
  final List<String> services;

  /// Articles the question mentioned — why this shop is in the results.
  final List<AssistantArticle> matchedArticles;

  factory AssistantBusiness.fromJson(Map<String, dynamic> json) =>
      AssistantBusiness(
        businessId: Json.str(json['business_id']),
        name: Json.str(json['name']),
        photoUrl: Json.strOrNull(json['photo_url']),
        categoryCode: Json.str(json['category_code']),
        categoryLabel: Json.str(json['category_label']),
        neighborhood: Json.str(json['neighborhood']),
        openNow: Json.boolOf(json['open_now']),
        services: Json.strings(json['services']),
        matchedArticles: Json.list(json['matched_articles'])
            .map(AssistantArticle.fromJson)
            .toList(),
      );
}

/// One article from a shop's catalogue that the question named.
class AssistantArticle {
  const AssistantArticle({required this.name, this.price, this.unit});

  final String name;

  /// Null is « prix sur demande », never zero — which would say it is free.
  final int? price;
  final String? unit;

  factory AssistantArticle.fromJson(Map<String, dynamic> json) =>
      AssistantArticle(
        name: Json.str(json['name']),
        price: Json.intOrNull(json['price']),
        unit: Json.strOrNull(json['unit']),
      );
}

/// The assistant's answer: an optional observation plus grounded results.
class AssistantAnswer {
  const AssistantAnswer({
    required this.observation,
    required this.quietBecause,
    required this.providers,
    required this.businesses,
    required this.referralDraft,
  });

  /// Null when the assistant is disabled server-side or the model call failed.
  final String? observation;

  /// Why nothing was said. Read at last: the app used to drop it, which left it
  /// unable to tell deliberate restraint from a broken model call — and unable
  /// to tell either from an empty search.
  final AssistantSilence? quietBecause;

  final List<AssistantResult> providers;

  /// Places from the annuaire. The server has always returned these; the app
  /// simply never read them, so a pharmacy matching the question was found and
  /// then thrown away.
  final List<AssistantBusiness> businesses;

  /// A question that could be relayed to the shops, present only when nothing
  /// was found and there is somebody to ask.
  final ReferralDraft? referralDraft;

  /// Nothing matched in either market.
  ///
  /// Asked of the server's own verdict rather than inferred from two empty
  /// lists: the backend decides what counts as empty, and the two agreeing is
  /// what keeps the proposal and the results telling the same story.
  bool get foundNothing => quietBecause == AssistantSilence.nothingFound;

  /// The assistant is quiet but the search still answered. The results stand on
  /// their own and there is nothing to retry.
  bool get quietWithResults =>
      quietBecause != null &&
      !quietBecause!.isFault &&
      !foundNothing &&
      (providers.isNotEmpty || businesses.isNotEmpty);

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) => AssistantAnswer(
        observation: Json.strOrNull(json['observation']),
        quietBecause:
            AssistantSilence.fromWire(Json.strOrNull(json['quiet_because'])),
        providers:
            Json.list(json['providers']).map(AssistantResult.fromJson).toList(),
        businesses: Json.list(json['businesses'])
            .map(AssistantBusiness.fromJson)
            .toList(),
        referralDraft: json['referral_draft'] == null
            ? null
            : ReferralDraft.fromJson(
                json['referral_draft'] as Map<String, dynamic>),
      );
}

/// A question the person could relay to the shops, prepared but not sent.
///
/// Never anything more than a draft. At the end of the gesture several
/// shopkeepers get a notification, so it goes through a confirmation sheet
/// (RM-09) — a search that quietly messaged nine traders would be the worst
/// possible reading of a typed question.
class ReferralDraft {
  const ReferralDraft({
    required this.text,
    required this.neighborhood,
    required this.wouldReach,
    required this.wouldWiden,
    this.suggestedCategoryCode,
    this.suggestedCategoryLabel,
    this.trade,
  });

  /// The question, verbatim, as the first draft of the relayed one.
  final String text;
  final String neighborhood;

  /// How many shops would receive it. A count and never the rows, so an
  /// unanswerable search cannot be used to enumerate the directory.
  final int wouldReach;

  /// The quartier holds too few shops to compare, so it would go city-wide.
  final bool wouldWiden;

  /// Null when the question is about an article rather than a kind of shop:
  /// « du ciment » belongs to no category.
  final String? suggestedCategoryCode;
  final String? suggestedCategoryLabel;

  /// The trade being asked, when the question goes to artisans.
  ///
  /// Set instead of [suggestedCategoryCode], never beside it: a question goes
  /// to one market or the other, and carrying both would let a screen render a
  /// shop category over an artisan's answer.
  final ServiceCategory? trade;

  /// Whether this draft is addressed to artisans rather than shops.
  bool get isTrade => trade != null;

  factory ReferralDraft.fromJson(Map<String, dynamic> json) => ReferralDraft(
        text: Json.str(json['text']),
        neighborhood: Json.str(json['neighborhood']),
        wouldReach: Json.intOf(json['would_reach']),
        wouldWiden: json['would_widen'] == true,
        suggestedCategoryCode: Json.strOrNull(json['suggested_category_code']),
        suggestedCategoryLabel: Json.strOrNull(json['suggested_category_label']),
      );
}

// ------------------------------------------------------ price negotiation ---

/// One round of haggling over an offer's price.
class PriceProposal {
  const PriceProposal({
    required this.id,
    required this.proposedBy,
    required this.proposerName,
    required this.price,
    required this.message,
    required this.status,
    required this.resolvedAt,
    required this.createdAt,
  });

  final String id;
  final PartyRole proposedBy;
  final String proposerName;
  final int price;
  final String? message;
  final ProposalStatus status;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  bool get isLive => status == ProposalStatus.pending;

  factory PriceProposal.fromJson(Map<String, dynamic> json) => PriceProposal(
        id: Json.str(json['id']),
        proposedBy:
            Json.enumOf(json['proposed_by'], PartyRole.values, PartyRole.user),
        proposerName: Json.str(json['proposer_name']),
        price: Json.intOf(json['price']),
        message: Json.strOrNull(json['message']),
        status: Json.enumOf(
            json['status'], ProposalStatus.values, ProposalStatus.pending),
        resolvedAt: Json.dateTimeOrNull(json['resolved_at']),
        createdAt: Json.dateTime(json['created_at']),
      );
}

/// The state of the haggle over one offer, and how it got there.
///
/// Three prices because they answer three questions: what was first asked, what
/// both sides settled on, and what is currently waiting for an answer.
class PriceNegotiation {
  const PriceNegotiation({
    required this.offerId,
    required this.openingPrice,
    required this.agreedPrice,
    required this.effectivePrice,
    required this.pendingPrice,
    required this.locked,
    required this.proposals,
  });

  final String offerId;
  final int openingPrice;
  final int? agreedPrice;

  /// What the client owes as things stand — the agreed price where there is one.
  final int effectivePrice;

  /// The number currently on the table, or null when nobody is waiting.
  final int? pendingPrice;

  /// True once the provider has confirmed arrival: the price is final and the
  /// compose affordance must disappear rather than sit there and fail.
  final bool locked;

  final List<PriceProposal> proposals;

  /// The round awaiting an answer, if any.
  PriceProposal? get pending =>
      proposals.where((p) => p.isLive).firstOrNull;

  /// True when a price was haggled rather than simply accepted as quoted.
  bool get wasNegotiated => agreedPrice != null;

  factory PriceNegotiation.fromJson(Map<String, dynamic> json) =>
      PriceNegotiation(
        offerId: Json.str(json['offer_id']),
        openingPrice: Json.intOf(json['opening_price']),
        agreedPrice: Json.intOrNull(json['agreed_price']),
        effectivePrice: Json.intOf(json['effective_price']),
        pendingPrice: Json.intOrNull(json['pending_price']),
        locked: Json.boolOf(json['locked']),
        proposals: Json.list(json['proposals'])
            .map(PriceProposal.fromJson)
            .toList(),
      );
}

// -------------------------------------------------------------- schedule ---

/// One job on the agenda.
class AgendaJob {
  const AgendaJob({
    required this.bookingId,
    required this.scheduledAt,
    required this.scheduledEndAt,
    required this.category,
    required this.clientName,
    required this.neighborhood,
    required this.description,
    required this.price,
    required this.status,
  });

  final String bookingId;

  /// Null for an urgent job dispatched without a date — real committed work,
  /// but not an appointment, so it belongs beside the grid rather than in it.
  final DateTime? scheduledAt;
  final DateTime? scheduledEndAt;
  final ServiceCategory category;
  final String clientName;
  final String neighborhood;
  final String description;
  final int price;
  final BookingStatus status;

  factory AgendaJob.fromJson(Map<String, dynamic> json) => AgendaJob(
        bookingId: Json.str(json['booking_id']),
        scheduledAt: Json.dateTimeOrNull(json['scheduled_at']),
        scheduledEndAt: Json.dateTimeOrNull(json['scheduled_end_at']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        clientName: Json.str(json['client_name']),
        neighborhood: Json.str(json['neighborhood']),
        description: Json.str(json['description']),
        price: Json.intOf(json['price']),
        status: Json.enumOf(
            json['status'], BookingStatus.values, BookingStatus.awaitingArrival),
      );
}

/// One day in the week view.
///
/// A quiet working day and a declared day off look nothing alike on the screen,
/// so they are told apart here rather than left for the widget to guess.
class AgendaDay {
  const AgendaDay({
    required this.date,
    required this.workingDay,
    required this.startTime,
    required this.endTime,
    required this.off,
    required this.timeOffReason,
    required this.jobs,
  });

  final DateTime date;

  /// Whether the provider declared hours for this weekday.
  final bool workingDay;
  final String? startTime;
  final String? endTime;

  /// True when an absence covers this date.
  final bool off;
  final String? timeOffReason;
  final List<AgendaJob> jobs;

  factory AgendaDay.fromJson(Map<String, dynamic> json) => AgendaDay(
        date: Json.dateTime(json['date']),
        workingDay: Json.boolOf(json['working_day']),
        startTime: Json.strOrNull(json['start_time']),
        endTime: Json.strOrNull(json['end_time']),
        off: Json.boolOf(json['off']),
        timeOffReason: Json.strOrNull(json['time_off_reason']),
        jobs: Json.list(json['jobs']).map(AgendaJob.fromJson).toList(),
      );
}

class Agenda {
  const Agenda({
    required this.days,
    required this.unscheduled,
    required this.declaredAvailability,
  });

  final List<AgendaDay> days;

  /// Urgent jobs with no date. Shown as their own strip above the grid.
  final List<AgendaJob> unscheduled;

  /// False when the provider has never set hours — which is not the same as
  /// being unavailable, and the screen must say so.
  final bool declaredAvailability;

  int get jobCount =>
      days.fold(0, (sum, day) => sum + day.jobs.length) + unscheduled.length;

  factory Agenda.fromJson(Map<String, dynamic> json) => Agenda(
        days: Json.list(json['days']).map(AgendaDay.fromJson).toList(),
        unscheduled:
            Json.list(json['unscheduled']).map(AgendaJob.fromJson).toList(),
        declaredAvailability: Json.boolOf(json['declared_availability']),
      );
}

/// One weekday the provider works, and the hours they work it.
class WorkingDay {
  const WorkingDay({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  /// ISO-8601: 1 = Monday .. 7 = Sunday.
  final int dayOfWeek;

  /// Local wall-clock, `HH:mm`. Cameroon keeps one zone, so eight o'clock is
  /// eight o'clock whatever the server is doing.
  final String startTime;
  final String endTime;

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      };

  factory WorkingDay.fromJson(Map<String, dynamic> json) => WorkingDay(
        dayOfWeek: Json.intOf(json['day_of_week']),
        startTime: Json.str(json['start_time']),
        endTime: Json.str(json['end_time']),
      );
}

class TimeOff {
  const TimeOff({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  final String id;

  /// Both ends inclusive — "absent du 12 au 19" includes the 19th.
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;

  factory TimeOff.fromJson(Map<String, dynamic> json) => TimeOff(
        id: Json.str(json['id']),
        startDate: Json.dateTime(json['start_date']),
        endDate: Json.dateTime(json['end_date']),
        reason: Json.strOrNull(json['reason']),
      );
}

class Availability {
  const Availability({
    required this.days,
    required this.declared,
    required this.timeOff,
  });

  final List<WorkingDay> days;

  /// False when nothing has ever been declared. The provider still receives
  /// requests at any hour — declaring nothing is not declaring unavailable.
  final bool declared;

  final List<TimeOff> timeOff;

  /// Today's hours, or null when the artisan is not working today.
  ///
  /// Three cases, and the order matters. Declaring nothing is not declaring
  /// unavailable — an artisan who has never opened the availability screen
  /// still receives requests at any hour, so [declared] false answers null and
  /// the caller says nothing rather than saying "fermé". A recorded absence
  /// beats the weekly pattern: someone away this week still has Tuesday in
  /// their week, and it would be a lie to show it.
  WorkingDay? today([DateTime? now]) {
    if (!declared) return null;

    final date = now ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);

    for (final off in timeOff) {
      final from = DateTime(
          off.startDate.year, off.startDate.month, off.startDate.day);
      // Both ends inclusive, per TimeOff.
      final to = DateTime(off.endDate.year, off.endDate.month, off.endDate.day);
      if (!day.isBefore(from) && !day.isAfter(to)) return null;
    }

    for (final d in days) {
      if (d.dayOfWeek == date.weekday) return d;
    }
    return null;
  }

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
        days: Json.list(json['days']).map(WorkingDay.fromJson).toList(),
        declared: Json.boolOf(json['declared']),
        timeOff: Json.list(json['time_off']).map(TimeOff.fromJson).toList(),
      );
}

// --------------------------------------------------------------- metrics ---

/// A metric that is allowed to have no answer.
///
/// [value] and [unavailableBecause] are mutually exclusive and exactly one is
/// always set, so a widget can never render a number that was never computed.
///
/// [sampleSize] is present either way, and that is what makes a refusal legible:
/// "4 sur 10 enregistrées" reads as progress towards something, where a blank
/// tile reads as a fault.
class Metric<T> {
  const Metric({
    required this.value,
    required this.unavailableBecause,
    required this.sampleSize,
    required this.requiredSampleSize,
  });

  final T? value;
  final MetricUnavailability? unavailableBecause;
  final int sampleSize;

  /// The floor this metric is working towards; zero where it has none.
  final int requiredSampleSize;

  bool get hasValue => value != null;

  /// How many more observations are needed. Null unless the metric is short of
  /// a floor it can actually reach.
  int? get remaining =>
      unavailableBecause == MetricUnavailability.notEnoughData &&
              requiredSampleSize > sampleSize
          ? requiredSampleSize - sampleSize
          : null;

  static Metric<double> numberFromJson(Map<String, dynamic> json) => Metric(
        value: Json.dblOrNull(json['value']),
        unavailableBecause: json['unavailable_because'] == null
            ? null
            : Json.enumOf(json['unavailable_because'],
                MetricUnavailability.values, MetricUnavailability.notEnoughData),
        sampleSize: Json.intOf(json['sample_size']),
        requiredSampleSize: Json.intOf(json['required_sample_size']),
      );
}

/// How a provider is doing, as far as the data can honestly say.
///
/// Nothing here is a grade. The numbers arrive with the sample that produced
/// them and the provider draws their own conclusion.
class ProviderMetrics {
  const ProviderMetrics({
    required this.winRate,
    required this.responseHours,
    required this.onSiteHours,
    required this.averageRating,
    required this.repeatClientRate,
    required this.reliability,
    required this.punctuality,
    required this.utilisation,
    required this.completedJobs,
    required this.distinctClients,
  });

  final Metric<double> winRate;
  final Metric<double> responseHours;
  final Metric<double> onSiteHours;
  final Metric<double> averageRating;
  final Metric<double> repeatClientRate;
  final Metric<double> reliability;

  /// Declines until agendas have enough history to compare arrivals against.
  final Metric<double> punctuality;

  /// Declines: needs a jobs-per-day capacity nobody has decided.
  final Metric<double> utilisation;

  final int completedJobs;
  final int distinctClients;

  factory ProviderMetrics.fromJson(Map<String, dynamic> json) => ProviderMetrics(
        winRate: Metric.numberFromJson(Json.obj(json['win_rate'])),
        responseHours: Metric.numberFromJson(Json.obj(json['response_hours'])),
        onSiteHours: Metric.numberFromJson(Json.obj(json['on_site_hours'])),
        averageRating: Metric.numberFromJson(Json.obj(json['average_rating'])),
        repeatClientRate:
            Metric.numberFromJson(Json.obj(json['repeat_client_rate'])),
        reliability: Metric.numberFromJson(Json.obj(json['reliability'])),
        punctuality: Metric.numberFromJson(Json.obj(json['punctuality'])),
        utilisation: Metric.numberFromJson(Json.obj(json['utilisation'])),
        completedJobs: Json.intOf(json['completed_jobs']),
        distinctClients: Json.intOf(json['distinct_clients']),
      );
}

/// What a provider's finished missions were worth.
///
/// Not a balance — Panergo never holds the money. The client pays the artisan
/// directly, and this reports the value of work done.
class ProviderRevenue {
  const ProviderRevenue({
    required this.total,
    required this.currency,
    required this.completedCount,
    required this.period,
    required this.totalAllTime,
    required this.averagePerMission,
    required this.byCategory,
    required this.byNeighborhood,
    required this.missions,
  });

  final int total;
  final String currency;
  final int completedCount;
  final String period;

  /// Kept beside the period figure: a quiet month should not read as a failed
  /// career.
  final int totalAllTime;

  /// Null, never zero, when there are no missions. Zero is a claim about a
  /// provider; absence is the truth.
  final int? averagePerMission;

  /// The period's work split by trade, biggest first.
  final List<RevenueCategorySlice> byCategory;

  /// The same split by quartier, as mission counts — never francs.
  final List<RevenueZoneSlice> byNeighborhood;

  /// The finished missions themselves, newest first.
  final List<CompletedMission> missions;

  /// The biggest trade of the period, or null when there is nothing to rank.
  RevenueCategorySlice? get topCategory =>
      byCategory.isEmpty ? null : byCategory.first;

  factory ProviderRevenue.fromJson(Map<String, dynamic> json) => ProviderRevenue(
        total: Json.intOf(json['total_valeur_missions']),
        currency: Json.str(json['currency']),
        completedCount: Json.intOf(json['completed_bookings_count']),
        period: Json.str(json['period']),
        totalAllTime: Json.intOf(json['total_all_time']),
        averagePerMission: Json.intOrNull(json['average_per_mission']),
        byCategory: Json.list(json['by_category'])
            .map(RevenueCategorySlice.fromJson)
            .toList(growable: false),
        byNeighborhood: Json.list(json['by_neighborhood'])
            .map(RevenueZoneSlice.fromJson)
            .toList(growable: false),
        missions: Json.list(json['missions'])
            .map(CompletedMission.fromJson)
            .toList(growable: false),
      );
}

/// One trade's share of a revenue period.
class RevenueCategorySlice {
  const RevenueCategorySlice({
    required this.category,
    required this.missions,
    required this.total,
    required this.share,
  });

  final ServiceCategory category;
  final int missions;
  final int total;

  /// Percent of the period's value, rounded by the server so two screens cannot
  /// round it differently.
  final int share;

  factory RevenueCategorySlice.fromJson(Map<String, dynamic> json) =>
      RevenueCategorySlice(
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        missions: Json.intOf(json['missions']),
        total: Json.intOf(json['total']),
        share: Json.intOf(json['share']),
      );
}

/// One quartier's share of a revenue period, counted in missions.
class RevenueZoneSlice {
  const RevenueZoneSlice({
    required this.neighborhood,
    required this.missions,
    required this.share,
  });

  final String neighborhood;
  final int missions;
  final int share;

  factory RevenueZoneSlice.fromJson(Map<String, dynamic> json) =>
      RevenueZoneSlice(
        neighborhood: Json.str(json['neighborhood']),
        missions: Json.intOf(json['missions']),
        share: Json.intOf(json['share']),
      );
}

/// A finished mission as the revenue list shows it.
class CompletedMission {
  const CompletedMission({
    required this.completedAt,
    required this.category,
    required this.clientName,
    required this.price,
    required this.originalPrice,
  });

  final DateTime completedAt;
  final ServiceCategory category;
  final String clientName;

  /// What was actually paid.
  final int price;

  /// The opening quote, present only when it differs from [price]. Null means
  /// no negotiation happened — striking through an unchanged quote would invent
  /// one.
  final int? originalPrice;

  bool get wasNegotiated => originalPrice != null;

  factory CompletedMission.fromJson(Map<String, dynamic> json) =>
      CompletedMission(
        completedAt: Json.dateTime(json['completed_at']),
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        clientName: Json.str(json['client_name']),
        price: Json.intOf(json['price']),
        originalPrice: Json.intOrNull(json['original_price']),
      );
}

// ---------------------------------------------- missed work and clients ---

/// A client this provider has worked for.
class ClientSummary {
  const ClientSummary({
    required this.clientId,
    required this.name,
    required this.jobs,
    required this.lastHired,
    required this.totalValue,
    required this.repeat,
  });

  final String clientId;
  final String name;
  final int jobs;
  final DateTime? lastHired;
  final int totalValue;

  /// True once they have come back. Shown as a word, never as a colour alone.
  final bool repeat;

  factory ClientSummary.fromJson(Map<String, dynamic> json) => ClientSummary(
        clientId: Json.str(json['client_id']),
        name: Json.str(json['name']),
        jobs: Json.intOf(json['jobs']),
        lastHired: Json.dateTimeOrNull(json['last_hired']),
        totalValue: Json.intOf(json['total_value']),
        repeat: Json.boolOf(json['repeat']),
      );
}

/// An offer this provider lost, beside the price that won it.
///
/// Carries no identity for the winner — the insight is about the market, not
/// about a neighbour.
class LostOffer {
  const LostOffer({
    required this.category,
    required this.neighborhood,
    required this.yourPrice,
    required this.winningPrice,
    required this.requestedAt,
  });

  final ServiceCategory category;
  final String neighborhood;
  final int yourPrice;
  final int winningPrice;
  final DateTime requestedAt;

  /// Positive when they quoted above the price that won.
  int get gap => yourPrice - winningPrice;

  factory LostOffer.fromJson(Map<String, dynamic> json) => LostOffer(
        category: Json.enumOf(json['category'], ServiceCategory.values,
            ServiceCategory.plomberie),
        neighborhood: Json.str(json['neighborhood']),
        yourPrice: Json.intOf(json['your_price']),
        winningPrice: Json.intOf(json['winning_price']),
        requestedAt: Json.dateTime(json['requested_at']),
      );
}

class MissedOpportunities {
  const MissedOpportunities({
    required this.unansweredRequests,
    required this.windowDays,
    required this.lostOffers,
  });

  /// Requests they could have bid on and did not. Not "ignored" — nothing
  /// records who was actually notified.
  final int unansweredRequests;
  final int windowDays;
  final List<LostOffer> lostOffers;

  bool get isEmpty => unansweredRequests == 0 && lostOffers.isEmpty;

  factory MissedOpportunities.fromJson(Map<String, dynamic> json) =>
      MissedOpportunities(
        unansweredRequests: Json.intOf(json['unanswered_requests']),
        windowDays: Json.intOf(json['window_days']),
        lostOffers:
            Json.list(json['lost_offers']).map(LostOffer.fromJson).toList(),
      );
}

// ------------------------------------------------------------- quartiers ---

/// A quartier Panergo serves.
///
/// The list is curated server-side because routing compares quartiers as exact
/// strings — a typed spelling that differs by a space or an accent is a market
/// nobody else can reach.
class Quartier {
  const Quartier({required this.name, required this.city, required this.cityId});

  final String name;
  final String city;
  final String cityId;

  factory Quartier.fromJson(Map<String, dynamic> json) => Quartier(
        name: Json.str(json['name']),
        city: Json.str(json['city']),
        cityId: Json.str(json['city_id']),
      );
}

/// A country Panergo operates in.
class Country {
  const Country({required this.code, required this.name, required this.dialCode});

  final String code;
  final String name;

  /// Shown beside the country so the phone number makes sense.
  final String dialCode;

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        code: Json.str(json['code']),
        name: Json.str(json['name']),
        dialCode: Json.str(json['dial_code']),
      );
}

/// A town. The middle step of saying where you are.
class City {
  const City({required this.id, required this.name});

  final String id;
  final String name;

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: Json.str(json['id']),
        name: Json.str(json['name']),
      );
}


// ------------------------------------------------------- marks and replies ---

/// Whether this reader has marked a post useful, and how many have.
class PostMark {
  const PostMark({required this.marked, required this.count});

  final bool marked;
  final int count;

  factory PostMark.fromJson(Map<String, dynamic> json) => PostMark(
        marked: Json.boolOf(json['marked']),
        count: Json.intOf(json['count']),
      );
}

/// A reply on an artisan's post.
class PostReply {
  const PostReply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.authorPhotoUrl,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String body;
  final DateTime createdAt;

  factory PostReply.fromJson(Map<String, dynamic> json) => PostReply(
        id: Json.str(json['id']),
        authorId: Json.str(json['author_id']),
        authorName: Json.str(json['author_name']),
        authorPhotoUrl: Json.strOrNull(json['author_photo_url']),
        body: Json.str(json['body']),
        createdAt: Json.dateTime(json['created_at']),
      );
}


// -------------------------------------------------------------- the stream ---

/// Which board a post came from.
enum StreamKind { quartier, provider }

/// One post in the merged stream.
///
/// Both boards in one type because they are now one screen. The fields that
/// only one kind carries are nullable, and [kind] decides which card is drawn —
/// the app never guesses from whether a photo happens to be present.
class StreamPost {
  const StreamPost({
    required this.id,
    required this.kind,
    required this.authorId,
    required this.authorName,
    required this.neighborhood,
    required this.replyCount,
    required this.markCount,
    required this.marked,
    required this.createdAt,
    this.authorPhotoUrl,
    this.body,
    this.photoUrl,
    this.postKind,
    this.category,
    this.providerId,
  });

  final String id;
  final StreamKind kind;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String neighborhood;

  /// The question on a quartier post, the caption on a réalisation.
  final String? body;

  /// Only a réalisation has one.
  final String? photoUrl;

  /// Only a quartier post has one.
  final QuartierPostKind? postKind;

  /// The artisan's trade, on a réalisation.
  final ServiceCategory? category;

  /// The provider row behind a réalisation.
  ///
  /// Distinct from [authorId], which is a user id: naming a request's origin
  /// needs the provider, and passing the user id would match nothing.
  final String? providerId;

  final int replyCount;
  final int markCount;
  final bool marked;
  final DateTime createdAt;

  bool get isRealisation => kind == StreamKind.provider;

  /// What the mark endpoint calls this kind.
  String get markKind => kind == StreamKind.provider ? 'PROVIDER' : 'QUARTIER';

  factory StreamPost.fromJson(Map<String, dynamic> json) {
    final kind = Json.str(json['kind']) == 'PROVIDER'
        ? StreamKind.provider
        : StreamKind.quartier;
    return StreamPost(
      id: Json.str(json['id']),
      kind: kind,
      authorId: Json.str(json['author_id']),
      authorName: Json.str(json['author_name']),
      authorPhotoUrl: json['author_photo_url'] as String?,
      neighborhood: Json.str(json['neighborhood']),
      body: json['body'] as String?,
      photoUrl: json['photo_url'] as String?,
      postKind: kind == StreamKind.quartier
          ? Json.enumOf(json['post_kind'], QuartierPostKind.values,
              QuartierPostKind.question)
          : null,
      category: kind == StreamKind.provider && json['category'] != null
          ? Json.enumOf(json['category'], ServiceCategory.values,
              ServiceCategory.values.first)
          : null,
      providerId: json['provider_id'] as String?,
      replyCount: Json.intOf(json['reply_count']),
      markCount: Json.intOf(json['mark_count']),
      marked: Json.boolOf(json['marked']),
      createdAt: Json.dateTime(json['created_at']),
    );
  }
}

/// A page of the merged stream, with the scope it was read under.
class StreamPage {
  const StreamPage({
    required this.content,
    required this.page,
    required this.totalPages,
    required this.totalPosts,
    required this.neighborhood,
    required this.onlyMine,
  });

  final List<StreamPost> content;
  final int page;
  final int totalPages;
  final int totalPosts;
  final String neighborhood;
  final bool onlyMine;

  factory StreamPage.fromJson(Map<String, dynamic> json) => StreamPage(
        content: (json['content'] as List<dynamic>? ?? const [])
            .map((e) => StreamPost.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: Json.intOf(json['page']),
        totalPages: Json.intOf(json['total_pages']),
        totalPosts: Json.intOf(json['total_posts']),
        neighborhood: Json.str(json['neighborhood']),
        onlyMine: Json.boolOf(json['only_mine']),
      );
}


// ---------------------------------------------------------- the directory ---

/// A kind of business — pharmacy, garage, hardware shop.
///
/// A class rather than an enum, unlike [ServiceCategory]: this list comes from
/// the server and grows sideways for years. The next person to read this will
/// want to "fix" it into a `WireEnum`; that would put a release between the
/// business and every new category.
class BusinessCategory {
  const BusinessCategory({
    required this.code,
    required this.label,
    required this.iconName,
    required this.totalCount,
    required this.nearCount,
  });

  final String code;
  final String label;

  /// How many published businesses sit behind this category, and how many of
  /// those are in the reader's own quartier. Most categories are empty for
  /// now, and saying so is what stops somebody tapping into a blank list.
  final int totalCount;
  final int nearCount;

  /// A Material Symbols name chosen server-side, so it may be one this build
  /// has never heard of. [MaterialSymbol] falls back rather than failing.
  final String iconName;

  factory BusinessCategory.fromJson(Map<String, dynamic> json) => BusinessCategory(
        code: Json.str(json['code']),
        label: Json.str(json['label']),
        iconName: Json.str(json['icon_name']),
        totalCount: Json.intOf(json['total_count']),
        nearCount: Json.intOf(json['near_count']),
      );
}

/// Where a listing stands with review.
enum BusinessStatus implements WireEnum {
  pending('PENDING', 'En attente'),
  published('PUBLISHED', 'Publié'),
  rejected('REJECTED', 'Refusé'),
  suspended('SUSPENDED', 'Suspendu');

  const BusinessStatus(this.wire, this.label);

  @override
  final String wire;

  final String label;
}

/// Where a business already lives online.
///
/// Facebook leads deliberately: in this market a great many shops keep an
/// active page and no website at all, and for those the page is the shopfront.
enum BusinessLinkKind implements WireEnum {
  facebook('FACEBOOK', 'Facebook', 'public', 'facebook.com/votre-page'),
  whatsapp('WHATSAPP', 'WhatsApp', 'forum', 'wa.me/237…'),
  instagram('INSTAGRAM', 'Instagram', 'photo_camera', 'instagram.com/votre-compte'),
  tiktok('TIKTOK', 'TikTok', 'play_circle', 'tiktok.com/@votre-compte'),
  website('WEBSITE', 'Site web', 'language', 'votre-site.cm'),
  autre('AUTRE', 'Autre', 'add_link', 'adresse de la page');

  const BusinessLinkKind(this.wire, this.label, this.icon, this.placeholder);

  @override
  final String wire;

  final String label;
  final String icon;

  /// What the field shows — never with a scheme, since the server adds one.
  final String placeholder;
}

/// One link on a listing.
class BusinessLink {
  const BusinessLink({required this.kind, required this.url});

  final BusinessLinkKind kind;
  final String url;

  factory BusinessLink.fromJson(Map<String, dynamic> json) => BusinessLink(
        kind: Json.enumOf(json['kind'], BusinessLinkKind.values,
            BusinessLinkKind.autre),
        url: Json.str(json['url']),
      );
}

/// One opening interval. [dayOfWeek] is ISO — 1 is Monday.
class BusinessHours {
  const BusinessHours({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
  });

  final int dayOfWeek;
  final String opensAt;
  final String closesAt;

  factory BusinessHours.fromJson(Map<String, dynamic> json) => BusinessHours(
        dayOfWeek: Json.intOf(json['day_of_week']),
        opensAt: Json.str(json['opens_at']),
        closesAt: Json.str(json['closes_at']),
      );
}

/// A business in a list.
class BusinessSummary {
  const BusinessSummary({
    required this.id,
    required this.name,
    required this.categoryCode,
    required this.categoryLabel,
    required this.categoryIconName,
    required this.neighborhood,
    required this.openNow,
    required this.statusLabel,
    required this.statusMeta,
    this.addressLine,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String categoryCode;
  final String categoryLabel;
  final String categoryIconName;
  final String neighborhood;

  /// The fact a reader is actually after. Does the work a rating does on a
  /// provider card.
  final bool openNow;

  /// « Ouvert » / « Fermé » / « Horaires non précisés », and the line that says
  /// what happens next. Both come from the server so two screens can never
  /// compute a different answer from the same week.
  final String statusLabel;
  final String statusMeta;
  final String? addressLine;

  final String? photoUrl;

  factory BusinessSummary.fromJson(Map<String, dynamic> json) => BusinessSummary(
        id: Json.str(json['id']),
        name: Json.str(json['name']),
        categoryCode: Json.str(json['category_code']),
        categoryLabel: Json.str(json['category_label']),
        categoryIconName: Json.str(json['category_icon_name']),
        neighborhood: Json.str(json['neighborhood']),
        openNow: Json.boolOf(json['open_now']),
      statusLabel: Json.str(json['status_label']),
      statusMeta: Json.str(json['status_meta']),
      addressLine: Json.strOrNull(json['address_line']),
        photoUrl: Json.strOrNull(json['photo_url']),
      );
}

/// One line of a price list.
class BusinessProduct {
  const BusinessProduct({
    required this.id,
    required this.name,
    this.slug,
    required this.available,
    this.description,
    this.photoUrl,
    this.price,
    this.unit,
    this.groupId,
    this.groupLabel,
  });

  final String id;

  /// Its address within the shop, for a shared link.
  final String? slug;

  final String name;
  final String? description;
  final String? photoUrl;

  /// Whole CFA francs. Null means « prix sur demande » — not free, and not
  /// zero, which would be a different claim.
  final int? price;

  final String? unit;
  final bool available;
  final String? groupId;
  final String? groupLabel;

  factory BusinessProduct.fromJson(Map<String, dynamic> json) => BusinessProduct(
        id: Json.str(json['id']),
        slug: Json.strOrNull(json['slug']),
        name: Json.str(json['name']),
        description: Json.strOrNull(json['description']),
        photoUrl: Json.strOrNull(json['photo_url']),
        price: json['price'] == null ? null : Json.intOf(json['price']),
        unit: Json.strOrNull(json['unit']),
        available: Json.boolOf(json['available']),
        groupId: Json.strOrNull(json['group_id']),
        groupLabel: Json.strOrNull(json['group_label']),
      );
}

/// The whole listing.
class BusinessDetail {
  const BusinessDetail({
    required this.id,
    required this.name,
    this.slug,
    required this.categoryCode,
    required this.categoryLabel,
    required this.categoryIconName,
    required this.neighborhood,
    required this.status,
    required this.openNow,
    required this.statusLabel,
    required this.statusMeta,
    required this.canMessage,
    required this.services,
    required this.links,
    required this.hours,
    this.description,
    this.addressLine,
    this.phoneNumber,
    this.whatsappNumber,
    this.photoUrl,
    this.bannerUrl,
    this.rejectionReason,
  });

  final String id;

  /// Its address in a shared link — `panergo.cm/b/{slug}`.
  final String? slug;

  final String name;
  final String categoryCode;
  final String categoryLabel;
  final String categoryIconName;
  final String neighborhood;
  final String? description;
  final String? addressLine;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? photoUrl;

  /// A wide photograph of the shopfront — a different crop from [photoUrl],
  /// which is the identity shown small beside the name.
  final String? bannerUrl;

  final BusinessStatus status;
  final String? rejectionReason;
  final bool openNow;
  final String statusLabel;
  final String statusMeta;

  /// Whether anyone is there to answer. A listing nobody has claimed has no
  /// owner, and offering to message it would reach nobody.
  final bool canMessage;

  final List<String> services;
  final List<BusinessLink> links;
  final List<BusinessHours> hours;

  bool get isPublished => status == BusinessStatus.published;

  factory BusinessDetail.fromJson(Map<String, dynamic> json) => BusinessDetail(
        id: Json.str(json['id']),
        slug: Json.strOrNull(json['slug']),
        name: Json.str(json['name']),
        categoryCode: Json.str(json['category_code']),
        categoryLabel: Json.str(json['category_label']),
        categoryIconName: Json.str(json['category_icon_name']),
        neighborhood: Json.str(json['neighborhood']),
        description: Json.strOrNull(json['description']),
        addressLine: Json.strOrNull(json['address_line']),
        phoneNumber: Json.strOrNull(json['phone_number']),
        whatsappNumber: Json.strOrNull(json['whatsapp_number']),
        photoUrl: Json.strOrNull(json['photo_url']),
        bannerUrl: Json.strOrNull(json['banner_url']),
        status: Json.enumOf(json['status'], BusinessStatus.values,
            BusinessStatus.pending),
        rejectionReason: Json.strOrNull(json['rejection_reason']),
        openNow: Json.boolOf(json['open_now']),
      statusLabel: Json.str(json['status_label']),
      statusMeta: Json.str(json['status_meta']),
        canMessage: Json.boolOf(json['can_message']),
        services: Json.strings(json['services']),
        links: (json['links'] as List<dynamic>? ?? const [])
            .map((e) => BusinessLink.fromJson(e as Map<String, dynamic>))
            .toList(),
        hours: (json['hours'] as List<dynamic>? ?? const [])
            .map((e) => BusinessHours.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A page of the directory.
class BusinessPage {
  const BusinessPage({
    required this.content,
    required this.page,
    required this.totalPages,
    required this.totalBusinesses,
  });

  final List<BusinessSummary> content;
  final int page;
  final int totalPages;
  final int totalBusinesses;

  factory BusinessPage.fromJson(Map<String, dynamic> json) => BusinessPage(
        content: (json['content'] as List<dynamic>? ?? const [])
            .map((e) => BusinessSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: Json.intOf(json['page']),
        totalPages: Json.intOf(json['total_pages']),
        totalBusinesses: Json.intOf(json['total_businesses']),
      );
}


// ------------------------------------------------------------ conversations ---

/// What a thread is about.
enum ConversationKind implements WireEnum {
  booking('BOOKING', 'Mission'),
  business('BUSINESS', 'Commerce'),
  group('GROUP', 'Groupe');

  const ConversationKind(this.wire, this.label);

  @override
  final String wire;

  final String label;
}

/// A row in the inbox.
///
/// The peer is whoever is not you, which differs per reader: the same thread is
/// "Jean-Pierre" to a client and "Murielle" to the artisan. The server resolves
/// that rather than shipping both sides and making the app choose.
class Conversation {
  const Conversation({
    required this.conversationId,
    required this.kind,
    required this.peerName,
    this.peerPhotoUrl,
    this.subtitle,
    this.bookingId,
    this.businessId,
    this.groupId,
    this.iconName,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String conversationId;
  final ConversationKind kind;
  final String peerName;
  final String? peerPhotoUrl;

  /// The trade for a mission, the category for a shop.
  final String? subtitle;

  final String? bookingId;
  final String? businessId;
  final String? groupId;

  /// A Material Symbols name for a group, which has no photograph to show.
  final String? iconName;

  /// The last thing said, as one line, already prefixed by the server —
  /// « Vous : » for your own, a first name in a group.
  ///
  /// Null in a thread nobody has spoken in, where the row shows the subject
  /// instead.
  final String? lastMessage;

  final DateTime? lastMessageAt;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        conversationId: Json.str(json['conversation_id']),
        kind: Json.enumOf(json['kind'], ConversationKind.values,
            ConversationKind.booking),
        peerName: Json.str(json['peer_name']),
        peerPhotoUrl: Json.strOrNull(json['peer_photo_url']),
        subtitle: Json.strOrNull(json['subtitle']),
        bookingId: Json.strOrNull(json['booking_id']),
        businessId: Json.strOrNull(json['business_id']),
        groupId: Json.strOrNull(json['group_id']),
        iconName: Json.strOrNull(json['icon_name']),
        lastMessage: Json.strOrNull(json['last_message']),
        lastMessageAt: json['last_message_at'] == null
            ? null
            : Json.dateTime(json['last_message_at']),
      );
}

// ----------------------------------------------------------------- groups ---

/// A group, and the caller's own standing in it.
///
/// [joined], [requested] and [owner] come from the server rather than being
/// worked out here: the button is the whole point of the row, and deriving it
/// client-side would mean a query per row to answer.
class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.iconName,
    required this.memberCount,
    required this.joined,
    required this.requested,
    required this.owner,
    required this.pendingCount,
    this.description,
    this.neighborhood,
    this.conversationId,
  });

  final String id;
  final String name;
  final String? description;
  final String? neighborhood;
  final String iconName;
  final int memberCount;

  final bool joined;
  final bool requested;
  final bool owner;

  /// Requests waiting on you, when you own it.
  final int pendingCount;

  /// Only a member gets one — there is nothing to open otherwise.
  final String? conversationId;

  factory GroupSummary.fromJson(Map<String, dynamic> json) => GroupSummary(
        id: Json.str(json['id']),
        name: Json.str(json['name']),
        description: Json.strOrNull(json['description']),
        neighborhood: Json.strOrNull(json['neighborhood']),
        iconName: Json.str(json['icon_name']),
        memberCount: Json.intOf(json['member_count']),
        joined: Json.boolOf(json['joined']),
        requested: Json.boolOf(json['requested']),
        owner: Json.boolOf(json['owner']),
        pendingCount: Json.intOf(json['pending_count']),
        conversationId: Json.strOrNull(json['conversation_id']),
      );
}

/// Somebody waiting in an owner's queue, or already seated.
class GroupPerson {
  const GroupPerson({
    required this.id,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.userPhotoUrl,
    this.userNeighborhood,
    this.message,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? userNeighborhood;

  /// Their note when asking; « Créateur » on a roster row.
  final String? message;

  final DateTime createdAt;

  factory GroupPerson.fromJson(Map<String, dynamic> json) => GroupPerson(
        id: Json.str(json['id']),
        userId: Json.str(json['user_id']),
        userName: Json.str(json['user_name']),
        userPhotoUrl: Json.strOrNull(json['user_photo_url']),
        userNeighborhood: Json.strOrNull(json['user_neighborhood']),
        message: Json.strOrNull(json['message']),
        createdAt: Json.dateTime(json['created_at']),
      );
}

// ------------------------------------------------------------ relayed search ---

/// What became of a question the server routed.
///
/// A tagged union rather than one record of nullables: a tender and a stock
/// question are answered on different screens, and [kind] says which to open
/// without inspecting six fields for nulls.
class ReferralOutcome {
  const ReferralOutcome({
    required this.kind,
    required this.reached,
    this.requestId,
    this.inquiryId,
    this.scope,
    this.options = const [],
  });

  final ReferralKind kind;

  /// How many artisans or shops it went to.
  final int reached;

  /// The tender, on [ReferralKind.trade].
  final String? requestId;

  /// The stock question, on [ReferralKind.shop].
  final String? inquiryId;

  /// Whether the quartier was enough, on [ReferralKind.shop].
  final InquiryScope? scope;

  /// On [ReferralKind.ambiguous], the two markets and what each would reach.
  final List<ReferralOption> options;

  factory ReferralOutcome.fromJson(Map<String, dynamic> json) => ReferralOutcome(
        kind: ReferralKind.fromWire(Json.strOrNull(json['kind'])),
        reached: Json.intOf(json['reached']),
        requestId: Json.strOrNull(json['request_id']),
        inquiryId: Json.strOrNull(json['inquiry_id']),
        scope: json['scope'] == null
            ? null
            : InquiryScope.fromWire(Json.strOrNull(json['scope'])),
        options:
            Json.list(json['options']).map(ReferralOption.fromJson).toList(),
      );
}

/// One market an ambiguous question could go to.
class ReferralOption {
  const ReferralOption({
    required this.target,
    required this.label,
    required this.wouldReach,
  });

  final ReferralTarget target;

  /// The server's own wording for the button.
  final String label;
  final int wouldReach;

  factory ReferralOption.fromJson(Map<String, dynamic> json) => ReferralOption(
        target: Json.strOrNull(json['target']) == 'TRADE'
            ? ReferralTarget.trade
            : ReferralTarget.shop,
        label: Json.str(json['label']),
        wouldReach: Json.intOf(json['would_reach']),
      );
}

/// One line in « mes demandes » for a relayed question.
class InquirySummary {
  const InquirySummary({
    required this.inquiryId,
    required this.audience,
    this.convertedRequestId,
    required this.text,
    required this.neighborhood,
    required this.scope,
    required this.status,
    required this.recipientCount,
    required this.answered,
    required this.haveIt,
    required this.expiresAt,
    required this.expired,
    required this.createdAt,
    this.categoryLabel,
  });

  final String inquiryId;
  /// Who was asked. The client reads its whole vocabulary from this — « en a »
  /// against « peut », « commerces » against the trade's own word.
  final InquiryAudienceKind audience;

  /// The tender this question became, when somebody said they could.
  ///
  /// Null for every other closed question. « Devenue une demande » and
  /// « 1 boutique en avait » are different endings, and the status cannot tell
  /// them apart.
  final String? convertedRequestId;

  /// Whether this question ended by becoming a demande.
  bool get becameRequest => convertedRequestId != null;

  final String text;
  final String? categoryLabel;
  final String neighborhood;
  final InquiryScope scope;
  final InquiryStatus status;
  final int recipientCount;
  final int answered;

  /// How many said yes. What the row's status line reads from.
  final int haveIt;

  final DateTime expiresAt;
  final bool expired;
  final DateTime createdAt;

  /// Still able to receive answers.
  bool get live => !expired && status == InquiryStatus.open;

  factory InquirySummary.fromJson(Map<String, dynamic> json) => InquirySummary(
        inquiryId: Json.str(json['inquiry_id']),
        audience: InquiryAudienceKind.fromWire(Json.strOrNull(json['audience'])),
        convertedRequestId: Json.strOrNull(json['converted_request_id']),
        text: Json.str(json['text']),
        categoryLabel: Json.strOrNull(json['category_label']),
        neighborhood: Json.str(json['neighborhood']),
        scope: InquiryScope.fromWire(Json.strOrNull(json['scope'])),
        status: InquiryStatus.fromWire(Json.strOrNull(json['status'])),
        recipientCount: Json.intOf(json['recipient_count']),
        answered: Json.intOf(json['answered']),
        haveIt: Json.intOf(json['have_it']),
        expiresAt: Json.dateTime(json['expires_at']),
        expired: json['expired'] == true,
        createdAt: Json.dateTime(json['created_at']),
      );
}

/// A relayed question and what came back.
class InquiryDetail {
  const InquiryDetail({
    required this.inquiryId,
    required this.audience,
    required this.text,
    required this.neighborhood,
    required this.scope,
    required this.status,
    required this.recipientCount,
    required this.answered,
    required this.haveIt,
    required this.doNotHaveIt,
    required this.silent,
    required this.expiresAt,
    required this.expired,
    required this.createdAt,
    required this.replies,
    this.categoryCode,
    this.categoryLabel,
    this.photoUrl,
  });

  final String inquiryId;
  /// Who was asked. The client reads its whole vocabulary from this — « en a »
  /// against « peut », « commerces » against the trade's own word.
  final InquiryAudienceKind audience;

  final String text;
  final String? categoryCode;
  final String? categoryLabel;
  final String neighborhood;
  final String? photoUrl;
  final InquiryScope scope;
  final InquiryStatus status;

  /// How many shops were asked.
  final int recipientCount;
  final int answered;

  /// How many said yes. The headline is built from this — design 5D gives the
  /// result, not the response rate.
  final int haveIt;

  /// How many said no. Folded into a counted line rather than given a card each.
  final int doNotHaveIt;

  /// Asked but never answered. Reported apart from a refusal on purpose: five
  /// silent shops « ne veut pas dire qu'elles n'en ont pas », and one combined
  /// number would have the platform assert a no nobody said.
  final int silent;

  final DateTime expiresAt;
  final bool expired;
  final DateTime createdAt;
  final List<InquiryReply> replies;

  bool get live => !expired && status == InquiryStatus.open;

  /// Answers worth acting on, which is what the list shows unfolded.
  List<InquiryReply> get haveItReplies =>
      replies.where((r) => r.hasItem).toList();

  /// « En ont · avec un prix » — sorted cheapest first.
  ///
  /// Split from the priceless ones because the design gives them separate
  /// headings, and the reason is comparability: a list that runs « 4 500 », then
  /// « prix à demander », then « 5 200 » reads as though the middle one were
  /// free or cheapest.
  List<InquiryReply> get pricedReplies {
    final priced = replies.where((r) => r.hasItem && r.price != null).toList()
      ..sort((a, b) => a.price!.compareTo(b.price!));
    return priced;
  }

  /// « Peuvent » — artisans who said yes, soonest first.
  ///
  /// Ordered by nothing but arrival: an availability is free text (« mardi
  /// matin », « sous 2 semaines ») and sorting it would mean parsing dates out
  /// of prose and getting them wrong.
  List<InquiryReply> get canDoReplies =>
      replies.where((r) => r.canDo).toList(growable: false);

  /// « Ne peut pas » — a real answer too. It saved a pointless demande.
  List<InquiryReply> get cannotReplies =>
      replies.where((r) => !r.canDo).toList(growable: false);

  /// « En ont · prix non donné » — a real answer, and not a cheap one.
  List<InquiryReply> get unpricedReplies =>
      replies.where((r) => r.hasItem && r.price == null).toList();

  /// Refusals, behind the folded line that counts them.
  List<InquiryReply> get refusals => replies.where((r) => !r.hasItem).toList();

  /// Nothing has come back yet, which is a wait rather than a result.
  bool get awaiting => replies.isEmpty;

  factory InquiryDetail.fromJson(Map<String, dynamic> json) => InquiryDetail(
        inquiryId: Json.str(json['inquiry_id']),
        audience: InquiryAudienceKind.fromWire(Json.strOrNull(json['audience'])),
        text: Json.str(json['text']),
        categoryCode: Json.strOrNull(json['category_code']),
        categoryLabel: Json.strOrNull(json['category_label']),
        neighborhood: Json.str(json['neighborhood']),
        photoUrl: Json.strOrNull(json['photo_url']),
        scope: InquiryScope.fromWire(Json.strOrNull(json['scope'])),
        status: InquiryStatus.fromWire(Json.strOrNull(json['status'])),
        recipientCount: Json.intOf(json['recipient_count']),
        answered: Json.intOf(json['answered']),
        haveIt: Json.intOf(json['have_it']),
        doNotHaveIt: Json.intOf(json['do_not_have_it']),
        silent: Json.intOf(json['silent']),
        expiresAt: Json.dateTime(json['expires_at']),
        expired: json['expired'] == true,
        createdAt: Json.dateTime(json['created_at']),
        replies:
            Json.list(json['replies']).map(InquiryReply.fromJson).toList(),
      );
}

/// One shop's answer.
class InquiryReply {
  const InquiryReply({
    required this.replyId,
    required this.businessId,
    required this.businessName,
    required this.neighborhood,
    required this.hasItem,
    required this.openNow,
    required this.stale,
    required this.repliedAt,
    this.businessSlug,
    this.photoUrl,
    this.phoneNumber,
    this.whatsappNumber,
    this.price,
    this.unit,
    this.availability,
    this.note,
    this.previous,
  });

  final String replyId;
  final String businessId;
  final String businessName;
  final String? businessSlug;
  final String? photoUrl;
  final String neighborhood;
  final String? phoneNumber;
  final String? whatsappNumber;
  final bool hasItem;

  /// « Peut » / « Ne peut pas ». The same stored yes/no as [hasItem], named for
  /// what it means when the answer came from a person rather than a shelf.
  bool get canDo => hasItem;

  final int? price;
  final String? unit;

  /// « Mardi matin », « Sous 2 semaines » — when an artisan says they can.
  ///
  /// The largest thing on an artisan's card, where a shop's card is largest on
  /// price. Null for a shop, and for an artisan who said no.
  final String? availability;
  final String? note;
  final bool openNow;

  /// Given before today. Design 5D writes « En avait hier » rather than « En
  /// a », because a stock answer keeps its wording long after it stopped being
  /// true, and somebody setting out on yesterday's word should be told so.
  final bool stale;

  final DateTime repliedAt;

  /// The answer this one replaced. Design 6B renders it struck through with its
  /// hour: somebody already crossing town needs to know what changed and when.
  final PreviousAnswer? previous;

  bool get corrected => previous != null;

  factory InquiryReply.fromJson(Map<String, dynamic> json) => InquiryReply(
        replyId: Json.str(json['reply_id']),
        businessId: Json.str(json['business_id']),
        businessName: Json.str(json['business_name']),
        businessSlug: Json.strOrNull(json['business_slug']),
        photoUrl: Json.strOrNull(json['photo_url']),
        neighborhood: Json.str(json['neighborhood']),
        phoneNumber: Json.strOrNull(json['phone_number']),
        whatsappNumber: Json.strOrNull(json['whatsapp_number']),
        hasItem: json['has_item'] == true,
        price: Json.intOrNull(json['price']),
        unit: Json.strOrNull(json['unit']),
        availability: Json.strOrNull(json['availability']),
        note: Json.strOrNull(json['note']),
        openNow: json['open_now'] == true,
        stale: json['stale'] == true,
        repliedAt: Json.dateTime(json['replied_at']),
        previous: json['previous'] == null
            ? null
            : PreviousAnswer.fromJson(json['previous'] as Map<String, dynamic>),
      );
}

/// A superseded answer, kept so the screen can say what changed.
class PreviousAnswer {
  const PreviousAnswer({
    required this.hasItem,
    required this.at,
    this.price,
    this.unit,
  });

  final bool hasItem;
  final int? price;
  final String? unit;
  final DateTime at;

  factory PreviousAnswer.fromJson(Map<String, dynamic> json) => PreviousAnswer(
        hasItem: json['has_item'] == true,
        price: Json.intOrNull(json['price']),
        unit: Json.strOrNull(json['unit']),
        at: Json.dateTime(json['at']),
      );
}

/// A question worth asking again, prepared but not sent.
class AskAgainDraft {
  const AskAgainDraft({
    required this.text,
    required this.neighborhood,
    required this.wouldReach,
    required this.wouldWiden,
    this.suggestedCategoryCode,
    this.suggestedCategoryLabel,
  });

  final String text;
  final String neighborhood;

  /// Recomputed rather than carried over: shops open, close and opt out between
  /// one asking and the next.
  final int wouldReach;
  final bool wouldWiden;
  final String? suggestedCategoryCode;
  final String? suggestedCategoryLabel;

  factory AskAgainDraft.fromJson(Map<String, dynamic> json) => AskAgainDraft(
        text: Json.str(json['text']),
        neighborhood: Json.str(json['neighborhood']),
        wouldReach: Json.intOf(json['would_reach']),
        wouldWiden: json['would_widen'] == true,
        suggestedCategoryCode: Json.strOrNull(json['suggested_category_code']),
        suggestedCategoryLabel: Json.strOrNull(json['suggested_category_label']),
      );
}

/// A question waiting in a shop's own list.
class ShopInboxItem {
  const ShopInboxItem({
    required this.inquiryId,
    required this.text,
    required this.neighborhood,
    required this.answered,
    required this.expiresAt,
    required this.askedAt,
    this.categoryLabel,
    this.photoUrl,
    this.hasItem,
    this.price,
    this.unit,
    this.suggestedUnit,
  });

  final String inquiryId;
  final String text;
  final String? categoryLabel;
  final String neighborhood;
  final String? photoUrl;

  /// Unanswered questions take an ink border in design 7D; answered ones show
  /// what was said and correct with one tap.
  final bool answered;

  final bool? hasItem;
  final int? price;
  final String? unit;

  /// The unit from this shop's own catalogue when the question names something
  /// it stocks. Design 7C pre-fills from it rather than making somebody type
  /// « le sac » again for an article already priced by the sack.
  final String? suggestedUnit;

  final DateTime expiresAt;
  final DateTime askedAt;

  factory ShopInboxItem.fromJson(Map<String, dynamic> json) => ShopInboxItem(
        inquiryId: Json.str(json['inquiry_id']),
        text: Json.str(json['text']),
        categoryLabel: Json.strOrNull(json['category_label']),
        neighborhood: Json.str(json['neighborhood']),
        photoUrl: Json.strOrNull(json['photo_url']),
        answered: json['answered'] == true,
        hasItem: json['has_item'] as bool?,
        price: Json.intOrNull(json['price']),
        unit: Json.strOrNull(json['unit']),
        suggestedUnit: Json.strOrNull(json['suggested_unit']),
        expiresAt: Json.dateTime(json['expires_at']),
        askedAt: Json.dateTime(json['asked_at']),
      );
}

/// Whether a shop wants to be asked, and how much.
class InquirySettings {
  const InquirySettings({
    required this.acceptsInquiries,
    required this.ownQuartierOnly,
    required this.recentWeeklyRate,
    this.dailyCap,
    this.pausedUntil,
  });

  final bool acceptsInquiries;
  final bool ownQuartierOnly;

  /// Null means no ceiling.
  final int? dailyCap;

  /// Null when not paused.
  final DateTime? pausedUntil;

  /// What the questions actually cost lately. Design 7E puts it under the main
  /// switch — « environ 4 par semaine en ce moment » — because a shopkeeper
  /// judging whether this is too much should be told the real figure.
  final int recentWeeklyRate;

  bool get paused =>
      pausedUntil != null && pausedUntil!.isAfter(DateTime.now());

  factory InquirySettings.fromJson(Map<String, dynamic> json) => InquirySettings(
        acceptsInquiries: json['accepts_inquiries'] == true,
        ownQuartierOnly: json['own_quartier_only'] == true,
        dailyCap: Json.intOrNull(json['daily_cap']),
        pausedUntil: Json.dateTimeOrNull(json['paused_until']),
        recentWeeklyRate: Json.intOf(json['recent_weekly_rate']),
      );
}
