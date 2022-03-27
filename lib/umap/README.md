# Copperbottom UMAP
The UMAP library of the Copperbottom application.

This library is responsible for handling UMAP communications
with the Copperbottom application server, allowing UMAP clients
to make requests.

## Usage
All UMAP protocol requests are implemented in `delegate.dart`.
Simply implement all the abstract methods in a class that extends
the UmapDelegate class and pass that to the Umap server when you
start it.