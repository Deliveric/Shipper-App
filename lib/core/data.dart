import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'session.dart';
import 'strings.dart';
import 'util.dart';

class Tx {
  final int id;
  final DateTime date;
  final String waybill, type;
  final num value, fee, commission;
  final int report;
  Tx(this.id, this.date, this.waybill, this.type, this.value, this.fee, this.commission, this.report);

  static Tx? from(Map m) {
    final d = parseDate('${m['date_added']}');
    if (d == null) return null;
    num n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
    return Tx(n(m['id']).toInt(), d, '${m['waybill'] ?? ''}'.replaceAll('null', ''), '${m['type'] ?? ''}', n(m['value']),
        n(m['delivery_cost']), n(m['commission']), n(m['report_id']).toInt());
  }

  bool get isPayout => type == '10' || type == '30';
  bool get isDelivery => type == '70';
  bool get isReturn => type == '80' || type == '152';
  String get label => tl(const {
        '70': 'Delivered',
        '80': 'Returned',
        '152': 'Partial / replacement',
        '10': 'Cash payout',
        '30': 'Bank transfer',
        '60': 'Extra services',
        '151': 'Overweight',
      }[type] ??
      'Other');

  /// money that moves on your account because of this row
  num get net => isPayout ? -value : (type == '60' || type == '151' ? value : value - fee);
}

/// Everything the screens show, loaded once and shared.
class AppData extends ChangeNotifier {
  static final AppData I = AppData._();
  AppData._();

  bool loading = false;
  List<Map<String, dynamic>> shipments = [];
  int allCount = 0;
  num allCod = 0, net = 0, transferable = 0, codCollected = 0;
  List<String> dashLabels = [];
  List<num> dashCounts = [];
  List<Tx> tx = []; // newest first, from the start of the month/week until now
  DateTime? loadedAt;
  String? error;

  Map<String, String> get _hdr => {
        'Accept': 'application/json',
        if (Session.I.token != null) 'Authorization': 'Bearer ${Session.I.token}',
        'Accept-Language': Session.I.locale.languageCode,
      };

  num _n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    final lang = Session.I.locale.languageCode;
    Future<void> guard(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        error ??= '$e';
      }
    }

    await Future.wait([
      guard(() async {
        final out = <Map<String, dynamic>>[];
        for (var start = 0;; start += 1000) {
          final r = await Api.get('my_shipments.php', {'general_status': 'delivere', 'start': '$start', 'limit': '1000', 'lang': lang});
          final l = Api.listOf(r);
          out.addAll(l);
          if (l.length < 1000) break;
        }
        shipments = out;
      }),
      guard(() async {
        final r = await Api.get('my_shipments.php', {'general_status': 'delivere', 'count': '1'});
        final i = r is Map ? r['info'] : null;
        if (i is Map) {
          allCount = _n(i['count']).toInt();
          allCod = _n(i['sum']);
        }
      }),
      guard(() async {
        final r = await Api.get('statusDashboard.php');
        final d = r is Map ? r['statusDashboard'] : null;
        if (d is Map) {
          dashLabels = (d['labels'] as List).map((e) => '$e').toList();
          dashCounts = (d['counts'] as List).map(_n).toList();
        }
      }),
      guard(() async => net = _n((await Api.get('transactions_sum.php'))['balance'])),
      guard(() async => transferable = _n((await Api.get('get_withdrawable_amount.php'))['withdrawable_amount'])),
      guard(() async {
        final r = await Api.get('getShipperBalance.php');
        final b = r is Map ? r['shipperBalance'] : null;
        if (b is Map) codCollected = _n(b['cod']);
      }),
      guard(_loadTx),
    ]);
    loadedAt = DateTime.now();
    loading = false;
    notifyListeners();
  }

  /// my_transactions.php returns the whole history (tens of MB) newest first and
  /// has no paging, so it is read as a stream and cut off once we have gone back
  /// far enough for the Stats screen (start of month or week) and at least 40 rows.
  Future<void> _loadTx() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: (now.weekday + 1) % 7));
    final limit = weekStart.isBefore(monthStart) ? weekStart : monthStart;
    final items = await _streamItems(Api.base + 'my_transactions.php', 'transactions', (m) {
      final t = Tx.from(m);
      return t != null && t.date.isBefore(limit);
    }, minItems: 40);
    tx = items.map(Tx.from).whereType<Tx>().toList();
  }

  Future<List<Map>> _streamItems(String url, String key, bool Function(Map) stopAt, {int minItems = 0}) async {
    final c = http.Client();
    try {
      final res = await c.send(http.Request('GET', Uri.parse(url))..headers.addAll(_hdr)).timeout(const Duration(seconds: 90));
      final out = <Map>[];
      var tail = '', inList = false, inStr = false, esc = false, done = false;
      var depth = 0;
      final cur = StringBuffer();
      await for (final chunk in res.stream.transform(utf8.decoder)) {
        for (var i = 0; i < chunk.length && !done; i++) {
          final ch = chunk[i];
          if (!inList) {
            tail += ch;
            if (tail.length > 40) tail = tail.substring(tail.length - 40);
            if (tail.endsWith('"$key":[')) inList = true;
            continue;
          }
          if (depth == 0) {
            if (ch == '{') {
              depth = 1;
              cur.clear();
              cur.write(ch);
            } else if (ch == ']') {
              done = true;
            }
            continue;
          }
          cur.write(ch);
          if (inStr) {
            if (esc) {
              esc = false;
            } else if (ch == '\\') {
              esc = true;
            } else if (ch == '"') {
              inStr = false;
            }
          } else if (ch == '"') {
            inStr = true;
          } else if (ch == '{') {
            depth++;
          } else if (ch == '}') {
            depth--;
            if (depth == 0) {
              final m = jsonDecode(cur.toString()) as Map;
              out.add(m);
              if (out.length >= minItems && stopAt(m)) done = true;
            }
          }
        }
        if (done) break;
      }
      return out;
    } finally {
      c.close();
    }
  }

  // ---- derived figures ----
  /// shipments that are on their way (the website's "in operation": everything except pickup requests)
  List<Map<String, dynamic>> get inOperation => shipments.where((s) => Api.pick(s, ['status_en']) != 'Pickup Request').toList();
  num get inOperationCod => inOperation.fold<num>(0, (a, s) => a + Api.num(Api.cod(s)));

  /// delivered / returned figures between two moments (rows are newest first)
  ({int delivered, num cod, num fees, int returned}) period(DateTime from) {
    var d = 0, r = 0;
    num cod = 0, fees = 0;
    for (final t in tx) {
      if (t.date.isBefore(from)) continue;
      if (t.isDelivery) {
        d++;
        cod += t.value;
        fees += t.fee;
      } else if (t.type == '80') {
        r++;
      }
    }
    return (delivered: d, cod: cod, fees: fees, returned: r);
  }

  int delivered(DateTime day) => tx.where((t) => t.isDelivery && t.date.year == day.year && t.date.month == day.month && t.date.day == day.day).length;
}
