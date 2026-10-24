import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.post('login.php', {
        'phone': _user.text.trim(),
        'password': _pass.text,
        'type': 'android',
        'platform_info': 'model:android,UUID:shipper-deliveric,version:android,serial:unknown,app_version:2.1.5',
        'app_version': '2.1.5',
      });
      final m = r is Map ? r : {};
      final data = m['token'] != null ? m : (m['data'] is Map ? m['data'] as Map : m);
      final token = Api.pick(data, ['token', 'access_token', 'api_token']);
      if (token.isEmpty) throw ApiException(Api.pick(m, ['message', 'msg'], 'Login failed'));
      await Session.I.save(
        token: token,
        userId: Api.pick(data, ['id', 'user_id']),
        name: Api.pick(data, ['name', 'full_name', 'username']),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset('assets/image/logo.png', width: 220),
                const SizedBox(height: 16),
                TextField(
                  controller: _user,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: tr(context, 'phone'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    hintText: tr(context, 'password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Brand.red)),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(tr(context, 'login')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
