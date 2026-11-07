import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'accounts_screen.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'portal_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 2;

  void goTo(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      const PortalScreen(
        title: 'Shipments',
        url: 'https://deliveric.net/admin-area/shipper_view_shipments.php',
      ),
      const AccountsScreen(),
      HomeScreen(onTab: goTo),
      const ReportsScreen(),
      const SettingsScreen(),
    ];
    final items = [
      (Icons.inventory_2_outlined, Icons.inventory_2, 'shipments'),
      (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'wallet'),
      (Icons.home_outlined, Icons.home_rounded, 'home'),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'reports'),
      (Icons.person_outline, Icons.person, 'profile'),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF22221B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF4A4132), width: 1.5),
          ),
          child: Row(
            children: [
              for (var n = 0; n < items.length; n++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => goTo(n),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_i == n ? items[n].$2 : items[n].$1,
                            color: _i == n ? Brand.orange : Brand.muted, size: 26),
                        const SizedBox(height: 2),
                        Text(tr(context, items[n].$3),
                            style: TextStyle(
                                fontSize: 10.5,
                                color: _i == n ? Brand.orange : Brand.muted)),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: _i == n ? 26 : 0,
                          decoration: BoxDecoration(
                              color: Brand.orange, borderRadius: BorderRadius.circular(3)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
