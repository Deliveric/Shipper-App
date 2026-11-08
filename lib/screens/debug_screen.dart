import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/download_stub.dart' if (dart.library.html) '../core/download_web.dart';
import '../core/session.dart';
import '../core/theme.dart';

/// API recorder: calls the read-only endpoints and saves the FULL replies
/// (nothing masked, nothing shortened) as JSON files you can download.
/// Only the sign-in token is left out. Nothing here changes data.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _Call {
  final String path;
  final Map<String, String> q;
  final Map<String, dynamic>? body;
  const _Call(this.path, [this.q = const {}, this.body]);
}

class _Part {
  final String title;
  final String file;
  String status = 'waiting';
  String? json;
  _Part(this.title, this.file);
}

class _DebugScreenState extends State<DebugScreen> {
  static const small = <_Call>[
    _Call('user_info.php'),
    _Call('my_shipments.php', {'general_status': 'delivere', 'count': '1'}),
    _Call('shipment.php', {}, {'id': '{ID}', 'app': 'shipper'}),
    _Call('shipment_statuses.php'),
    _Call('get_shipper_filter_statuses.php'),
    _Call('statusDashboard.php'),
    _Call('getShipperBalance.php'),
    _Call('transactions_sum.php'),
    _Call('get_withdrawable_amount.php'),
    _Call('notifications.php'),
    _Call('filterData.php'),
    _Call('get_stores.php'),
    _Call('sectors.php'),
    _Call('service_types.php'),
    _Call('get_reasons.php'),
    _Call('get_company_data.php'),
    _Call('get_whats_templates.php'),
    _Call('get_request_data.php'),
    _Call('get_shippers.php'),
    _Call('get_task_types.php'),
    _Call('get_tasks.php'),
    _Call('my_chat.php'),
  ];

  final parts = <_Part>[
    _Part('Everything except the long lists', 'shipper-api-small.json'),
    _Part('All shipments', 'shipper-api-shipments.json'),
    _Part('Returned shipments', 'shipper-api-returned.json'),
    _Part('All transactions', 'shipper-api-transactions.json'),
  ];
  String? firstId;
  bool running = true;

  Map<String, String> get _hdr => {
        'Accept': 'application/json',
        if (Session.I.token != null) 'Authorization': 'Bearer ${Session.I.token}',
        'Accept-Language': Session.I.locale.languageCode,
      };

  Uri _uri(String path, Map<String, String> q) =>
      Uri.parse('${Api.base}$path').replace(queryParameters: q.isEmpty ? null : q);

  String _shown(Uri u) => u.toString().replaceAll(Uri.base.origin, 'https://deliveric.net');

