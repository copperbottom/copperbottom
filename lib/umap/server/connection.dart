import 'dart:io';
import 'dart:typed_data';

import 'package:copperbottom/pubspec.dart';
import 'package:copperbottom/umap/delegate.dart';
import 'package:copperbottom/umap/server/server.dart';
import 'package:copperbottom/umap/umap.dart';

/// A delegate responsible for handling communications with one individual
/// client socket.
class ConnectionHandler {
  /// The server that this connection handler belongs to.
  final UmapServer server;

  /// The socket that this connection handler is responsible for handling.
  final Socket socket;

  /// Whether the socket connection is active.
  bool get isActive => _delegate != null;

  /// The constructor tear-off that generates a delegate for the socket
  /// connection.
  final UmapDelegate Function() delegateBuilder;

  /// The delegate responsible for performing application functions based on
  /// requests.
  UmapDelegate? _delegate;

  /// Initializes a connection handler responsible for dealing with
  /// communications with the specified socket only.
  ConnectionHandler({
    required this.socket,
    required this.server,
    required this.delegateBuilder,
  });

  /// Marks this connection handler delegate as active, and begins listening
  /// for communications from the socket that was assigned to this connection
  /// handler.
  void accept() {
    _delegate = delegateBuilder();

    socket.listen((Uint8List packet) {
      // If the packet was rejected because it was an HTTP packet, don't bother
      // processing it.
      if (_rejectHTTP(packet)) return;

      // TODO
    });
  }

  /// Marks the connection handler as no longer active, and ensures that the
  /// delegate stops listening for communications from the specified socket.
  void close() {
    _delegate = null;
    socket.close();
  }

  /// Checks if a given packet of bytes is an HTTP packet. If it is, it returns
  /// an HTTP response that redirects the user to the web interface.
  /// Other implementations may, instead, return a message saying that HTTP
  /// requests are not supported over UMAP.
  ///
  /// If the packet was an HTTP packet, this method returns true to indicate
  /// that the packet was rejected (per the name) and that it should not be
  /// processed any further.
  bool _rejectHTTP(Uint8List packet) {
    String payload = String.fromCharCodes(packet);

    // If the packet *was* an HTTP request, then the first line would be the
    // request line.
    String requestLine = payload.split('\n')[0];

    // We'll grab the last space-delimited string (which for an HTTP packet
    // would be the protocol version.)
    String maybeProtocol = requestLine.split(' ').last;

    // If the maybeProtocol line ends with HTTP/1.1, then we can recognize this
    // as an HTTP request that we can respond to accordingly and then reject.
    // Otherwise, we'll mark the packet as NOT rejected, meaning it can be
    // processed as a UMAP packet.
    //
    // (We append a carriage return to the string to check because HTTP/1.1
    // appears at the end of the request line and properly formed HTTP packets
    // use a carriage return AND line feed ending.)
    //
    // The goal here is not to serve as a global 'catch-all' for HTTP packets,
    // rather to redirect the majority of erroneous browser requests that are
    // made to the UMAP port.
    if (!maybeProtocol.endsWith('HTTP/1.1\r')) return false;

    // Generate the HTTP response content based on whether or not an interface
    // URL was set.
    String responseText = server.httpInterfaceUrl != null
        ? '<p>Please <a href="${server.httpInterfaceUrl}">click here</a> if you are not redirected.</p>'
            '<script>window.location.href="${server.httpInterfaceUrl}";</script>'
        : '<p>Invalid protocol. This is not an HTTP service.</p>';

    // Write the response line and protocol information headers.
    socket.writeln('HTTP/1.1 301 Invalid Protocol');
    socket.writeln('Connection: close');
    socket.writeln('X-Protocol: umap');
    socket.writeln('X-Protocol-Version: $kUmapProtocolVersion');
    socket.writeln('X-Protocol-Application: https://github.com/SamJakob/copperbottom');
    socket.writeln('X-Protocol-Application-Version: ${Pubspec.versionFull}+${Pubspec.versionBuild}');

    // If the httpInterfaceUrl was set, add a redirect header
    if (server.httpInterfaceUrl != null) socket.writeln('Location: ${server.httpInterfaceUrl}');

    // Additionally, add content-type headers for the response body, followed
    // by the response body itself.
    socket.writeln('Content-Type: text/html');
    socket.writeln('Content-Length: ${responseText.length}');
    socket.writeln('\n');
    socket.writeln(responseText);

    close();
    return true;
  }
}
