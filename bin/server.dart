import 'dart:io';

import 'package:ambience/server/provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

final httpClient = http.Client();

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  Response _cors(Response response) => response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token',
      });

  var _fixCORS = createMiddleware(responseHandler: _cors);

  // Configure a pipeline that logs requests.
  final _handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_fixCORS)
      .addHandler(_router);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '7070');
  final server = await serve(_handler, ip, port);
  print('Server listening on port ${server.port}');
}

String getMimeType(File f) {
  switch (path.extension(f.path)) {
    case '.html':
      return 'text/html';
    case '.css':
      return 'text/css';
    case '.js':
      return 'text/javascript';
    case '.mp3':
      return 'audio/mpeg';
    case '.wav':
      return 'audio/wav';
  }
  return 'text/plain';
}

Future<Response> _router(Request request) async {
  var path = request.url.path;

  if (path.isEmpty || path == 'home') {
    path = 'index.html';
  } else if (path == 'audio') {
    return _audioHandler(request);
  }

  var file = File((path.startsWith('resources') ? '' : 'web/') + path);

  if (await file.exists()) {
    var type = getMimeType(file);
    return Response(
      200,
      body: file.openRead(),
      headers: {'Content-Type': type},
    );
  }

  return Response.notFound('Request for "${request.url}"');
}

Future<Response> _audioHandler(Request request) async {
  var info =
      await AudioInfo.fromUrl('https://www.youtube.com/watch?v=t8MC135MwdE');
  var response = await httpClient.send(http.Request(
    'GET',
    Uri.parse(info.audioUrl),
  ));

  return Response.ok(response.stream);
}
