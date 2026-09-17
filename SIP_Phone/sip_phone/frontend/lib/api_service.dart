import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiUser {
  const ApiUser({required this.name, required this.email, required this.extension, required this.token});

  final String name;
  final String email;
  final String extension;
  final String token;
}

class ApiRecentCall {
  const ApiRecentCall({required this.name, required this.time, required this.direction});

  final String name;
  final String time;
  final String direction;

  factory ApiRecentCall.fromJson(Map<String, dynamic> json) => ApiRecentCall(
        name: json['name'] as String? ?? 'Unknown number',
        time: json['time'] as String? ?? '',
        direction: json['direction'] as String? ?? 'missed',
      );
}

class SipPhoneApi {
  SipPhoneApi({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080/api',
  );

  final http.Client _client;

  Future<ApiUser> login({required String name, required String extension, required String email, required String password}) async {
    final response = await _client.post(
      Uri.parse('$_configuredBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'extension': extension, 'email': email, 'password': password}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) throw ApiException(data['error'] as String? ?? 'Unable to sign in');
    final user = data['user'] as Map<String, dynamic>;
    return ApiUser(
      name: user['name'] as String,
      email: user['email'] as String,
      extension: user['extension'] as String,
      token: data['token'] as String,
    );
  }

  Future<void> recordCall(String token, String destination) async {
    final response = await _client.post(
      Uri.parse('$_configuredBaseUrl/calls'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'destination': destination}),
    );
    final data = _decode(response);
    if (response.statusCode != 201) throw ApiException(data['error'] as String? ?? 'Unable to record call');
  }

  Future<List<ApiRecentCall>> recentCalls(String token) async {
    final response = await _client.get(Uri.parse('$_configuredBaseUrl/calls/recent'), headers: {'Authorization': 'Bearer $token'});
    final data = _decode(response);
    if (response.statusCode != 200) throw ApiException(data['error'] as String? ?? 'Unable to load recent calls');
    return (data['calls'] as List<dynamic>).map((item) => ApiRecentCall.fromJson(item as Map<String, dynamic>)).take(10).toList();
  }

  Future<void> logout(String token) async {
    await _client.post(Uri.parse('$_configuredBaseUrl/auth/logout'), headers: {'Authorization': 'Bearer $token'});
  }

  Map<String, dynamic> _decode(http.Response response) => jsonDecode(response.body) as Map<String, dynamic>;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