  Future<http.Response> _get(Uri u, {Map<String, dynamic>? body}) async {
    Object? err;
    for (var i = 0; i < 3; i++) {
      try {
        final h = {..._hdr, if (body != null) 'Content-Type': 'application/json; charset=utf-8'};
        final f = body == null ? http.get(u, headers: h) : http.post(u, headers: h, body: jsonEncode(body));
        return await f.timeout(const Duration(minutes: 5));
      } catch (e) {
        err = e;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw err!;
  }

  bool _isJson(String s) {
    final t = s.trimLeft();
    return t.startsWith('{') || t.startsWith('[');
  }

  /// one entry of the report; the reply text is spliced in unchanged
  String _entry(String method, Uri u, Map<String, dynamic>? body, http.Response r, int ms) {
    final text = utf8.decode(r.bodyBytes);
    final meta = {
      'method': method,
      'url': _shown(u),
      if (body != null) 'request_body': body,
      'status': r.statusCode,
      'content_type': r.headers['content-type'],
      'ms': ms,
    };
    final m = jsonEncode(meta);
    final resp = _isJson(text) ? text : jsonEncode(text);
    return '${m.substring(0, m.length - 1)},"response":$resp}';
  }

  String _wrap(List<String> entries) =>
      '{"base_url":"https://deliveric.net/api_v2/","recorded_at":"${DateTime.now().toIso8601String()}","calls":[${entries.join(',')}]}';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await _runSmall();
      await _runPaged(parts[1], 'my_shipments.php', {'general_status': 'delivere', 'lang': 'en'}, 'shipments');
      await _runPaged(parts[2], 'returned_shipments.php', {}, 'returned_shipment');
      await _runTx();
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Future<void> _runSmall() async {
    final p = parts[0];
    final out = <String>[];
    for (var i = 0; i < small.length; i++) {
      final c = small[i];
      final q = Map<String, String>.from(c.q);
      final body = c.body == null ? null : Map<String, dynamic>.from(c.body!);
      if (body != null && body['id'] == '{ID}') {
        if (firstId == null) continue;
        body['id'] = firstId;
      }
      final u = _uri(c.path, q);
      p.status = '${c.path} (${i + 1}/${small.length})';
      if (mounted) setState(() {});
      try {
        final sw = Stopwatch()..start();
        final r = await _get(u, body: body);
        out.add(_entry(body == null ? 'GET' : 'POST', u, body, r, sw.elapsedMilliseconds));
      } catch (e) {
        out.add(jsonEncode({'method': body == null ? 'GET' : 'POST', 'url': _shown(u), 'error': '$e'}));
      }
      if (c.path == 'my_shipments.php' && firstId == null) {
        // first shipment id, used for the shipment detail call
        try {
          final r = await _get(_uri('my_shipments.php', {'general_status': 'delivere', 'start': '0', 'limit': '1', 'lang': 'en'}));
          final l = Api.listOf(jsonDecode(utf8.decode(r.bodyBytes)));
          if (l.isNotEmpty) firstId = '${l.first['id']}';
        } catch (_) {}
      }
    }
    var json = _wrap(out);
    // sign-in secrets inside the profile reply are not exported
    json = json.replaceAllMapped(RegExp(r'"(password|sms_password)":"[^"]*"'), (m) => '"${m[1]}":"(not exported)"');
    p.json = json;
    p.status = 'ready (${(json.length / 1024).round()} KB)';
    if (mounted) setState(() {});
  }

  Future<void> _runPaged(_Part p, String path, Map<String, String> base, String key) async {
    const page = 1000;
    final out = <String>[];
    var start = 0, total = 0;
    while (true) {
      p.status = 'loaded $total…';
      if (mounted) setState(() {});
      final u = _uri(path, {...base, 'start': '$start', 'limit': '$page'});
      try {
        final sw = Stopwatch()..start();
        final r = await _get(u);
        final text = utf8.decode(r.bodyBytes);
        final j = jsonDecode(text);
        final list = j is Map && j[key] is List ? j[key] as List : <dynamic>[];
        out.add(_entry('GET', u, null, r, sw.elapsedMilliseconds));
        total += list.length;
        if (list.length < page) break;
        start += page;
      } catch (e) {
        out.add(jsonEncode({'method': 'GET', 'url': _shown(u), 'error': '$e'}));
        break;
      }
    }
    p.json = _wrap(out);
    p.status = 'ready: $total rows (${(p.json!.length / 1024 / 1024).toStringAsFixed(1)} MB)';
    if (mounted) setState(() {});
  }

  Future<void> _runTx() async {
    final p = parts[3];
    p.status = 'loading (this can take a minute)…';
    if (mounted) setState(() {});
    final u = _uri('my_transactions.php', {});
    try {
      final sw = Stopwatch()..start();
      final r = await _get(u);
      p.json = _wrap([_entry('GET', u, null, r, sw.elapsedMilliseconds)]);
      p.status = 'ready (${(p.json!.length / 1024 / 1024).toStringAsFixed(1)} MB)';
    } catch (e) {
      p.status = 'failed: $e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save(_Part p) async {
    final ok = await downloadText(p.file, p.json!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Downloading ${p.file}' : 'Downloads work in the web version. Open the app on Render in your browser.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API recorder')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (running) const LinearProgressIndicator(color: Brand.orange),
        const SizedBox(height: 8),
        const Text(
          'Saves the full replies of the read-only endpoints. Nothing is masked or shortened; only your sign-in token is left out. Keep the files private. Wait until each line says ready, then download it and send it in the chat.',
          style: TextStyle(color: Brand.muted),
        ),
        const SizedBox(height: 12),
        for (final p in parts)
          Card(
            child: ListTile(
              title: Text(p.title),
              subtitle: Text(p.status, style: const TextStyle(color: Brand.muted)),
              trailing: p.json == null
                  ? null
                  : IconButton(icon: const Icon(Icons.download, color: Brand.orange), onPressed: () => _save(p)),
            ),
          ),
      ]),
    );
  }
}
