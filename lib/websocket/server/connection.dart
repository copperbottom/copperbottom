import 'dart:io';

import 'package:copperbottom/websocket/delegate.dart';
import 'package:copperbottom/websocket/server/server.dart';

/// A delegate responsible for handling communications with one individual
/// [WebSocket] client.
class ConnectionHandler {
  /// The server that this connection handler belongs to.
  final WebSocketServer server;

  /// The [WebSocket] that this connection handler is responsible for handling.
  final WebSocket socket;

  /// Whether the socket connection is active.
  bool get isActive => _delegate != null;

  /// The constructor tear-off that generates a delegate for the socket
  /// connection.
  final WebSocketDelegate Function() delegateBuilder;

  /// The delegate responsible for performing application functions based on
  /// requests.
  WebSocketDelegate? _delegate;

  ConnectionHandler({
    required this.socket,
    required this.server,
    required this.delegateBuilder,
  });

  void accept() {
    _delegate = delegateBuilder();

    socket.listen((data) {
      // TODO
    }, onDone: () {
      close();
    });
  }

  /// Marks the connection handler as no longer active, and ensures that the
  /// delegate stops listening for communications from the specified socket.
  void close() {
    _delegate = null;
    socket.close();
  }
}
