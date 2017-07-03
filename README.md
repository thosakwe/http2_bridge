# http2_bridge
[![Pub](https://img.shields.io/pub/v/http2_bridge.svg)](https://pub.dartlang.org/packages/http2_bridge)

Handle HTTP/2 requests as if they were dart:io HttpRequests.

This package is currently in alpha, mainly because I have no practical idea of how to test it.
Stay tuned.

# Usage
Use the `adaptHttp2Stream` function to bridge HTTP/2 requests to an existing HTTP/1.1 handler.

```dart
import 'dart:io';
import 'package:http2/multiprotocol_server.dart';
import 'package:http2_bridge/http2_bridge.dart';

main() async {
  var ctx = new SecurityContext();
  ctx.useCertificateChainFile('keys/server_chain.pem');
  ctx.usePrivateKeyFile('keys/server_key.pem');
  var server = await MultiProtocolServer.bind('127.0.0.1', 443, ctx);
  
  server.startServing(
    // Serve HTTP/1.1 as normal
    handleRequest,
    
    // Handle HTTP/2 streams as though they were HTTP/1.1 requests...
    adaptHttp2Stream(handleRequest)
  );
}

handleRequest(HttpRequest request) async {
  // Do something...
}

```