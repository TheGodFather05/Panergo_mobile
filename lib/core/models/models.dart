import '../network/json.dart';
import 'enums.dart';

/// The signed-in person.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.neighborhood,
    required this.role,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String neighborhood;
  final UserRole role;

  bool get isProvider => role == UserRole.provider;

  /// First login creates the account with the phone number as the name and no
  /// quartier, so the app knows to ask for a real profile before continuing.
  bool get needsProfileCompletion =>
      neighborhood.trim().isEmpty || name == phoneNumber;

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
        role: Json.enumOf(json['role'], UserRole.values, UserRole.user),
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
    required this.category,
    required this.neighborhood,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final int score;
  final String? comment;
  final ServiceCategory category;
  final String neighborhood;
  final DateTime createdAt;

  factory ProviderRating.fromJson(Map<String, dynamic> json) => ProviderRating(
        id: Json.str(json['rating_id']),
        authorName: Json.str(json['author_name']),
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
    required this.bookingId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.photoUrl,
    required this.sentAt,
  });

  final String id;
  final String bookingId;
  final String senderId;
  final UserRole senderRole;
  final String? content;
  final String? photoUrl;
  final DateTime sentAt;

  bool get isPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: Json.str(json['message_id']),
        bookingId: Json.str(json['booking_id']),
        senderId: Json.str(json['sender_id']),
        senderRole:
            Json.enumOf(json['sender_role'], UserRole.values, UserRole.user),
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
    required this.body,
    required this.replyCount,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String neighborhood;
  final QuartierPostKind kind;
  final String body;
  final int replyCount;
  final DateTime createdAt;

  factory QuartierPost.fromJson(Map<String, dynamic> json) => QuartierPost(
        id: Json.str(json['post_id']),
        authorId: Json.str(json['author_id']),
        authorName: Json.str(json['author_name']),
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
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory QuartierReply.fromJson(Map<String, dynamic> json) => QuartierReply(
        id: Json.str(json['reply_id']),
        authorId: Json.str(json['author_id']),
        authorName: Json.str(json['author_name']),
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
        dataMissing: (json['data_missing'] as List? ?? const [])
            .map((e) => '$e')
            .toList(),
      );
}

/// The assistant's answer: an optional observation plus grounded results.
class AssistantAnswer {
  const AssistantAnswer({required this.observation, required this.providers});

  /// Null when the assistant is disabled server-side or the model call failed.
  final String? observation;
  final List<AssistantResult> providers;

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) => AssistantAnswer(
        observation: Json.strOrNull(json['observation']),
        providers:
            Json.list(json['providers']).map(AssistantResult.fromJson).toList(),
      );
}
