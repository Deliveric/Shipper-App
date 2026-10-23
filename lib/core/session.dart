import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session extends ChangeNotifier {
  static final Session I = Session._();
  Session._();

  late SharedPreferences _p;
  String? token;
  String? userId;
  String? userName;
  Locale locale = const Locale('en');

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    token = _p.getString('token');
    userId = _p.getString('user_id');
    userName = _p.getString('user_name');
    locale = Locale(_p.getString('lang') ?? 'en');
  }

  bool get loggedIn => token != null && token!.isNotEmpty;

  Future<void> save({required String token, String? userId, String? name}) async {
    this.token = token;
    this.userId = userId;
    userName = name;
    await _p.setString('token', token);
    if (userId != null) await _p.setString('user_id', userId);
    if (name != null) await _p.setString('user_name', name);
    notifyListeners();
  }

  Future<void> setLang(String code) async {
    locale = Locale(code);
    await _p.setString('lang', code);
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    userId = null;
    userName = null;
    await _p.remove('token');
    await _p.remove('user_id');
    await _p.remove('user_name');
    notifyListeners();
  }
}
