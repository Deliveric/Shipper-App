import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';

/// API recorder: calls every read-only endpoint of the shipper API and builds a
/// JSON report (request, status, reply) with personal data masked, so an API
/// document can be written from real examples. Nothing here changes data.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _Call {
  final String path;
  final Map<String, String> q;
  const _Call(this.path, [this.q = const {}]);
}

class _DebugScreenState extends State<DebugScreen> {
  static const calls = <_Call>[
    _Call('user_info.php'),
    _Call('my_shipments.php', {'page': '1', 'limit': '3'}),
    _Call('my_shipments.php', {'page': '1', 'limit': '3', 'general_status': '1'}),
    _Call('shipment.php', {'id': '{ID}'}),
    _Call('shipment_statuses.php'),
    _Call('get_shipper_filter_statuses.php'),
    _Call('statusDashboard.php'),
    _Call('getShipperBalance.php'),
    _Call('transactions_sum.php'),
    _Call('get_withdrawable_amount.php'),
    _Call('my_transactions.php', {'page': '1', 'limit': '3'}),
    _Call('returned_shipments.php', {'page': '1', 'limit': '3'}),
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
    _Call('warehouse_shippers.php'),
    _Call('get_task_types.php'),
    _Call('get_tasks.php'),
    _Call('my_chat.php'),
  ];

  final List<Map<String, dynamic>> report = [];
  bool loading = true;
  String? firstId;

  static final _secretKey = RegExp(r'(name|phone|mobile|address|email|token|password|note|comment|shipper|store|client|merchant|account|iban)', caseSensitive: false);
  static final _longDigits = RegExp(r'\d{9,}');
  static final _mail = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');

  dynamic _mask(dynamic v, [String key = '']) {
    if (v is Map) return v.map((k, x) => MapEntry(k, _mask(x, '$k')));
    if (v is List) return v.map((x) => _mask(x, key)).toList();
    if (v is String) {
      if (v.isNotEmpty && _secretKey.hasMatch(key) && !RegExp(r'(status|type|count|id$)', caseSensitive: false).hasMatch(key)) {
        return '«masked»';
      }
      return v.replaceAll(_mail, '«email»').replaceAll(_longDigits, '«number»');
    }
    return v;
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (final c in calls) {
      final q = Map<String, String>.from(c.q);
      if (q.containsValue('{ID}')) {
        if (firstId == null) continue;
        q.updateAll((k, v) => v == '{ID}' ? firstId! : v);
      }
      final uri = Uri.parse('${Api.base}${c.path}').replace(queryParameters: q.isEmpty ? null : q);
      final entry = <String, dynamic>{
        'method': 'GET',
        'url': uri.toString().replaceAll(Uri.base.origin, 'https://deliveric.net'),
        'request_headers': {
          'Accept': 'application/json',
          'Authorization': 'Bearer «token»',
          'Accept-Language': Session.I.locale.languageCode,
        },
      };
      final sw = Stopwatch()..start();
      try {
        final r = await http.get(uri, headers: {
          'Accept': 'application/json',
          if (Session.I.token != null) 'Authorization': 'Bearer ${Session.I.token}',
          'Accept-Language': Session.I.locale.languageCode,
        }).timeout(const Duration(seconds: 30));
        entry['status'] = r.statusCode;
        entry['content_type'] = r.headers['content-type'];
        entry['ms'] = sw.elapsedMilliseconds;
        final text = utf8.decode(r.bodyBytes);
        try {
          final j = jsonDecode(text);
          if (c.path == 'my_shipments.php' && firstId == null) {
            final l = Api.listOf(j);
            if (l.isNotEmpty) firstId = '${l.first['id'] ?? ''}';
            if (firstId == '') firstId = null;
          }
          entry['response'] = _mask(j);
        } catch (_) {
          entry['response_text'] = text.length > 600 ? '${text.substring(0, 600)}…' : text;
        }
      } catch (e) {
        entry['error'] = '$e';
      }
      report.add(entry);
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => loading = false);
  }

  String get _json => const JsonEncoder.withIndent('  ').convert({
        'base_url': 'https://deliveric.net/api_v2/',
        'app_version': '2.1.5',
        'recorded_at': DateTime.now().toIso8601String(),
        'calls': report,
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API recorder'), actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy report',
          onPressed: loading
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: _json));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied')));
                },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (loading) const LinearProgressIndicator(color: Brand.orange),
        Text(
          loading
              ? 'Recording ${report.length}/${calls.length}…'
              : 'Done. Tap copy (top right) and paste the report in the chat. Names, phones, addresses and the token are masked.',
          style: const TextStyle(color: Brand.muted),
        ),
        const SizedBox(height: 12),
        for (final e in report)
          Card(
            child: ListTile(
              dense: true,
              title: Text((e['url'] as String).replaceFirst('https://deliveric.net/api_v2/', '')),
              trailing: Text(e['status'] != null ? '${e['status']}' : 'ERR',
                  style: TextStyle(color: e['status'] == 200 ? Brand.green : Brand.red, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}
