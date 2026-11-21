import 'package:flutter/material.dart';
import '../core/build_info.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Session.I, builder: (context, _) => _body(context));

  Widget _body(BuildContext context) {
    final ar = Session.I.locale.languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
        children: [
          Center(child: ClipOval(child: Image.asset('assets/image/logo.png', height: 110))),
          if ((Session.I.userName ?? '').isNotEmpty)
            Center(
              child: Text(Session.I.userName!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          const Center(child: Padding(padding: EdgeInsets.only(top: 4), child: Text(kBuildLabel, style: TextStyle(color: Brand.muted, fontSize: 12)))),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Image.asset('assets/image/Language.png', width: 28),
              title: Text(tr(context, 'language')),
              trailing: Text(ar ? 'العربية' : 'English'),
              onTap: () => Session.I.setLang(ar ? 'en' : 'ar'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(tl('Accounts'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Brand.orange)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                Session.I.multi
                    ? '${tl('Combined')} — ${Session.I.active.length} ${tl('accounts')}\n${tl('All numbers, shipments and stats are added together')}'
                    : '${tl('One account')}: ${Session.I.userName ?? ''}',
                style: const TextStyle(fontSize: 12.5, color: Brand.muted),
              ),
            ),
          ),
          for (final a in Session.I.accounts)
            Card(
              child: ListTile(
                leading: Checkbox(
                  value: Session.I.isSelected(a.id),
                  activeColor: Brand.orange,
                  onChanged: (_) => Session.I.toggle(a.id),
                ),
                title: Text(a.title),
                subtitle: a.userId.isEmpty ? null : Text('#${a.userId}', style: const TextStyle(fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () => Session.I.only(a.id), child: Text(tl('Only this'))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Brand.muted),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('${tl('Remove account')}: ${a.title}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tl('Cancel'))),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tl('Remove'))),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await Session.I.remove(a.id);
                      if (!context.mounted || Session.I.accounts.isNotEmpty) return;
                      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                    },
                  ),
                ]),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add, color: Brand.orange),
              title: Text(tl('Add account')),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen(addMode: true))),
            ),
          ),
          const SizedBox(height: 6),
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
