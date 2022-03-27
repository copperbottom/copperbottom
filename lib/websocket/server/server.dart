import 'dart:io';

import 'package:copperbottom/websocket/delegate.dart';
import 'package:copperbottom/websocket/server/connection.dart';
import 'package:copperbottom/pubspec.dart';
import 'package:copperbottom/websocket/websocket.dart';

/// The WebSocket server implementation for Copperbottom.
/// This server allows for communication with WebSocket clients and serves
/// as a proprietary gateway API between Copperbottom and a web-based client
/// for Copperbottom.
class WebSocketServer {
  /// The delegate that handles tasks initiated by WebSocket requests.
  final WebSocketDelegate Function() delegate;

  /// The port number that the [WebSocketServer] is listening on.
  final int port;

  /// The internal [HttpServer] that handles incoming HTTP requests on the
  /// WebSocket port.
  HttpServer? _httpServer;

  /// The list of current connections to the WebSocket server.
  final List<WebSocket> connections;

  /// Private constructor for internal use.
  WebSocketServer._construct({
    required this.port,
    required this.delegate,
  }) : connections = [];

  static Future<WebSocketServer> start({
    int? port,
    String? httpInterfaceUrl,
    required WebSocketDelegate Function() delegateBuilder,
  }) async {
    var server = WebSocketServer._construct(
      port: port ?? kWebSocketPortDefault,
      delegate: delegateBuilder,
    );

    server._httpServer = await HttpServer.bind('0.0.0.0', server.port);
    server._httpServer!.listen((HttpRequest request) async {
      // If the request is a valid WebSocket upgrade request, upgrade the
      // request and hand the WebSocket connection over to the delegate.
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then((WebSocket ws) {
          // Listen only for the done event to remove the WebSocket from the
          // current connections list.
          ws.listen(null, onDone: () {
            server.connections.remove(ws);
          });

          // Now start a new delegate to handle the WebSocket connection.
          ConnectionHandler(
            socket: ws,
            server: server,
            delegateBuilder: delegateBuilder,
          ).accept();

          // Finally, add the socket to the list of current connections.
          server.connections.add(ws);
        });
      }
      // Otherwise, redirect the user to the HTTP Interface URL (if it was
      // specified, displaying an error if it wasn't.)
      else {
        // Generate the HTTP response content based on whether or not an interface
        // URL was set.
        String responseText = httpInterfaceUrl != null
            ? '<p>Please <a href="$httpInterfaceUrl">click here</a> if you are not redirected.</p>'
                '<script>window.location.href="$httpInterfaceUrl";</script>'
            : '<p>Invalid protocol. This is not an HTTP service.</p>';

        // Write the response line and protocol information headers.
        request.response.statusCode = 301;
        request.response.headers.add('Connection', 'close');
        request.response.headers.add('X-Protocol-Application', 'https://github.com/SamJakob/copperbottom');
        request.response.headers.add('X-Protocol-Application-Version', '${Pubspec.versionFull}+${Pubspec.versionBuild}');

        // If the httpInterfaceUrl was set, add a redirect header
        if (httpInterfaceUrl != null) request.response.headers.add('Location', httpInterfaceUrl);

        // Additionally, add content-type headers for the response body, followed
        // by the response body itself.
        request.response.headers.add('Content-Type', 'text/html');
        request.response.writeln(responseText);
        await request.response.close();
      }
    });

    return server;
  }
}
