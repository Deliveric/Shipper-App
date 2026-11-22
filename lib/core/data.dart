import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'session.dart';
import 'strings.dart';
import 'util.dart';

/// one month of delivered / returned figures
class MonthStat {
  int delivered = 0, returned = 0;
  num cod = 0, fees = 0;
  MonthStat();
  void add(MonthStat o) {
    delivered += o.delivered;
    returned += o.returned;
    cod += o.cod;
    fees += o.fees;
  }

  List<num> toJson() => [delivered, returned, cod, fees];
  static MonthStat from(List l) => MonthStat()
    ..delivered = (l[0] as num).toInt()
    ..returned = (l[1] as num).toInt()
    ..cod = l[2] as num
    ..fees = l[3] as num;
}

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
  AppData._() {
    Session.I.addListener(_onSession);
  }

  String _key = '';
  void _onSession() {
    final k = Session.I.active.map((a) => a.id).join(',');
    if (k == _key) return;
    _key = k;
    if (k.isEmpty) {
      _gen++;
      _clear();
      loading = false;
      notifyListeners();
    } else {
      refresh(force: false);
      if (historyWanted) loadHistory();
    }
  }

  bool loading = false;
  /// Shipments list shows only "action required" ones (set from Home / the chip).
  bool actionOnly = false;
  void setActionOnly(bool v) {
    actionOnly = v;
    notifyListeners();
  }

  /// Same list as the website page "Shipments that need action from the shipper".
  static const actionStatuses = {'Hold (Follow with Shipper)'};
  /// SIMULATION ONLY: waybills the user marked "Ready for delivery" in this session.
  /// Nothing is sent to Deliveric; it is cleared when the page reloads.
  final Set<String> simReady = {};
  void markReady(String waybill) {
    simReady.add(waybill);
    notifyListeners();
  }

  List<Map<String, dynamic>> get actionRequired =>
      shipments.where((s) => actionStatuses.contains('${s['status_en']}'.trim()) && !simReady.contains('${s['waybill']}')).toList();

  List<Map<String, dynamic>> shipments = [];
  int allCount = 0;
  num allCod = 0, net = 0, transferable = 0, codCollected = 0;
  List<String> dashLabels = [];
  List<num> dashCounts = [];
  List<Tx> tx = []; // newest first, from the start of the month/week until now
  DateTime? loadedAt;
  String? error;

  num _n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

  /// Per-account data kept in memory, so switching between accounts is instant.
  final Map<String, _AccData> _cache = {};
  final Map<String, DateTime> _cacheAt = {};

  void _clear() {
    shipments = [];
    tx = [];
    allCount = 0;
    allCod = net = transferable = codCollected = 0;
    dashLabels = [];
    dashCounts = [];
  }

  void _apply(List<_AccData> res) {
    shipments = [for (final r in res) ...r.shipments];
    allCount = res.fold(0, (a, r) => a + r.count);
    allCod = res.fold<num>(0, (a, r) => a + r.cod);
    net = res.fold<num>(0, (a, r) => a + r.net);
    transferable = res.fold<num>(0, (a, r) => a + r.transferable);
    codCollected = res.fold<num>(0, (a, r) => a + r.codCollected);
    final dash = <String, num>{};
    for (final r in res) {
      for (var i = 0; i < r.dashLabels.length && i < r.dashCounts.length; i++) {
        dash[r.dashLabels[i]] = (dash[r.dashLabels[i]] ?? 0) + r.dashCounts[i];
      }
    }
    dashLabels = dash.keys.toList();
    dashCounts = dash.values.toList();
    tx = [for (final r in res) ...r.tx]..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Loads the ticked accounts in parallel and adds everything together.
  /// force=false (switching accounts): accounts already loaded are shown at once
  /// and refreshed in the background.
  int _gen = 0;
  Future<void> refresh({bool force = true}) async {
    final gen = ++_gen;
    final accs = Session.I.active;
    final allCached = accs.isNotEmpty && accs.every((a) => _cache.containsKey(a.token));
    if (allCached && !force) {
      _apply([for (final a in accs) _cache[a.token]!]);
    } else {
      _clear();
    }
    final stale = accs; // always revalidate in the background; cached figures show meanwhile
    if (stale.isEmpty) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    final fresh = await Future.wait(stale.map(_loadOne));
    for (final f in fresh) {
      if (f.error == null) {
        _cache[f.acc.token] = f;
        _cacheAt[f.acc.token] = DateTime.now();
      }
    }
    if (gen != _gen) return; // a newer refresh (other accounts) is running; ignore this one
    final res = [
      for (final a in accs) fresh.firstWhere((f) => f.acc.token == a.token, orElse: () => _cache[a.token]!),
    ];
    _apply(res);
    final errs = [for (final r in fresh) if (r.error != null) accs.length > 1 ? '${r.acc.title}: ${r.error}' : r.error!];
    error = errs.isEmpty ? null : errs.join('\n');
    loadedAt = DateTime.now();
    loading = false;
    notifyListeners();
  }

  Future<_AccData> _loadOne(Account acc) async {
    final d = _AccData(acc);
    final t = acc.token;
    final lang = Session.I.locale.languageCode;
    Future<void> guard(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        d.error ??= '$e';
      }
    }

    await Future.wait([
      guard(() async {
        final out = <Map<String, dynamic>>[];
        for (var start = 0;; start += 1000) {
          final r = await Api.get('my_shipments.php', {'general_status': 'delivere', 'start': '$start', 'limit': '1000', 'lang': lang}, t);
          final l = Api.listOf(r);
          out.addAll(l);
          if (l.length < 1000) break;
        }
        for (final s in out) {
          s['_token'] = t;
          s['_account'] = acc.title;
        }
        d.shipments = out;
      }),
      guard(() async {
        final r = await Api.get('my_shipments.php', {'general_status': 'delivere', 'count': '1'}, t);
        final i = r is Map ? r['info'] : null;
        if (i is Map) {
          d.count = _n(i['count']).toInt();
          d.cod = _n(i['sum']);
        }
      }),
      guard(() async {
        final r = await Api.get('statusDashboard.php', null, t);
        final x = r is Map ? r['statusDashboard'] : null;
        if (x is Map) {
          d.dashLabels = (x['labels'] as List).map((e) => '$e').toList();
          d.dashCounts = (x['counts'] as List).map(_n).toList();
        }
      }),
      guard(() async => d.net = _n((await Api.get('transactions_sum.php', null, t))['balance'])),
      guard(() async {
        final u = await Api.get('user_info.php', null, t);
        final i = u is Map ? u['userInfo'] : null;
        if (i is Map) {
          final n = '${i['name'] ?? ''}'.trim();
          await Session.I.setNameFor(t, n.isNotEmpty ? n : '${i['company_name'] ?? ''}'.trim());
        }
      }),
      guard(() async => d.transferable = _n((await Api.get('get_withdrawable_amount.php', null, t))['withdrawable_amount'])),
      guard(() async {
        final r = await Api.get('getShipperBalance.php', null, t);
        final b = r is Map ? r['shipperBalance'] : null;
        if (b is Map) d.codCollected = _n(b['cod']);
      }),
      guard(() async => d.tx = await _loadTx(t)),
    ]);
    return d;
  }

  /// my_transactions.php returns the whole history (tens of MB) newest first and
  /// has no paging, so it is read as a stream and cut off once we have gone back
  /// far enough for the Stats screen (start of month or week) and at least 40 rows.
  Future<List<Tx>> _loadTx(String token) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: (now.weekday + 1) % 7));
    final limit = weekStart.isBefore(monthStart) ? weekStart : monthStart;
    final items = await _streamItems(Api.base + 'my_transactions.php', 'transactions', (m) {
      final t = Tx.from(m);
      return t != null && t.date.isBefore(limit);
    }, token, minItems: 40);
    return items.map(Tx.from).whereType<Tx>().toList();
  }

  Future<List<Map>> _streamItems(String url, String key, bool Function(Map) stopAt, String token, {int minItems = 0, void Function(Map)? onItem}) async {
    final c = http.Client();
    try {
      final res = await c.send(http.Request('GET', Uri.parse(url))..headers.addAll(Api.headersFor(token))).timeout(const Duration(seconds: 90));
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
              if (onItem != null) {
                onItem(m);
              } else {
                out.add(m);
              }
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

  // ---- month by month history (Stats screen) ----
  // The whole transaction history is read once per session as a stream and only the
  // monthly totals are kept (and saved on the device so the next start shows them at once).
  final Map<String, Map<String, MonthStat>> _hist = {}; // account token -> 'yyyy-MM' -> totals
  final Set<String> _histFresh = {};
  bool historyLoading = false, historyWanted = false;
  String? historyError;
  int _histGen = 0;

  /// monthly totals of the accounts shown now, added together
  Map<String, MonthStat> get monthly {
    final out = <String, MonthStat>{};
    for (final a in Session.I.active) {
      (_hist[a.token] ?? const <String, MonthStat>{}).forEach((k, v) => (out[k] ??= MonthStat()).add(v));
    }
    return out;
  }

  Future<void> loadHistory({bool force = false}) async {
    historyWanted = true;
    final gen = ++_histGen;
    final accs = Session.I.active;
    if (force) {
      historyLoading = true; // show the spinner at once when the button is pressed
      historyError = null;
      notifyListeners();
    }
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {}
    for (final a in accs) {
      if (_hist.containsKey(a.token) || p == null) continue;
      try {
        final raw = p.getString('hist_${a.id}');
        if (raw != null) {
          _hist[a.token] = {for (final e in (jsonDecode(raw) as Map).entries) e.key as String: MonthStat.from(e.value as List)};
        }
      } catch (_) {}
    }
    notifyListeners();
    final todo = accs.where((a) => force || !_histFresh.contains(a.token)).toList();
    if (todo.isEmpty) {
      historyLoading = false;
      notifyListeners();
      return;
    }
    historyLoading = true;
    historyError = null;
    notifyListeners();
    await Future.wait(todo.map((a) async {
      try {
        final m = <String, MonthStat>{};
        await _streamItems(Api.base + 'my_transactions.php', 'transactions', (_) => false, a.token, onItem: (r) {
          final t = Tx.from(r);
          if (t == null) return;
          if (!t.isDelivery && t.type != '80') return;
          final k = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
          final s = m[k] ??= MonthStat();
          if (t.isDelivery) {
            s.delivered++;
            s.cod += t.value;
            s.fees += t.fee;
          } else {
            s.returned++;
          }
        }).timeout(const Duration(minutes: 5));
        _hist[a.token] = m;
        _histFresh.add(a.token);
        await p?.setString('hist_${a.id}', jsonEncode({for (final e in m.entries) e.key: e.value.toJson()}));
      } catch (e) {
        historyError = '$e';
      }
    }));
    if (gen == _histGen) historyLoading = false;
    notifyListeners();
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

class _AccData {
  final Account acc;
  _AccData(this.acc);
  List<Map<String, dynamic>> shipments = [];
  int count = 0;
  num cod = 0, net = 0, transferable = 0, codCollected = 0;
  List<String> dashLabels = [];
  List<num> dashCounts = [];
  List<Tx> tx = [];
  String? error;
}
