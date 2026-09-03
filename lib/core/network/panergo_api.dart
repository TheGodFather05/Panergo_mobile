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

  Future<AppUser> me() async {
    final data = await _client.get<Map<String, dynamic>>('/api/user/me');
    // This endpoint omits `role`; callers merge it from the stored session.
    return AppUser.fromJson({...data, 'role': UserRole.user.wire});
  }

  Future<void> updateProfile({String? name, String? neighborhood}) async {
    await _client.put<dynamic>('/api/user/me', body: {
      if (name != null) 'name': name,
      if (neighborhood != null) 'neighborhood': neighborhood,
    });
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

  Future<List<Map<String, dynamic>>> myOffers() async {
    final data = await _client.get<List<dynamic>>('/api/offers/mine');
    return Json.list(data);
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

  /// Total value of completed missions. Not a wallet — Panergo does not
  /// transact, it introduces.
  Future<({int total, String currency, int completedBookings})> revenue() async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/provider/me/revenue');
    return (
      total: Json.intOf(data['total_valeur_missions']),
      currency: Json.str(data['currency']),
      completedBookings: Json.intOf(data['completed_bookings_count']),
    );
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
}
