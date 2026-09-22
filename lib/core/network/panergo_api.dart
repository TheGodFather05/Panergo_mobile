import 'dart:io';

import '../models/enums.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'json.dart';

/// Every Panergo endpoint, in one place.
///
/// Kept as a single surface rather than a repository per feature: the API is
/// small, and having the whole contract visible together makes a mismatch with
/// the backend easy to spot.
class PanergoApi {
  const PanergoApi(this._client);

  final ApiClient _client;

  // ---------------------------------------------------------------- auth ---

  /// Sends a 6-digit code. In this deployment it is written to the server log
  /// rather than sent by SMS.
  Future<void> requestOtp(String phoneNumber) async {
    await _client.post<dynamic>(
      '/api/auth/request-otp',
      body: {'phone_number': phoneNumber},
    );
  }

  Future<AuthSession> verifyOtp(String phoneNumber, String otp) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/auth/verify-otp',
      body: {'phone_number': phoneNumber, 'otp': otp},
    );
    return AuthSession.fromJson(data);
  }

  // ---------------------------------------------------------------- user ---

  /// The person, and what they can currently do.
  ///
  /// It used to hard-code the role to `user` here, which was harmless only
  /// while nothing called it — the obvious way to refresh someone after
  /// onboarding would have quietly demoted every artisan to a client.
  Future<AppUser> me() async =>
      AppUser.fromJson(await _client.get<Map<String, dynamic>>('/api/user/me'));

  /// Records who someone is, at the end of signing up.
  Future<AppUser> completeProfile({
    required String name,
    required String countryCode,
    required String city,
    required String neighborhood,
    String? photoUrl,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/user/me/complete-profile',
      body: {
        'name': name,
        'country_code': countryCode,
        'city': city,
        'neighborhood': neighborhood,
        if (photoUrl != null) 'photo_url': photoUrl,
      },
    );
    return AppUser.fromJson(data);
  }

  /// Uploads an image and returns the URL to store against a profile.
  Future<String> uploadImage(File file) async {
    final data = await _client.upload<Map<String, dynamic>>(
      '/api/uploads',
      file: file,
    );
    return Json.str(data['url']);
  }

  /// Where Panergo operates. Public — the first screen needs these before the
  /// account they belong to has said anything.
  Future<List<Country>> countries() async {
    final data = await _client.get<List<dynamic>>('/api/quartiers/countries');
    return data.map((e) => Country.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<City>> cities(String countryCode) async {
    final data = await _client
        .get<List<dynamic>>('/api/quartiers/countries/$countryCode/cities');
    return data.map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The quartiers of one town, or all of them when no town is named.
  Future<List<Quartier>> quartiers({String? cityId}) async {
    final data = await _client.get<List<dynamic>>(
      '/api/quartiers',
      query: cityId == null ? null : {'city_id': cityId},
    );
    return data.map((e) => Quartier.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> updateProfile({
    String? name,
    String? countryCode,
    String? city,
    String? neighborhood,
    String? photoUrl,
  }) async {
    final data = await _client.put<Map<String, dynamic>>('/api/user/me', body: {
      if (name != null) 'name': name,
      if (countryCode != null) 'country_code': countryCode,
      if (city != null) 'city': city,
      if (neighborhood != null) 'neighborhood': neighborhood,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
    return AppUser.fromJson(data);
  }

  // ------------------------------------------------------------ requests ---

  /// Creates a tender request.
  ///
  /// [idempotencyKey] lets a queued offline send be retried without creating a
  /// second request.
  Future<String> createRequest({
    required ServiceCategory category,
    required String neighborhood,
    required String description,
    required Urgency urgency,
    BudgetBracket? budget,
    String? photoUrl,
    String? originProviderId,
    String? idempotencyKey,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/requests',
      headers:
          idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
      body: {
        'category': category.wire,
        'neighborhood': neighborhood,
        'description': description,
        'urgency': urgency.wire,
        if (budget != null) 'budget_bracket': budget.wire,
        if (photoUrl != null) 'photo_url': photoUrl,
        // The artisan whose work prompted this, so they hear about it first.
        if (originProviderId != null) 'origin_provider_id': originProviderId,
      },
    );
    return Json.str(data['request_id']);
  }

  /// Sends an urgent request straight to the nearest available provider.
  Future<DirectMatch> createDirectRequest({
    required ServiceCategory category,
    required String neighborhood,
    required String description,
    BudgetBracket? budget,
    String? photoUrl,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/requests/direct',
      body: {
        'category': category.wire,
        'neighborhood': neighborhood,
        'description': description,
        if (budget != null) 'budget_bracket': budget.wire,
        if (photoUrl != null) 'photo_url': photoUrl,
      },
    );
    return DirectMatch.fromJson(data);
  }

  Future<List<ServiceRequest>> myRequests() async {
    final data = await _client.get<List<dynamic>>('/api/requests/mine');
    return Json.list(data).map(ServiceRequest.fromJson).toList();
  }

  Future<ServiceRequest> request(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/api/requests/$id');
    return ServiceRequest.fromJson(data);
  }

  /// The provider's job board: open requests in their category and quartier.
  Future<List<AvailableRequest>> availableRequests() async {
    final data = await _client.get<List<dynamic>>('/api/requests/available');
    return Json.list(data).map(AvailableRequest.fromJson).toList();
  }

  // -------------------------------------------------------------- offers ---

  Future<String> createOffer({
    required String requestId,
    required int price,
    required TimelineLabel timeline,
    required String message,
  }) async {
    final data = await _client.post<Map<String, dynamic>>('/api/offers', body: {
      'request_id': requestId,
      'price': price,
      'timeline_label': timeline.wire,
      'message': message,
    });
    return Json.str(data['offer_id']);
  }

  /// Accepts an offer. Rejects the others and opens a booking.
  Future<({String bookingId, String qrToken})> selectOffer(String offerId) async {
    final data =
        await _client.post<Map<String, dynamic>>('/api/offers/$offerId/select');
    return (
      bookingId: Json.str(data['booking_id']),
      qrToken: Json.str(data['qr_token']),
    );
  }

  /// Every offer this provider has made, newest first. A selected one carries
  /// the booking id that lets the provider open the job they won.
  Future<List<MyOffer>> myOffers() async {
    final data = await _client.get<List<dynamic>>('/api/offers/mine');
    return Json.list(data).map(MyOffer.fromJson).toList();
  }

  // ------------------------------------------------------------ bookings ---

  Future<Booking> booking(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/api/bookings/$id');
    return Booking.fromJson(data);
  }

  Future<void> confirmArrival(String bookingId, String qrToken) async {
    await _client.post<dynamic>(
      '/api/bookings/$bookingId/confirm-arrival',
      body: {'qr_token': qrToken},
    );
  }

  /// Reissues an arrival code after the 24 h one expired. The provider has
  /// nothing to redo — they present whatever this screen now shows.
  Future<String> regenerateQrToken(String bookingId) async {
    final data =
        await _client.post<Map<String, dynamic>>('/api/bookings/$bookingId/qr');
    return Json.str(data['qr_token']);
  }

  Future<void> completeBooking(String bookingId) async {
    await _client.post<dynamic>('/api/bookings/$bookingId/complete');
  }

  // ------------------------------------------------------------- ratings ---

  Future<void> rate({
    required String bookingId,
    required int score,
    String? comment,
  }) async {
    await _client.post<dynamic>('/api/ratings', body: {
      'booking_id': bookingId,
      'score': score,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  // ------------------------------------------------------------ provider ---

  Future<ProviderProfile> providerProfile(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/api/provider/$id');
    return ProviderProfile.fromJson(data);
  }

  Future<ProviderRatingsPage> providerRatings(
    String providerId, {
    int page = 0,
    int size = 20,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/provider/$providerId/ratings',
      query: {'page': page, 'size': size},
    );
    return ProviderRatingsPage.fromJson(data);
  }

  /// Becoming a provider. The caller must re-authenticate afterwards: the role
  /// is baked into the JWT at issue time, so the current token still says USER.
  Future<String> registerAsProvider({
    required ServiceCategory category,
    required String neighborhood,
    String? bio,
    String? photoUrl,
  }) async {
    final data = await _client
        .post<Map<String, dynamic>>('/api/provider/register', body: {
      'category': category.wire,
      'neighborhood': neighborhood,
      if (bio != null) 'bio': bio,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
    return Json.str(data['provider_id']);
  }

  Future<void> updateProviderProfile({
    String? bio,
    String? photoUrl,
    bool? isActive,
  }) async {
    await _client.put<dynamic>('/api/provider/me', body: {
      if (bio != null) 'bio': bio,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (isActive != null) 'is_active': isActive,
    });
  }

  // ---------------------------------------------------------------- chat ---

  /// Messages for a booking, oldest first. Omit [before] for the latest window.
  Future<List<ChatMessage>> chatHistory(
    String bookingId, {
    DateTime? before,
    int? limit,
  }) async {
    final data = await _client.get<List<dynamic>>(
      '/api/chat/$bookingId/messages',
      query: {
        if (before != null) 'before': before.toUtc().toIso8601String(),
        if (limit != null) 'limit': limit,
      },
    );
    return Json.list(data).map(ChatMessage.fromJson).toList();
  }

  // ------------------------------------------------------------ quartier ---

  Future<({List<QuartierPost> posts, int page, int totalPages})> quartier({
    String? neighborhood,
    int page = 0,
    int size = 20,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/quartier',
      query: {
        if (neighborhood != null) 'neighborhood': neighborhood,
        'page': page,
        'size': size,
      },
    );
    return (
      posts: Json.list(data['content']).map(QuartierPost.fromJson).toList(),
      page: Json.intOf(data['page']),
      totalPages: Json.intOf(data['total_pages']),
    );
  }

  Future<QuartierPost> createQuartierPost({
    required QuartierPostKind kind,
    required String body,
    String? neighborhood,
  }) async {
    final data =
        await _client.post<Map<String, dynamic>>('/api/quartier/posts', body: {
      'kind': kind.wire,
      'body': body,
      if (neighborhood != null) 'neighborhood': neighborhood,
    });
    return QuartierPost.fromJson(data);
  }

  Future<List<QuartierReply>> quartierReplies(String postId) async {
    final data =
        await _client.get<List<dynamic>>('/api/quartier/posts/$postId/replies');
    return Json.list(data).map(QuartierReply.fromJson).toList();
  }

  Future<QuartierReply> replyToPost(String postId, String body) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/quartier/posts/$postId/replies',
      body: {'body': body},
    );
    return QuartierReply.fromJson(data);
  }

  // ---------------------------------------------------------- businesses ---

  /// The business taxonomy, served rather than hardcoded.
  ///
  /// Unlike [ServiceCategory]'s eighteen trades, this list grows without an app
  /// release, so it is fetched rather than compiled in.
  Future<List<BusinessCategory>> businessCategories() async {
    final data = await _client.get<List<dynamic>>('/api/business-categories');
    return data
        .map((e) => BusinessCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The directory: published listings, the reader's quartier first.
  Future<BusinessPage> businesses({
    String? category,
    String? neighborhood,
    int page = 0,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/businesses',
      query: {
        if (category != null) 'category': category,
        if (neighborhood != null) 'neighborhood': neighborhood,
        'page': page,
      },
    );
    return BusinessPage.fromJson(data);
  }

  Future<BusinessDetail> business(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/api/businesses/$id');
    return BusinessDetail.fromJson(data);
  }

  /// A published business's price list.
  Future<List<BusinessProduct>> businessProducts(String businessId) async {
    final data =
        await _client.get<List<dynamic>>('/api/businesses/$businessId/products');
    return data
        .map((e) => BusinessProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ------------------------------------------------- businesses I manage ---

  Future<List<BusinessDetail>> myBusinesses() async {
    final data = await _client.get<List<dynamic>>('/api/businesses/me');
    return data
        .map((e) => BusinessDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BusinessDetail> registerBusiness({
    required String name,
    required String categoryCode,
    required String neighborhood,
    String? description,
    String? addressLine,
    String? phoneNumber,
    String? whatsappNumber,
    String? photoUrl,
    List<String> services = const [],
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/businesses/me',
      body: {
        'name': name,
        'category_code': categoryCode,
        'neighborhood': neighborhood,
        if (description != null) 'description': description,
        if (addressLine != null) 'address_line': addressLine,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
        if (photoUrl != null) 'photo_url': photoUrl,
        'services': services,
      },
    );
    return BusinessDetail.fromJson(data);
  }

  Future<BusinessDetail> updateBusiness(
    String id, {
    required String name,
    String? description,
    String? addressLine,
    String? phoneNumber,
    String? whatsappNumber,
    String? photoUrl,
    String? bannerUrl,
    List<String> services = const [],
    List<BusinessLink> links = const [],
  }) async {
    final data = await _client.put<Map<String, dynamic>>(
      '/api/businesses/me/$id',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (addressLine != null) 'address_line': addressLine,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (bannerUrl != null) 'banner_url': bannerUrl,
        'services': services,
        'links': [
          for (final link in links) {'kind': link.kind.wire, 'url': link.url}
        ],
      },
    );
    return BusinessDetail.fromJson(data);
  }

  /// The whole week at once — editing hours is "here is when I am open".
  Future<List<BusinessHours>> setBusinessHours(
      String id, List<BusinessHours> slots) async {
    final data = await _client.put<List<dynamic>>(
      '/api/businesses/me/$id/hours',
      body: {
        'slots': slots
            .map((s) => {
                  'day_of_week': s.dayOfWeek,
                  'opens_at': s.opensAt,
                  'closes_at': s.closesAt,
                })
            .toList(),
      },
    );
    return data
        .map((e) => BusinessHours.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The owner's own catalogue, including what is out of stock.
  Future<List<BusinessProduct>> myProducts(String businessId) async {
    final data = await _client
        .get<List<dynamic>>('/api/businesses/me/$businessId/products');
    return data
        .map((e) => BusinessProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BusinessProduct> saveProduct(
    String businessId, {
    String? productId,
    required String name,
    String? description,
    String? photoUrl,
    int? price,
    String? unit,
    bool? available,
    String? groupId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (description != null) 'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
      // Sent explicitly as null rather than omitted: absent means "leave it",
      // and « prix sur demande » has to be settable on a product that had one.
      'price': price,
      if (unit != null) 'unit': unit,
      if (available != null) 'available': available,
      if (groupId != null) 'group_id': groupId,
    };

    final path = productId == null
        ? '/api/businesses/me/$businessId/products'
        : '/api/businesses/me/$businessId/products/$productId';

    final data = productId == null
        ? await _client.post<Map<String, dynamic>>(path, body: body)
        : await _client.put<Map<String, dynamic>>(path, body: body);

    return BusinessProduct.fromJson(data);
  }

  Future<void> deleteProduct(String businessId, String productId) =>
      _client.delete<dynamic>('/api/businesses/me/$businessId/products/$productId');

  // -------------------------------------------------------------- stream ---

  /// The merged stream: neighbours' posts and artisans' work together.
  Future<StreamPage> stream({bool onlyMine = false, int page = 0}) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/stream',
      query: {'onlyMine': onlyMine, 'page': page},
    );
    return StreamPage.fromJson(data);
  }

  // ------------------------------------------------- marks and replies ---

  /// Marks a post useful, or takes the mark back.
  ///
  /// A toggle: the tap says the mark should be there or should not, and the
  /// server answers with the state that resulted.
  Future<PostMark> toggleMark({required String kind, required String postId}) async {
    final data =
        await _client.post<Map<String, dynamic>>('/api/marks/$kind/$postId');
    return PostMark.fromJson(data);
  }

  Future<List<PostReply>> feedReplies(String postId) async {
    final data =
        await _client.get<List<dynamic>>('/api/feed/posts/$postId/replies');
    return data.map((e) => PostReply.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PostReply> replyToFeedPost(String postId, String body) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/feed/posts/$postId/replies',
      body: {'body': body},
    );
    return PostReply.fromJson(data);
  }

  // --------------------------------------------------------------- deals ---

  Future<List<Deal>> deals() async {
    final data = await _client.get<List<dynamic>>('/api/deals');
    return Json.list(data).map(Deal.fromJson).toList();
  }

  // ---------------------------------------------------------------- feed ---

  Future<({List<FeedPost> posts, int page, int totalPages})> feed({
    int page = 0,
    int size = 20,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/feed',
      query: {'page': page, 'size': size},
    );
    return (
      posts: Json.list(data['content']).map(FeedPost.fromJson).toList(),
      page: Json.intOf(data['page']),
      totalPages: Json.intOf(data['total_pages']),
    );
  }

  Future<void> createFeedPost({
    required String photoUrl,
    required PostType postType,
    String? caption,
  }) async {
    await _client.post<dynamic>('/api/feed/posts', body: {
      'photo_url': photoUrl,
      'post_type': postType.wire,
      if (caption != null) 'caption': caption,
    });
  }

  // ----------------------------------------------------------- assistant ---

  /// Free-text provider search.
  ///
  /// [neighborhood] matters: the backend never infers it, and without one the
  /// result list is always empty.
  Future<AssistantAnswer> assistantSearch({
    required String query,
    ServiceCategory? category,
    String? neighborhood,
  }) async {
    final data =
        await _client.post<Map<String, dynamic>>('/api/assistant/search', body: {
      'query': query,
      if (category != null) 'category': category.wire,
      if (neighborhood != null) 'neighborhood': neighborhood,
    });
    return AssistantAnswer.fromJson(data);
  }

  // -------------------------------------------------------------- device ---

  Future<void> registerDevice(String fcmToken) async {
    await _client
        .post<dynamic>('/api/device/register', body: {'fcm_token': fcmToken});
  }

  /// Called on sign-out. Unusually for DELETE, this one carries a body.
  Future<void> removeDevice(String fcmToken) async {
    await _client
        .delete<dynamic>('/api/device/token', body: {'fcm_token': fcmToken});
  }

  // ------------------------------------------------- price negotiation ---

  Future<PriceNegotiation> priceThread(String offerId) async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/offers/$offerId/price');
    return PriceNegotiation.fromJson(data);
  }

  /// Puts a new price on the table. Answering an open proposal with a different
  /// number counters it — the server closes the old round as part of the same
  /// call, so there is never more than one live price.
  Future<PriceNegotiation> proposePrice(
    String offerId, {
    required int price,
    String? message,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/offers/$offerId/price/proposals',
      body: {
        'price': price,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return PriceNegotiation.fromJson(data);
  }

  /// Takes the price on the table. Only the party who did not propose it may.
  Future<PriceNegotiation> acceptPrice(String offerId, String proposalId) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/offers/$offerId/price/proposals/$proposalId/accept',
    );
    return PriceNegotiation.fromJson(data);
  }

  // ---------------------------------------------------------- schedule ---

  /// The provider's committed work between two dates, inclusive.
  Future<Agenda> agenda({required DateTime from, required DateTime to}) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/provider/me/agenda',
      query: {'from': _isoDate(from), 'to': _isoDate(to)},
    );
    return Agenda.fromJson(data);
  }

  /// Sets or moves when a visit happens. Either participant may call it.
  Future<void> scheduleBooking(
    String bookingId, {
    required DateTime scheduledAt,
    DateTime? scheduledEndAt,
  }) async {
    await _client.post<dynamic>('/api/bookings/$bookingId/schedule', body: {
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      if (scheduledEndAt != null)
        'scheduled_end_at': scheduledEndAt.toUtc().toIso8601String(),
    });
  }

  Future<Availability> availability() async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/provider/me/availability');
    return Availability.fromJson(data);
  }

  /// Replaces the whole week. Days left out are days not worked.
  Future<Availability> setAvailability(List<WorkingDay> days) async {
    final data = await _client.put<Map<String, dynamic>>(
      '/api/provider/me/availability',
      body: {'days': days.map((d) => d.toJson()).toList()},
    );
    return Availability.fromJson(data);
  }

  Future<void> addTimeOff({
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    await _client.post<dynamic>('/api/provider/me/time-off', body: {
      'start_date': _isoDate(startDate),
      'end_date': _isoDate(endDate),
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> removeTimeOff(String id) async {
    await _client.delete<dynamic>('/api/provider/me/time-off/$id');
  }

  // ----------------------------------------------------------- workspace ---

  Future<ProviderMetrics> metrics() async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/provider/me/metrics');
    return ProviderMetrics.fromJson(data);
  }

  Future<List<ClientSummary>> clients() async {
    final data = await _client
        .get<List<dynamic>>('/api/provider/me/clients');
    return data
        .map((e) => ClientSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MissedOpportunities> missedOpportunities() async {
    final data = await _client
        .get<Map<String, dynamic>>('/api/provider/me/missed-opportunities');
    return MissedOpportunities.fromJson(data);
  }

  Future<ProviderRevenue> revenue(
      {RevenuePeriod period = RevenuePeriod.allTime}) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/provider/me/revenue',
      query: {'period': period.wire},
    );
    return ProviderRevenue.fromJson(data);
  }

  // ---------------------------------------------------------- cancellation ---

  /// Calls off a job that has not started. [noShow] is the client's report that
  /// the provider never came, and the server refuses it from anyone else.
  Future<void> cancelBooking(
    String bookingId, {
    String? reason,
    bool noShow = false,
  }) async {
    await _client.post<dynamic>('/api/bookings/$bookingId/cancel', body: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      'no_show': noShow,
    });
  }

  /// Dates on the wire are plain calendar days, not instants — the agenda is
  /// read in Douala time and a timezone would shift it by a day at the edges.
  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
