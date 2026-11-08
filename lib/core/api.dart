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
      for (final k in ['data', 'shipments', 'items', 'result', 'results', 'transactions', 'statuses', 'sectors', 'service_types', 'stores']) {
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

  /// Raw server reply as text (used by the debug screen).
  static Future<String> raw(String path, [Map<String, String>? q]) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: q);
    final r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
    return 'HTTP ${r.statusCode}\n${utf8.decode(r.bodyBytes)}';
  }

  // ---- field names taken from the original app's models ----
  static String code(Map s) => pick(s, ['waybill', 'order_id', 'id']);
  static String name(Map s) => pick(s, ['client_name']);
  static String phone(Map s) => pick(s, ['phone_1', 'phone_2']);
  static String cod(Map s) => pick(s, ['costing'], '0');
  static String area(Map s) => pick(s, ['sector_name', 'address']);
  static String status(Map s) {
    final ar = Session.I.locale.languageCode == 'ar';
    return ar
        ? pick(s, ['status_ar', 'status_en', 'status'])
        : pick(s, ['status_en', 'status_ar', 'status']);
  }
  static double num(String v) => double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;

  static String pick(Map m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && '$v'.isNotEmpty && '$v' != 'null') return '$v';
    }
    return fallback;
  }
}
