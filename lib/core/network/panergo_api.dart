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
  Future<String> uploadImage(File file,
      {void Function(double fraction)? onProgress}) async {
    final data = await _client.upload<Map<String, dynamic>>(
      '/api/uploads',
      file: file,
      onProgress: onProgress,
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
    String conversationId, {
    DateTime? before,
    int? limit,
  }) async {
    final data = await _client.get<List<dynamic>>(
      '/api/chat/$conversationId/messages',
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

  // ------------------------------------------------------------- groups ---

  Future<List<GroupSummary>> groups({String? query}) async {
    final data = await _client.get<List<dynamic>>(
      '/api/groups',
      query: {if (query != null && query.isNotEmpty) 'q': query},
    );
    return data.map((e) => GroupSummary.fromJson(Json.obj(e))).toList();
  }

  Future<GroupSummary> createGroup({
    required String name,
    String? description,
    String? neighborhood,
    String? iconName,
  }) async {
    final data = await _client.post<Map<String, dynamic>>('/api/groups', body: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      if (neighborhood != null && neighborhood.isNotEmpty) 'neighborhood': neighborhood,
      if (iconName != null && iconName.isNotEmpty) 'icon_name': iconName,
    });
    return GroupSummary.fromJson(data);
  }

  Future<void> requestToJoinGroup(String groupId, {String? message}) =>
      _client.post<dynamic>('/api/groups/$groupId/join-requests', body: {
        if (message != null && message.isNotEmpty) 'message': message,
      });

  Future<List<GroupPerson>> groupJoinRequests(String groupId) async {
    final data = await _client
        .get<List<dynamic>>('/api/groups/$groupId/join-requests');
    return data.map((e) => GroupPerson.fromJson(Json.obj(e))).toList();
  }

  Future<void> decideGroupJoinRequest(
    String groupId,
    String requestId, {
    required bool accept,
  }) =>
      _client.post<dynamic>(
          '/api/groups/$groupId/join-requests/$requestId/'
          '${accept ? 'accept' : 'decline'}');

  Future<List<GroupPerson>> groupMembers(String groupId) async {
    final data =
        await _client.get<List<dynamic>>('/api/groups/$groupId/members');
    return data.map((e) => GroupPerson.fromJson(Json.obj(e))).toList();
  }

  Future<void> leaveGroup(String groupId) =>
      _client.delete<dynamic>('/api/groups/$groupId/membership');

  // ------------------------------------------------------ conversations ---

  /// Every thread the caller can see, newest activity first.
  Future<List<Conversation>> conversations() async {
    final data = await _client.get<List<dynamic>>('/api/conversations');
    return data
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Clears a thread from your own inbox.
  ///
  /// Not a delete: the other side keeps the exchange, and a new message brings
  /// it back.
  Future<void> hideConversation(String conversationId) =>
      _client.delete<dynamic>('/api/conversations/$conversationId');

  /// Opens a thread with a shop, or returns the one already open.
  Future<Conversation> openBusinessConversation(String businessId) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/conversations',
      body: {'business_id': businessId},
    );
    return Conversation.fromJson(data);
  }

  /// The thread for a booking, created the first time anyone opens it.
  Future<Conversation> openBookingConversation(String bookingId) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/conversations',
      body: {'booking_id': bookingId},
    );
    return Conversation.fromJson(data);
  }

  // ------------------------------------------------------- moderation ---

  /// Listings waiting to be reviewed, oldest first.
  Future<List<BusinessDetail>> moderationQueue({BusinessStatus? status}) async {
    final data = await _client.get<List<dynamic>>(
      '/api/admin/businesses',
      query: {if (status != null) 'status': status.wire},
    );
    return data
        .map((e) => BusinessDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BusinessDetail> publishBusiness(String id) async {
    final data = await _client
        .post<Map<String, dynamic>>('/api/admin/businesses/$id/publish');
    return BusinessDetail.fromJson(data);
  }

  /// @param reason required — a refusal the owner cannot read leaves them with
  /// nothing to correct.
  Future<BusinessDetail> rejectBusiness(String id, String reason) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/admin/businesses/$id/reject',
      body: {'reason': reason},
    );
    return BusinessDetail.fromJson(data);
  }

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

  /// « Mes publications » — the signed-in artisan's own posts, newest first.
  Future<List<FeedPost>> myFeedPosts({int size = 20}) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/feed/posts/mine',
      query: {'page': 0, 'size': size},
    );
    return Json.list(data['content']).map(FeedPost.fromJson).toList();
  }

  /// The signed-in artisan's own provider record — their trade and quartier,
  /// which the account itself does not carry.
  Future<ProviderProfile> myProviderProfile() async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/provider/me');
    return ProviderProfile.fromJson(data);
  }

  /// Publishes a réalisation or a conseil.
  ///
  /// [photoUrl] is required for a réalisation and optional for a conseil, and
  /// it decides the destination: with a photo the post reaches the public feed,
  /// without one a conseil stays on the artisan's own profile.
  Future<void> createFeedPost({
    required PostType postType,
    String? photoUrl,
    String? caption,
  }) async {
    await _client.post<dynamic>('/api/feed/posts', body: {
      if (photoUrl != null) 'photo_url': photoUrl,
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

  /// Artisans for the client's home strip, own quartier first.
  ///
  /// Public on the backend, so it works before sign-in rather than leaving the
  /// first screen somebody sees half-empty.
  Future<List<ProviderProfile>> featuredProviders({
    String? neighborhood,
    int limit = 3,
  }) async {
    final data = await _client.get<List<dynamic>>(
      '/api/provider/featured',
      query: {
        if (neighborhood != null && neighborhood.isNotEmpty)
          'neighborhood': neighborhood,
        'limit': limit,
      },
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(ProviderProfile.fromJson)
        .toList();
  }

  // ------------------------------------------------------ relayed search ---

  /// Sends one question and lets the server decide which market answers it.
  ///
  /// The person describes what they need; whether that becomes a tender to
  /// artisans or a stock question to shops is not theirs to classify. A
  /// [ReferralKind.ambiguous] answer creates nothing and hands back two options
  /// to choose between — send again with [target] set to settle it.
  ///
  /// [idempotencyKey] makes a retry safe: replaying a key returns what it first
  /// created rather than asking the same shopkeepers twice.
  Future<ReferralOutcome> sendReferral({
    required String text,
    required String neighborhood,
    ReferralTarget? target,
    bool urgent = false,
    String? photoUrl,
    String? idempotencyKey,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/referrals',
      headers:
          idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
      body: {
        'text': text,
        'neighborhood': neighborhood,
        if (target != null) 'target': target.wire,
        'urgent': urgent,
        if (photoUrl != null) 'photo_url': photoUrl,
      },
    );
    return ReferralOutcome.fromJson(data);
  }

  /// The stock questions this person asked. Tenders come from [myRequests].
  Future<List<InquirySummary>> myInquiries() async {
    final data = await _client.get<List<dynamic>>('/api/referrals/mine');
    return data
        .cast<Map<String, dynamic>>()
        .map(InquirySummary.fromJson)
        .toList();
  }

  Future<InquiryDetail> inquiry(String id) async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/referrals/$id');
    return InquiryDetail.fromJson(data);
  }

  /// The draft for asking the same thing again.
  ///
  /// A draft and not a send: a stock question comes back precisely because
  /// stock changed, so the wording gets reread before it reaches the same
  /// shopkeepers a second time.
  Future<AskAgainDraft> askAgainDraft(String inquiryId) async {
    final data = await _client
        .get<Map<String, dynamic>>('/api/referrals/$inquiryId/ask-again');
    return AskAgainDraft.fromJson(data);
  }

  /// Stops listening. The answers already in stay readable.
  /// How many artisans of a trade a question would reach, before writing it.
  ///
  /// The « + » entry starts from nothing, so the draft has no reach to show
  /// until it asks. A count and never the rows.
  Future<({int wouldReach, bool wouldWiden})> tradeReach({
    required ServiceCategory trade,
    required String neighborhood,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/referrals/trade-reach',
      query: {'trade': trade.wire, 'neighborhood': neighborhood},
    );
    return (
      wouldReach: Json.intOf(data['would_reach']),
      wouldWiden: data['would_widen'] == true,
    );
  }

  /// « En faire une demande » — a « je peux » becomes a real tender.
  ///
  /// The question closes and records what it became, so the row can say
  /// « devenue une demande » rather than an unexplained « close ». Idempotent
  /// server-side: a second tap returns the same request rather than opening
  /// another.
  ///
  /// The indicative price an artisan may have mentioned is deliberately not
  /// carried over — that omission is what shows it was never a quote.
  Future<({String requestId, int providersNotified})> inquiryToRequest(
      String inquiryId) async {
    final data = await _client.post<Map<String, dynamic>>(
        '/api/referrals/$inquiryId/to-request');
    return (
      requestId: Json.str(data['request_id']),
      providersNotified: Json.intOf(data['providers_notified']),
    );
  }

  Future<void> closeInquiry(String id) =>
      _client.post<dynamic>('/api/referrals/$id/close');

  /// Replays a queued tender exactly as it was first attempted.
  ///
  /// Takes the raw body rather than typed arguments: the queue stored what was
  /// sent, and rebuilding it from parsed fields risks a subtle difference between
  /// the first attempt and the retry. The idempotency key makes the replay safe.
  Future<void> createRequestFromQueue({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) =>
      _client.post<dynamic>(
        '/api/requests',
        headers: {'Idempotency-Key': idempotencyKey},
        body: body,
      );

  /// Replays a queued relayed question. Same reasoning as above.
  Future<void> sendReferralFromQueue({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) =>
      _client.post<dynamic>(
        '/api/referrals',
        headers: {'Idempotency-Key': idempotencyKey},
        body: body,
      );

  /// The client withdraws a request nobody has been chosen for.
  ///
  /// Returns how many artisans were notified, so the screen can say so rather
  /// than leaving them to wonder whether anybody was told.
  Future<int> cancelRequest(String requestId) async {
    final data = await _client
        .post<Map<String, dynamic>>('/api/requests/$requestId/cancel');
    return Json.intOf(data['providers_notified']);
  }

  /// The artisan takes their own offer back.
  ///
  /// Distinct from the client rejecting it: a new one may be sent while the
  /// request is still open, and this never counts against their response rate.
  Future<void> withdrawOffer(String offerId) =>
      _client.post<dynamic>('/api/offers/$offerId/withdraw');

  // ------------------------------------------ relayed search, trade side ---

  /// The questions sent to this artisan, answered or not.
  ///
  /// Addressed by the token rather than a provider id: an artisan has exactly
  /// one provider record, so asking them to supply its id would be asking them
  /// to prove what the token already says.
  Future<List<ShopInboxItem>> tradeInquiries() async {
    final data = await _client.get<List<dynamic>>('/api/provider/me/inquiries');
    return data
        .cast<Map<String, dynamic>>()
        .map(ShopInboxItem.fromJson)
        .toList();
  }

  /// « Je peux le faire » or « ce n'est pas pour moi ».
  ///
  /// Not an offer, and the parameters keep saying so: [price] is indicative and
  /// [availability] is a rough window. The real offer is made later, against a
  /// real request, through the tender flow.
  Future<void> answerTradeInquiry(
    String inquiryId, {
    required bool canDo,
    int? price,
    String? availability,
    String? note,
  }) =>
      _client.post<dynamic>(
        '/api/provider/me/inquiries/$inquiryId/reply',
        body: {
          'can_do': canDo,
          if (canDo && price != null) 'price': price,
          if (canDo && availability != null) 'availability': availability,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

  Future<InquirySettings> tradeInquirySettings() async {
    final data = await _client
        .get<Map<String, dynamic>>('/api/provider/me/inquiry-settings');
    return InquirySettings.fromJson(data);
  }

  Future<InquirySettings> saveTradeInquirySettings({
    required bool acceptsInquiries,
    required bool ownQuartierOnly,
    int? dailyCap,
    int? pauseDays,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/api/provider/me/inquiry-settings',
      body: {
        'accepts_inquiries': acceptsInquiries,
        'own_quartier_only': ownQuartierOnly,
        if (dailyCap != null) 'daily_cap': dailyCap,
        if (pauseDays != null) 'pause_days': pauseDays,
      },
    );
    return InquirySettings.fromJson(data);
  }

  // ------------------------------------------- relayed search, shop side ---

  /// The questions this shop has been sent, answered or not.
  Future<List<ShopInboxItem>> shopInquiries(String businessId) async {
    final data = await _client
        .get<List<dynamic>>('/api/businesses/me/$businessId/inquiries');
    return data
        .cast<Map<String, dynamic>>()
        .map(ShopInboxItem.fromJson)
        .toList();
  }

  /// « J'en ai » or « je n'en ai pas », and optionally a price.
  ///
  /// Sending it twice corrects the answer rather than adding a second one.
  /// A price alongside [hasItem] false is refused by the server: the comparison
  /// screen sorts on price and would file a refusal among the offers.
  Future<void> answerShopInquiry(
    String businessId,
    String inquiryId, {
    required bool hasItem,
    int? price,
    String? unit,
    String? note,
  }) =>
      _client.post<dynamic>(
        '/api/businesses/me/$businessId/inquiries/$inquiryId/reply',
        body: {
          'has_item': hasItem,
          if (hasItem && price != null) 'price': price,
          if (hasItem && unit != null) 'unit': unit,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

  Future<InquirySettings> shopInquirySettings(String businessId) async {
    final data = await _client.get<Map<String, dynamic>>(
        '/api/businesses/me/$businessId/inquiry-settings');
    return InquirySettings.fromJson(data);
  }

  /// Take the shop out of relayed questions, narrow them, cap them, or pause.
  ///
  /// [pauseDays] null lifts an existing pause: being busy is temporary, and
  /// undoing it should not mean finding this screen again in a calmer week.
  Future<InquirySettings> saveShopInquirySettings(
    String businessId, {
    required bool acceptsInquiries,
    required bool ownQuartierOnly,
    int? dailyCap,
    int? pauseDays,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/api/businesses/me/$businessId/inquiry-settings',
      body: {
        'accepts_inquiries': acceptsInquiries,
        'own_quartier_only': ownQuartierOnly,
        if (dailyCap != null) 'daily_cap': dailyCap,
        if (pauseDays != null) 'pause_days': pauseDays,
      },
    );
    return InquirySettings.fromJson(data);
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
