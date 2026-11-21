import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One logged-in Deliveric account. Only the token is stored (never the password).
class Account {
  final String token;
  String userId, name;
  Account(this.token, this.userId, this.name);
  String get id => userId.isNotEmpty ? userId : token;
  String get title => name.isNotEmpty ? name : (userId.isNotEmpty ? '#$userId' : '—');
  Map<String, dynamic> toJson() => {'token': token, 'user_id': userId, 'name': name};
  static Account from(Map m) => Account('${m['token']}', '${m['user_id'] ?? ''}', '${m['name'] ?? ''}');
}

class Session extends ChangeNotifier {
  static final Session I = Session._();
  Session._();

  late SharedPreferences _p;
  final List<Account> accounts = [];
  final Set<String> _selected = {};
  Locale locale = const Locale('en');

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    try {
      final raw = _p.getString('accounts');
      if (raw != null) {
        for (final m in jsonDecode(raw) as List) {
          accounts.add(Account.from(m as Map));
        }
      }
    } catch (_) {}
    // migrate the old single-account storage
    final old = _p.getString('token');
    if (accounts.isEmpty && old != null && old.isNotEmpty) {
      accounts.add(Account(old, _p.getString('user_id') ?? '', _p.getString('user_name') ?? ''));
    }
    _selected.addAll(_p.getStringList('selected') ?? const []);
    _selected.removeWhere((id) => !accounts.any((a) => a.id == id));
    if (_selected.isEmpty && accounts.isNotEmpty) _selected.add(accounts.first.id);
    locale = Locale(_p.getString('lang') ?? 'en');
  }

  Future<void> _persist() async {
    await _p.setString('accounts', jsonEncode(accounts.map((a) => a.toJson()).toList()));
    await _p.setStringList('selected', _selected.toList());
    await _p.remove('token');
    await _p.remove('user_id');
    await _p.remove('user_name');
  }

  /// accounts that are ticked (at least one while any account exists)
  List<Account> get active {
    final l = accounts.where((a) => _selected.contains(a.id)).toList();
    return l.isEmpty && accounts.isNotEmpty ? [accounts.first] : l;
  }

  bool isSelected(String id) => active.any((a) => a.id == id);
  String? get token => active.isEmpty ? null : active.first.token;
  String? get userName => active.isEmpty ? null : active.map((a) => a.title).join(' + ');
  bool get loggedIn => accounts.isNotEmpty;
  bool get multi => active.length > 1;

  Account? byToken(String? t) {
    for (final a in accounts) {
      if (a.token == t) return a;
    }
    return null;
  }

  /// Add (or refresh) an account and make it the only active one.
  Future<void> save({required String token, String? userId, String? name, bool add = false}) async {
    final uid = userId ?? '';
    accounts.removeWhere((a) => a.token == token || (uid.isNotEmpty && a.userId == uid));
    final a = Account(token, uid, name ?? '');
    accounts.add(a);
    _selected.removeWhere((id) => !accounts.any((x) => x.id == id));
    if (!add) _selected.clear();
    _selected.add(a.id);
    await _persist();
    notifyListeners();
  }

  Future<void> selectAll() async {
    _selected
      ..clear()
      ..addAll(accounts.map((a) => a.id));
    await _persist();
    notifyListeners();
  }

  Future<void> setNameFor(String token, String name) async {
    final a = byToken(token);
    if (a == null || name.isEmpty || a.name == name) return;
    a.name = name;
    await _persist();
    notifyListeners();
  }

  /// Tick / untick an account (combined mode when several are ticked).
  Future<void> toggle(String id) async {
    if (_selected.contains(id)) {
      if (_selected.length > 1) _selected.remove(id);
    } else {
      _selected.add(id);
    }
    await _persist();
    notifyListeners();
  }

  /// Work with this account only.
  Future<void> only(String id) async {
    _selected
      ..clear()
      ..add(id);
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    accounts.removeWhere((a) => a.id == id);
    _selected.remove(id);
    if (_selected.isEmpty && accounts.isNotEmpty) _selected.add(accounts.first.id);
    await _persist();
    notifyListeners();
  }

  Future<void> setLang(String code) async {
    locale = Locale(code);
    await _p.setString('lang', code);
    notifyListeners();
  }

  /// log out of every account
  Future<void> logout() async {
    accounts.clear();
    _selected.clear();
    await _persist();
    notifyListeners();
  }
}
