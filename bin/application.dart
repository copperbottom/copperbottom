import 'dart:io';

import 'package:copperbottom/app/database/adapters/postgres.dart';
import 'package:copperbottom/app/database/database.dart';
import 'package:copperbottom/app/struct/user.dart';
import 'package:copperbottom/app/umap.dart';
import 'package:copperbottom/app/websocket.dart';
import 'package:copperbottom/websocket/server/server.dart';
import 'package:copperbottom/umap/server/server.dart';
import 'package:logger/logger.dart';
import 'package:yaml/yaml.dart';

/// Prepares the database adapter for Copperbottom based on the database
/// section of the configuration file.
Future<CDBAdapter> prepareAdapter(Map databaseConfig) {
  switch (databaseConfig['type']) {
    // If the database type is 'postgresql' or 'postgres', use the
    // CDBPostgresAdapter.
    case 'postgresql':
    case 'postgres':
      {
        // Check the necessary parameters.
        bool hostnameMissing = !databaseConfig.containsKey('hostname') || databaseConfig['hostname'] == null;
        bool databaseMissing = !databaseConfig.containsKey('database') || databaseConfig['database'] == null;
        bool usernameMissing = !databaseConfig.containsKey('username') || databaseConfig['username'] == null;
        bool passwordMissing = !databaseConfig.containsKey('password') || databaseConfig['password'] == null;

        // If any are missing, print them in the error accordingly.
        if (hostnameMissing || databaseMissing || usernameMissing || passwordMissing) {
          throw ArgumentError(
            'To use the PostgreSQL driver, you must specify all of the following in your database configuration:\n' +
                (hostnameMissing ? '- hostname\n' : '') +
                (databaseMissing ? '- database\n' : '') +
                (usernameMissing ? '- username\n' : '') +
                (passwordMissing ? '- password\n' : ''),
          );
        }

        // Finally, connect to the database server.
        return CDBPostgresAdapter.connect(
          hostname: databaseConfig['hostname'],
          port: databaseConfig['port'],
          database: databaseConfig['database'],
          username: databaseConfig['username'],
          password: databaseConfig['password'],
        );
      }

    // Otherwise, throw an error indicating that we do not currently support
    // the specified adapter type.
    default:
      throw UnimplementedError(
        "The specified database type, ${databaseConfig['type']} is not currently supported.",
      );
  }
}

Future<void> main(List<String> arguments) async {
  // Initialize logging.
  var logger = Logger(printer: SimplePrinter(printTime: true));
  logger.i("Initializing...");

  // Read the system configuration.
  var config = loadYaml(await File('config.yaml').readAsString()) as Map;
  Map serverConfig = (config['server'] ?? {}) as Map;
  int? port = serverConfig['port'];

  // Initialize database driver.
  final CopperbottomDatabase database;
  try {
    // Check that the database configuration section exists.
    if (!config.containsKey('database')) {
      throw Exception('The database configuration section is missing.');
    }

    // If it does, initialize the database module with the appropriate adapter.
    database = CopperbottomDatabase.fromAdapter(
      adapter: await prepareAdapter(config['database']),
    );
  } catch (ex) {
    logger.e("Failed to connect to the database.", ex);
    return;
  }

  try {
    // Register application database tables.
    await database.registerTable(
      deserializer: User.deserialize,
      fields: User.fields,
    );
  } catch (ex) {
    database.close();
    logger.e("A database error occurred.", ex);
    return;
  }

  // Start mail server communications.
  UmapServer umapServer = await UmapServer.start(
    port: port,
    httpInterfaceUrl: serverConfig['redirect_uri'],
    delegateBuilder: CopperbottomUmapDelegate.new,
  );
  logger.i("Listening for UMAP traffic on port ${umapServer.port}...");

  // Start WebSocket server communications.
  WebSocketServer webSocketServer = await WebSocketServer.start(
    port: port,
    httpInterfaceUrl: serverConfig['redirect_uri'],
    delegateBuilder: CopperbottomWebSocketDelegate.new,
  );
  logger.i(
    "Listening for WebSocket traffic on port ${webSocketServer.port}...",
  );

  // Indicate that we're ready for connections.
  logger.i("Ready!");
}
