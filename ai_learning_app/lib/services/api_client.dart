import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════
// CONFIGURATION
// ══════════════════════════════════════════

class ApiConfig {
  // ── HOW TO FIND YOUR PC IP ──
  // Run in CMD: ipconfig
  // Look for "IPv4 Address" under your WiFi adapter
  // Example: 192.168.1.5
  // Your phone and PC must be on the SAME WiFi network

  static const String _localIp ='192.168.1.7'; // ← change to your PC IPv4
  static const String devUrl = 'http://$_localIp:5000';
  static const String prodUrl =
      'https://your-app.railway.app'; // ← change when deployed

  static const bool isProduction = false;
  static String get baseUrl => isProduction ? prodUrl : devUrl;
}

// ══════════════════════════════════════════
// TOKEN MANAGER
// ══════════════════════════════════════════

class TokenManager {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

// ══════════════════════════════════════════
// API EXCEPTION
// ══════════════════════════════════════════

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// ══════════════════════════════════════════
// BASE API CLIENT
// ══════════════════════════════════════════

class ApiClient {
  static final String _base = ApiConfig.baseUrl;

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await TokenManager.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic> _parse(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return body;
      final message = body['message'] ?? 'Something went wrong';
      throw ApiException(message, statusCode: res.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to parse response: ${res.body}',
          statusCode: res.statusCode);
    }
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$_base$path');
      if (queryParams != null) uri = uri.replace(queryParameters: queryParams);
      final res = await http
          .get(uri, headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 15));
      return _parse(res);
    } on SocketException {
      throw ApiException(
          'No internet connection. Check your network or server IP.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('GET error: $e');
    }
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 60));
      return _parse(res);
    } on SocketException {
      throw ApiException(
          'No internet connection. Check your network or server IP.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('POST error: $e');
    }
  }

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _parse(res);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('PUT error: $e');
    }
  }

  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base$path'),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _parse(res);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('PATCH error: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base$path'), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 30));
      return _parse(res);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('DELETE error: $e');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required File file,
    required String fileField,
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    try {
      final token = auth ? await TokenManager.getToken() : null;
      final request = http.MultipartRequest('POST', Uri.parse('$_base$path'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (fields != null) request.fields.addAll(fields);
      request.files
          .add(await http.MultipartFile.fromPath(fileField, file.path));
      final streamed =
          await request.send().timeout(const Duration(seconds: 120));
      final res = await http.Response.fromStream(streamed);
      return _parse(res);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Upload error: $e');
    }
  }

  static Stream<String> streamPost(
    String path, {
    Map<String, dynamic>? body,
  }) async* {
    try {
      final token = await TokenManager.getToken();
      final client = http.Client();
      final request = http.Request('POST', Uri.parse('$_base$path'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);

      final response = await client.send(request);
      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data: ')) {
            final data = trimmed.substring(6);
            if (data.isEmpty || data == '[DONE]') continue;
            try {
              final parsed = jsonDecode(data) as Map<String, dynamic>;
              if (parsed['chunk'] != null) {
                yield parsed['chunk'] as String;
              } else if (parsed['done'] == true) {
                return;
              } else if (parsed['error'] != null) {
                throw ApiException(parsed['error'] as String);
              }
            } catch (_) {}
          }
        }
      }
      client.close();
    } on SocketException {
      throw ApiException('No internet connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Stream error: $e');
    }
  }
}
