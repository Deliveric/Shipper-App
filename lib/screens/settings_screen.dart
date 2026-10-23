import 'package:flutter/material.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = Session.I.locale.languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'settings'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Center(child: Image.asset('assets/image/logo.png', height: 110)),
          if ((Session.I.userName ?? '').isNotEmpty)
            Center(
              child: Text(Session.I.userName!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Image.asset('assets/image/Language.png', width: 28),
              title: Text(tr(context, 'language')),
              trailing: Text(ar ? 'العربية' : 'English'),
              onTap: () => Session.I.setLang(ar ? 'en' : 'ar'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Image.asset('assets/image/logout.png', width: 28),
              title: Text(tr(context, 'logout'), style: const TextStyle(color: Brand.red)),
              onTap: () async {
                await Session.I.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
