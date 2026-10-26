import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'session.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin client for https://deliveric.net/api_v2/*.php (same backend as the
/// original shipper app 2.1.5).
class Api {
  /// On the web build, calls go to the same origin; server.js proxies /api_v2 to
  /// deliveric.net (browsers block direct calls because of CORS).
  static String get base => kIsWeb ? '${Uri.base.origin}/api_v2/' : 'https://deliveric.net/api_v2/';
  static const mediaBase = 'https://deliveric.net/';

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (Session.I.token != null) 'Authorization': 'Bearer ${Session.I.token}',
        'Accept-Language': Session.I.locale.languageCode,
      };

  static dynamic _decode(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiException('Unexpected response (${r.statusCode})');
    }
    if (r.statusCode == 401) {
      Session.I.logout();
      throw ApiException('Session expired');
    }
    if (body is Map && (body['status'] == false || body['success'] == false)) {
      throw ApiException('${body['message'] ?? body['msg'] ?? 'Request failed'}');
    }
    if (body is Map && body['errors'] is List && (body['errors'] as List).isNotEmpty) {
      final e = (body['errors'] as List).first;
      throw ApiException(e is Map ? '${e['message'] ?? e['code']}' : '$e');
    }
    return body;
  }

  static Future<dynamic> get(String path, [Map<String, String>? q]) async {
    final uri = Uri.parse('$base$path').replace(
      queryParameters: {
        ...Uri.parse('$base$path').queryParameters,
        if (q != null) ...q,
      },
    );
    return _decode(await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30)));
  }

  /// The original app posts JSON bodies (Content-Type application/json).
  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    return _decode(await http
        .post(Uri.parse('$base$path'),
            headers: {..._headers, 'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 30)));
  }

  /// The backend wraps lists under different keys; find the first list.
  static List<Map<String, dynamic>> listOf(dynamic body) {
    dynamic v = body;
    if (v is Map) {
      for (final k in ['data', 'shipments', 'items', 'result', 'results', 'transactions', 'statuses']) {
        if (v[k] is List) {
          v = v[k];
          break;
        }
        if (v[k] is Map) {
          final inner = listOf(v[k]);
          if (inner.isNotEmpty) return inner;
        }
      }
    }
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  static String pick(Map m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && '$v'.isNotEmpty && '$v' != 'null') return '$v';
    }
    return fallback;
  }
}
