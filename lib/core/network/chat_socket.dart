import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Where the live connection stands, so the chat header can say so.
///
/// The distinction that matters to the user is [connected] versus everything
/// else: while we are not connected, a message can still be typed but not yet
/// sent, and the screen has to say why rather than swallowing the tap.
enum ChatConnection { connecting, connected, disconnected }

/// The STOMP half of the chat.
///
/// History is REST ([PanergoApi.chatHistory]); everything live goes over the
/// socket the backend documents in `WebSocketConfig`:
///
/// * connect to `{base}/ws` with SockJS, carrying `Authorization: Bearer {jwt}`
///   on the CONNECT frame — the handshake itself is unauthenticated, so the
///   token has to ride on the frame rather than the URL,
/// * subscribe to `/topic/chat.{conversationId}`,
/// * send to `/app/chat.send` as `{booking_id, content?, photo_url?}`.
///
/// The sender is taken from the authenticated session server-side, so nothing
/// here identifies the author — a client-supplied sender would be a forgery
/// waiting to happen.
class ChatSocket {
  ChatSocket({
    required this.conversationId,
    required this.token,
    @visibleForTesting StompClient Function(StompConfig)? clientFactory,
  }) : _clientFactory =
            clientFactory ?? ((config) => StompClient(config: config));

  final String conversationId;
  final String token;
  final StompClient Function(StompConfig) _clientFactory;

  final _messages = StreamController<ChatMessage>.broadcast();
  final _connection = StreamController<ChatConnection>.broadcast();

  StompClient? _client;
  bool _disposed = false;

  /// Messages arriving on this booking's topic.
  Stream<ChatMessage> get messages => _messages.stream;

  /// Connection transitions, for the "connexion…" line in the header.
  Stream<ChatConnection> get connection => _connection.stream;

  ChatConnection _state = ChatConnection.connecting;
  ChatConnection get state => _state;

  bool get isConnected => _state == ChatConnection.connected;

  void connect() {
    if (_disposed || _client != null) return;

    _emitConnection(ChatConnection.connecting);

    _client = _clientFactory(
      StompConfig.sockJS(
        url: ApiConfig.webSocketUrl,
        // The backend closes an unauthenticated CONNECT with an ERROR frame,
        // so the token goes on both the STOMP frame and the handshake headers.
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        // What the backend advertises.
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
        // Exponential backoff is not exposed by the client, but it does
        // reconnect on its own; 1s matches the documented floor.
        reconnectDelay: const Duration(seconds: 1),
        onConnect: _onConnect,
        onWebSocketDone: () => _emitConnection(ChatConnection.disconnected),
        onDisconnect: (_) => _emitConnection(ChatConnection.disconnected),
        // A dropped socket is normal on mobile and the client retries by
        // itself, so a failure moves the header to "hors ligne" rather than
        // tearing the screen down.
        onWebSocketError: (_) => _emitConnection(ChatConnection.disconnected),
        onStompError: (_) => _emitConnection(ChatConnection.disconnected),
      ),
    )..activate();
  }

  void _onConnect(StompFrame frame) {
    if (_disposed) return;

    _client?.subscribe(
      destination: '/topic/chat.$conversationId',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            _messages.add(ChatMessage.fromJson(decoded));
          }
        } on FormatException {
          // A frame we cannot parse is not worth killing the thread over.
        }
      },
    );

    _emitConnection(ChatConnection.connected);
  }

  /// Sends a message. Returns false when the socket is not up, so the caller
  /// can keep the draft in the composer rather than losing it.
  bool send({String? content, String? photoUrl}) {
    final client = _client;
    if (client == null || !isConnected) return false;

    client.send(
      destination: '/app/chat.send',
      body: jsonEncode({
        'conversation_id': conversationId,
        if (content != null && content.isNotEmpty) 'content': content,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
      }),
    );
    return true;
  }

  void _emitConnection(ChatConnection next) {
    if (_disposed || _state == next) return;
    _state = next;
    _connection.add(next);
  }

  Future<void> dispose() async {
    _disposed = true;
    _client?.deactivate();
    _client = null;
    await _messages.close();
    await _connection.close();
  }
}
