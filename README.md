# copperbottom
The open-source UMAP implementation.

- **Dart SDK:** >= 2.16

## Compiling
Before compiling, be sure to update the version information by running:
```bash
pub run pubspec_extract
```

To compile as a self-contained platform-dependent executable, use the
following command:
```bash
dart compile exe bin/application.dart -o dist/application
```

This will compile a standalone architecture-specific executable file
containing the source code compiled to machine code with a small Dart
runtime. On *nix systems, you can then run the executable with
`./dist/application`.

As a fun aside, you can also compile to JavaScript as follows:
```bash
dart compile js bin/application.dart -o dist/application
```

## Directory Structure
This project is conceptually modularized both for readability and to serve as a
good reference for new implementations of the UMAP or Copperbottom's protocols.

This modularization is done by directories and is loosely based around Dart's
library structure with the intention that many of the `lib/` subdirectories
could, later, be divided into distinct Dart libraries.

```bash
bin/
  application.dart  # The executable stub that gets run first to start all the
                    # servers with the application delegates.

lib/
  app/              # Support libraries and logic for the application implementation.
    database/       # Database libraries and APIs for entity-modelling and storage.
      adapters/     # Adapters for specific database-backends.
      database.dart # The abstract API for database operations and entity-modelling.
    shared/         # Logic that may be shared between the UMAP and WebSocket
                    # protocols. (e.g., authentication)
    struct/         # The models (classes) relevant to entities within the
                    # application and protocol.
    umap.dart       # The implementation delegate for UMAP.
    websocket.dart  # The implementation delegate for WebSockets.

  umap/             # A package to facilitate UMAP communications within a Dart
                    # application.
    server/         # Code to facilitate UMAP communications by handling
                    # requests using the appropriate delegate methods.
    delegate.dart   # The abstract specification for UMAP delegates.
    umap.dart       # Contains useful constants for UMAP communications
                    # (such as default ports).
  
  websocket/        # A package to facilitate communications between Copperbottom's
                    # WebSocket API. This structure mimics that of lib/umap.
    server/         # Code to facilitate WebSocket communications by handling
                    # requests using the appropriate delegate methods.
    delegate.dart   # The abstract specification for WebSocket delegates.
    websocket.dart  # Contains useful constants for WebSockets communications
                    # (such as default ports).
  
  pubspec.dart      # Contains version information extracted automatically at
                    # compile time from pubspec.yaml and exposed as Dart
                    # constants.
```