import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http2/transport.dart';
import 'package:mock_request/mock_request.dart';

/// A function that acts upon a [ServerTransportStream].
typedef void ServerTransportStreamHandler(ServerTransportStream stream);

/// Returns a function that adapts data from an HTTP/2 stream into an [HttpRequest] instance and then normalizes the response data.
///
/// Use this to run an existing Dart server as an HTTP/2 server.
ServerTransportStreamHandler adaptHttp2Stream(FutureOr callback(HttpRequest)) {
  return (ServerTransportStream stream) {
    MockHttpRequest rq;
    String method, path, scheme, authority;
    List<List<String>> headerQueue = [];
    List<int> buf = [];

    stream.incomingMessages.listen((msg) {
      if (msg is HeadersStreamMessage) {
        for (var header in msg.headers) {
          var name = UTF8.decode(header.name),
              value = UTF8.decode(header.value);

          if (name == ':method') {
            method = value;
          } else if (name == ':path') {
            path = value;
          } else if (name == ':scheme') {
            scheme = value;
          } else if (name == ':authority') {
            authority = value;
          } else if (rq == null) {
            headerQueue.add([name, value]);
          } else {
            rq.headers.add(name, value);
          }

          // Maybe initialize request
          if (method != null &&
              path != null &&
              scheme != null &&
              authority != null) {
            var uriString = '$scheme://$authority$path';
            var uri = Uri.parse(
                uriString); //new Uri(scheme: scheme, path: path, host: authority);
            rq = new MockHttpRequest(method, uri);
            rq.protocolVersion = '2.0';
            /*rq.connectionInfo = new MockHttpConnectionInfo(
                remoteAddress: client.address,
                remotePort: client.port,
                localPort: socket.port);*/

            // Add queued headers, etc.
            headerQueue.forEach((list) => rq.headers.add(list[0], list[1]));
          }
        }
      } else if (msg is DataStreamMessage) {
        buf.addAll(msg.bytes);
      }
    }, onDone: () async {
      if (rq != null) {
        // Let's push the HTTP/2 request along...
        rq.add(buf);
        rq.close();

        await callback(rq);

        rq.response.done.then((_) {
          // Send headers
          var headers = [
            new Header.ascii(':status', rq.response.statusCode.toString())
          ];
          rq.response.headers.forEach((k, v) {
            headers.add(new Header.ascii(k, v.join(',')));
          });
          stream.sendHeaders(headers);

          rq.response.listen((buf) {
            stream.sendData(buf);
          }, onDone: () {
            return stream.outgoingMessages.close();
          });
        });
      }
    });
  };
}
