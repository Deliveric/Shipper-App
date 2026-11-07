import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session extends ChangeNotifier {
  static final Session I = Session._();
  Session._();

  late SharedPreferences _p;
  String? token;
  String? userId;
  String? userName;
  Locale locale = const Locale('en');
  static const _ss = FlutterSecureStorage();
  String? portalUser;
  String? portalPass;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    token = _p.getString('token');
    userId = _p.getString('user_id');
    userName = _p.getString('user_name');
    locale = Locale(_p.getString('lang') ?? 'en');
    try {
      portalUser = await _ss.read(key: 'portal_user');
      portalPass = await _ss.read(key: 'portal_pass');
    } catch (_) {}
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

  /// The portal (deliveric.net/admin-area) uses the same login; kept only in the
  /// phone's secure storage so the in-app portal pages sign in automatically.
  Future<void> savePortalLogin(String user, String pass) async {
    portalUser = user;
    portalPass = pass;
    try {
      await _ss.write(key: 'portal_user', value: user);
      await _ss.write(key: 'portal_pass', value: pass);
    } catch (_) {}
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
    portalUser = null;
    portalPass = null;
    try {
      await _ss.delete(key: 'portal_user');
      await _ss.delete(key: 'portal_pass');
    } catch (_) {}
    notifyListeners();
  }
}
