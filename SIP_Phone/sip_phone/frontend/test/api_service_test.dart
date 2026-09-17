import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sip_phone/api_service.dart';

void main() {
  test('logs in and loads at most ten recent calls', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(jsonEncode({
          'token': 'test-token',
          'user': {'name': 'Alex Morgan', 'email': 'alex@example.com', 'extension': '204'},
        }), 200);
      }
      if (request.url.path.endsWith('/calls')) {
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {'destination': '5551234'});
        return http.Response(jsonEncode({'ok': true}), 201);
      }
      if (request.url.path.endsWith('/calls/recent')) {
        return http.Response(jsonEncode({
          'calls': List.generate(12, (index) => {
            'name': 'Caller $index',
            'time': 'Today',
            'direction': 'incoming',
          }),
        }), 200);
      }
      return http.Response('{}', 404);
    });

    final api = SipPhoneApi(client: client);
    final user = await api.login(name: 'Alex Morgan', extension: '204', email: 'alex@example.com', password: 'pass');
    await api.recordCall(user.token, '5551234');
    final calls = await api.recentCalls(user.token);

    expect(user.name, 'Alex Morgan');
    expect(user.extension, '204');
    expect(user.token, 'test-token');
    expect(calls, hasLength(10));
    expect(calls.first.name, 'Caller 0');
  });
}
