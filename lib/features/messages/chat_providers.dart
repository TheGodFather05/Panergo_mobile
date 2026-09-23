import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/chat_socket.dart';
import '../../core/providers.dart';

/// One thread: the history we have loaded, plus where the live socket stands.
class ChatThread {
  const ChatThread({
    this.messages = const [],
    this.connection = ChatConnection.connecting,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  /// Oldest first — the order the list renders in.
  final List<ChatMessage> messages;
  final ChatConnection connection;
  final bool isLoading;
  final bool isLoadingMore;

  /// Whether a full page came back, so there is likely more above.
  final bool hasMore;
  final ApiException? error;

  bool get isEmpty => messages.isEmpty;

  /// Sending is only possible while the socket is up; the composer says so.
  bool get canSend => connection == ChatConnection.connected;

  ChatThread copyWith({
    List<ChatMessage>? messages,
    ChatConnection? connection,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    ApiException? error,
    bool clearError = false,
  }) =>
      ChatThread(
        messages: messages ?? this.messages,
        connection: connection ?? this.connection,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Drives one booking's conversation.
///
/// History arrives over REST and everything after over STOMP. The two can
/// overlap — a message can land on the topic while the history request is in
/// flight — so messages are merged by id rather than appended blindly.
class ChatController extends AsyncNotifier<ChatThread> {
  ChatController(this._conversationId);

  static const _pageSize = 50;

  final String _conversationId;

  ChatSocket? _socket;
  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<ChatConnection>? _connectionSub;

  @override
  Future<ChatThread> build() async {
    ref.onDispose(() {
      _messageSub?.cancel();
      _connectionSub?.cancel();
      unawaited(_socket?.dispose());
    });

    final thread = await _loadHistory();
    await _openSocket();
    return thread;
  }

  Future<ChatThread> _loadHistory() async {
    try {
      final history = await ref
          .read(apiProvider)
          .chatHistory(_conversationId, limit: _pageSize);
      return ChatThread(
        messages: history,
        isLoading: false,
        hasMore: history.length >= _pageSize,
      );
    } on ApiException catch (e) {
      return ChatThread(isLoading: false, error: e);
    }
  }

  Future<void> _openSocket() async {
    final token = await ref.read(tokenStoreProvider).readToken();
    if (token == null || token.isEmpty) return;

    final socket = ChatSocket(conversationId: _conversationId, token: token);
    _socket = socket;

    _messageSub = socket.messages.listen(_onLiveMessage);
    _connectionSub = socket.connection.listen((connection) {
      _update((thread) => thread.copyWith(connection: connection));
    });

    socket.connect();
  }

  void _onLiveMessage(ChatMessage message) {
    _update((thread) {
      // The topic echoes our own sends back, and a reconnect can replay one we
      // already hold — so an id we know is an update, never a duplicate.
      final existing =
          thread.messages.indexWhere((m) => m.id == message.id);
      if (existing >= 0) {
        final merged = [...thread.messages]..[existing] = message;
        return thread.copyWith(messages: merged);
      }
      return thread.copyWith(messages: [...thread.messages, message]);
    });
  }

  /// Pages further back, oldest-first, from the top of what we hold.
  Future<void> loadMore() async {
    final thread = state.value;
    if (thread == null ||
        thread.isLoadingMore ||
        !thread.hasMore ||
        thread.messages.isEmpty) {
      return;
    }

    _update((t) => t.copyWith(isLoadingMore: true));

    try {
      final older = await ref.read(apiProvider).chatHistory(
            _conversationId,
            before: thread.messages.first.sentAt,
            limit: _pageSize,
          );

      _update((t) {
        final known = t.messages.map((m) => m.id).toSet();
        final fresh = older.where((m) => !known.contains(m.id)).toList();
        return t.copyWith(
          messages: [...fresh, ...t.messages],
          isLoadingMore: false,
          hasMore: older.length >= _pageSize,
        );
      });
    } on ApiException {
      // Failing to page further back leaves what we have on screen; the user
      // can pull again. Surfacing an error here would hide the conversation.
      _update((t) => t.copyWith(isLoadingMore: false, hasMore: false));
    }
  }

  /// True when the message went out. False leaves the draft in the composer.
  bool send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _socket?.send(content: trimmed) ?? false;
  }

  /// Retries the history load after an error.
  Future<void> retry() async {
    state = const AsyncValue<ChatThread>.loading();
    final thread = await _loadHistory();
    final connection = _socket?.state ?? ChatConnection.connecting;
    state = AsyncValue.data(thread.copyWith(connection: connection));
    if (_socket == null) await _openSocket();
  }

  void _update(ChatThread Function(ChatThread) transform) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(transform(current));
  }
}

final chatControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChatController, ChatThread, String>(ChatController.new);

