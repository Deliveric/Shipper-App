import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'accounts_screen.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'shipments_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 2;

  @override
  void initState() {
    super.initState();
    AppData.I.refresh();
  }

  Widget _accountBar() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('${tl('All')} (${Session.I.ticked.length})'),
                selected: Session.I.viewId == null,
                selectedColor: Brand.orange,
                elevation: 0,
                pressElevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                onSelected: (_) => Session.I.setView(null),
              ),
            ),
            for (final a in Session.I.ticked)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(a.title),
                  selected: Session.I.viewId == a.id,
                  selectedColor: Brand.orange,
                elevation: 0,
                pressElevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                  onSelected: (_) => Session.I.setView(a.id),
                ),
              ),
          ]),
        ),
      );

  void goTo(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ShipmentsScreen(),
      const AccountsScreen(),
      HomeScreen(onTab: goTo),
      const ReportsScreen(),
      const SettingsScreen(),
    ];
    final items = [
      (Icons.inventory_2_outlined, Icons.inventory_2, 'shipments'),
      (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'wallet'),
      (Icons.home_outlined, Icons.home_rounded, 'home'),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'stats'),
      (Icons.person_outline, Icons.person, 'profile'),
    ];
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          ListenableBuilder(
            listenable: Session.I,
            builder: (context, _) => Session.I.combinedMode ? _accountBar() : const SizedBox.shrink(),
          ),
          Expanded(
            child: Stack(children: [
              IndexedStack(index: _i, children: pages),
              // big spinner while there is nothing to show yet (first load or a not-yet-loaded account)
              ListenableBuilder(
                listenable: AppData.I,
                builder: (context, _) {
                  final d = AppData.I;
                  if (!d.loading || _i == 4 || d.shipments.isNotEmpty || d.tx.isNotEmpty || d.net != 0) return const SizedBox.shrink();
                  final label = ['Loading shipments…', 'Loading wallet…', 'Loading home…', 'Loading stats…'][_i];
                  return Positioned.fill(
                    child: Container(
                      color: Brand.dark.withOpacity(.92),
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 46, height: 46, child: CircularProgressIndicator(color: Brand.orange, strokeWidth: 4)),
                        const SizedBox(height: 14),
                        Text(tl(label), style: const TextStyle(color: Brand.muted)),
                      ]),
                    ),
                  );
                },
              ),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: AppData.I,
        builder: (context, _) => SafeArea(
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
                        Badge(
                          isLabelVisible: n == 0 && AppData.I.actionRequired.isNotEmpty,
                          label: Text('${AppData.I.actionRequired.length}'),
                          child: Icon(_i == n ? items[n].$2 : items[n].$1, color: _i == n ? Brand.orange : Brand.muted, size: 26),
                        ),
                        const SizedBox(height: 2),
                        Text(tr(context, items[n].$3), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, height: 1.1, color: _i == n ? Brand.orange : Brand.muted)),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: _i == n ? 26 : 0,
                          decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(3)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      )),
    );
  }
}
