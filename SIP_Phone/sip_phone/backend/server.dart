import 'dart:convert';
import 'dart:io';

const port = 8080;

final users = <String, Map<String, String>>{};
final sessions = <String, Map<String, String>>{};

final recentCalls = <Map<String, String>>[];

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  await for (final request in server) {
    await _handle(request);
  }
}

Future<void> _handle(HttpRequest request) async {
  request.response.headers
    ..contentType = ContentType.json
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Headers', 'Content-Type, Authorization')
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  try {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/health') {
      await _send(request, HttpStatus.ok, {
        'ok': true,
        'service': 'sip-phone-api',
      });
      return;
    }
    if (request.method == 'POST' && path == '/api/auth/login') {
      await _login(request);
      return;
    }
    if (request.method == 'POST' && path == '/api/auth/logout') {
      final token = _token(request);
      sessions.remove(token);
      await _send(request, HttpStatus.ok, {'ok': true});
      return;
    }
    if (request.method == 'GET' && path == '/api/calls/recent') {
      if (!_authenticated(request)) {
        await _send(request, HttpStatus.unauthorized, {
          'error': 'Authentication required',
        });
        return;
      }
      await _send(request, HttpStatus.ok, {
        'calls': recentCalls.take(10).toList(),
      });
      return;
    }
    if (request.method == 'POST' && path == '/api/calls') {
      await _recordCall(request);
      return;
    }
    await _send(request, HttpStatus.notFound, {'error': 'Route not found'});
  } catch (error) {
    await _send(request, HttpStatus.badRequest, {'error': error.toString()});
  }
}

Future<void> _login(HttpRequest request) async {
  final body = jsonDecode(
    await utf8.decoder.bind(request).join(),
  ) as Map<String, dynamic>;
  final password = body['password'] as String? ?? '';
  final extension = (body['extension'] as String? ?? '').trim();
  if (extension.isEmpty) {
    await _send(request, HttpStatus.unprocessableEntity, {
      'error': 'Extension is required',
    });
    return;
  }

  users[extension] = {'extension': extension};
  final token = '${DateTime.now().microsecondsSinceEpoch}-$extension';
  sessions[token] = users[extension]!;
  await _send(request, HttpStatus.ok, {
    'token': token,
    'user': users[extension],
  });
}

Future<void> _recordCall(HttpRequest request) async {
  final session = sessions[_token(request)];
  if (session == null) {
    await _send(request, HttpStatus.unauthorized, {
      'error': 'Authentication required',
    });
    return;
  }

  final body = jsonDecode(
    await utf8.decoder.bind(request).join(),
  ) as Map<String, dynamic>;
  final destination = (body['destination'] as String? ?? '').trim();
  if (destination.isEmpty) {
    await _send(request, HttpStatus.unprocessableEntity, {
      'error': 'A destination number is required',
    });
    return;
  }

  recentCalls.insert(0, {
    'name': destination,
    'time':
        '${DateTime.now().toLocal()} from extension ${session['extension']}',
    'direction': 'outgoing',
  });
  await _send(request, HttpStatus.created, {'ok': true});
}

String _token(HttpRequest request) =>
    request.headers.value('authorization')?.replaceFirst('Bearer ', '') ?? '';
bool _authenticated(HttpRequest request) =>
    sessions.containsKey(_token(request));

Future<void> _send(
  HttpRequest request,
  int status,
  Map<String, dynamic> body,
) async {
  request.response.statusCode = status;
  request.response.write(jsonEncode(body));
  await request.response.close();
}
