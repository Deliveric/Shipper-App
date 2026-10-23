import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';
import 'shipments_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const ShipmentsScreen(), const AccountsScreen(), const SettingsScreen()];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        indicatorColor: Brand.orange.withOpacity(.25),
        destinations: [
          NavigationDestination(
            icon: Image.asset('assets/image/boxes.png', width: 26),
            label: tr(context, 'shipments'),
          ),
          NavigationDestination(
            icon: Image.asset('assets/image/account.png', width: 26),
            label: tr(context, 'accounts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: tr(context, 'settings'),
          ),
        ],
      ),
    );
  }
}
