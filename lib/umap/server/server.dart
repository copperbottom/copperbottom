import 'dart:async';
import 'dart:io';

import 'package:copperbottom/umap/delegate.dart';
import 'package:copperbottom/umap/server/connection.dart';
import 'package:copperbottom/umap/umap.dart';

import 'connection.dart';

/// The core UMAP server implementation for Copperbottom.
/// This server allows for communication with UMAP clients.
class UmapServer {
  /// The delegate that handles tasks initiated by UMAP requests.
  final UmapDelegate Function() delegateBuilder;

  /// The URL of the HTTP interface that a user should be redirect to, if an
  /// HTTP request is made on the UMAP port.
  final String? httpInterfaceUrl;

  /// The Dart IO TCP [ServerSocket] that handles incoming requests from IPv4.
  ServerSocket? _v4Socket;

  /// The Dart IO TCP [ServerSocket] that handles incoming requests from IPv6.
  ServerSocket? _v6Socket;

  /// The unified streams for v4 and v6 sockets.
  StreamController<Socket>? _socketStreams;

  /// Returns the stream of new socket connections, if the server is running.
  /// Otherwise, returns null.
  get socketStreams => _socketStreams?.stream;

  /// The port number that the [UmapServer] is listening on.
  final int port;

  /// Private constructor for internal use.
  UmapServer._construct({
    required this.port,
    required this.httpInterfaceUrl,
    required this.delegateBuilder,
  });

  /// Initializes and starts a [UmapServer], returning the created [UmapServer]
  /// instance. If specified, [port] will be the port that the server listens
  /// on.
  static Future<UmapServer> start({
    int? port = kUmapPortDefault,
    String? httpInterfaceUrl,
    required UmapDelegate Function() delegateBuilder,
  }) async {
    // Initialize an empty UmapServer and create a stream controller to manage
    // the incoming v4 and v6 socket connections.
    final server = UmapServer._construct(
      port: port ?? kUmapPortDefault,
      httpInterfaceUrl: httpInterfaceUrl,
      delegateBuilder: delegateBuilder,
    );
    server._socketStreams = StreamController();

    // Create the server sockets for both v4 and v6 IP, piping new socket
    // connections from both into the combined stream.
    server._v4Socket = await ServerSocket.bind(InternetAddress.anyIPv4, server.port)
      ..listen((client) => server._socketStreams!.sink.add(client));
    server._v6Socket = await ServerSocket.bind(InternetAddress.anyIPv6, server.port)
      ..listen((client) => server._socketStreams!.sink.add(client));

    // Open both socket streams immediately, and set up the connection handler
    // to accept new socket connections.
    server._socketStreams!.stream.listen(
      (socket) => ConnectionHandler(
        socket: socket,
        server: server,
        delegateBuilder: delegateBuilder,
      ).accept(),
    );

    return server;
  }

  /// Closes all streams, shuts down the socket servers and cleans up.
  Future<void> stop() async {
    await _socketStreams?.close();
    await _v4Socket?.close();
    await _v6Socket?.close();

    _socketStreams = null;
    _v4Socket = null;
    _v6Socket = null;
  }
}
