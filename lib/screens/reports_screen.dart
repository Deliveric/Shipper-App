import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/util.dart';

/// "Stats" tab: delivered today / this week / this month, last 7 days, all-time status counts.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final d = AppData.I;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = today.subtract(Duration(days: (now.weekday + 1) % 7)); // weeks start on Saturday
        final monthStart = DateTime(now.year, now.month, 1);
        final periods = [
          ('Today', '${today.day}/${today.month}', today),
          ('This week', 'from ${weekStart.day}/${weekStart.month}', weekStart),
          ('This month', 'from 1/${now.month}', monthStart),
        ];
        final last7 = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
        final counts = last7.map(d.delivered).toList();
        final mx = counts.fold<int>(1, (a, b) => b > a ? b : a);
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'stats'))),
          body: RefreshIndicator(
            color: Brand.orange,
            onRefresh: d.refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 110), children: [
              if (d.loading) const LinearProgressIndicator(color: Brand.orange, minHeight: 3),
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 6, 2, 10),
                child: Text('Delivered shipments. A delivery counts on the day it is paid into your account. Weeks start on Saturday.',
                    style: TextStyle(color: Brand.muted, fontSize: 12)),
              ),
              for (final p in periods) ...[
                _period(p.$1, p.$2, d.period(p.$3)),
                const SizedBox(height: 10),
              ],
              _sec('Last 7 days'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(16)),
                child: SizedBox(
                  height: 130,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text('${counts[i]}', style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 3),
                          Container(
                            height: 2 + counts[i] / mx * 76,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: const BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
                          ),
                          const SizedBox(height: 4),
                          Text(_days[last7[i].weekday - 1], style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
                        ]),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12, color: Brand.muted, letterSpacing: .8)),
      );

  Widget _period(String title, String sub, ({int delivered, num cod, num fees, int returned}) p) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: Brand.muted, letterSpacing: .8)),
            Text(sub, style: const TextStyle(fontSize: 11, color: Brand.muted)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${p.delivered}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Brand.orange)),
            const SizedBox(width: 6),
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('delivered', style: TextStyle(color: Brand.muted, fontSize: 13))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _mini('COD collected', fmt(p.cod)),
            const SizedBox(width: 8),
            _mini('Shipping fees', fmt(p.fees)),
            const SizedBox(width: 8),
            _mini('Returned', '${p.returned}'),
          ]),
        ]),
      );

  Widget _mini(String k, String v) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Brand.card2, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
            Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
