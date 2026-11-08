import 'package:flutter/material.dart';
import 'track_screen.dart';
import '../core/api.dart';
import '../core/data.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/util.dart';
import 'shipment_details_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onTab;
  const HomeScreen({super.key, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final d = AppData.I;
        final op = d.inOperation;
        final groups = <String, int>{};
        for (final s in op) {
          groups[Api.pick(s, ['status_en'])] = (groups[Api.pick(s, ['status_en'])] ?? 0) + 1;
        }
        final names = groups.keys.toList()..sort((a, b) => groups[b]!.compareTo(groups[a]!));
        final pickups = d.shipments.length - op.length;
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'home'))),
          body: RefreshIndicator(
            color: Brand.orange,
            onRefresh: d.refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 110), children: [
              if ((Session.I.userName ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 2),
                  child: Text('Hello, ${Session.I.userName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              if (d.loading) const LinearProgressIndicator(color: Brand.orange, minHeight: 3),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [Brand.orange, Brand.orangeDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Shipments in operation · COD to collect', style: TextStyle(color: Color(0xBF1B1B17), fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(fmt(d.inOperationCod), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Brand.dark)),
                    const SizedBox(width: 6),
                    const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('EGP', style: TextStyle(color: Color(0xBF1B1B17)))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _chip('Net Deserved', d.net, outlined: true),
                    const SizedBox(width: 10),
                    _chip('The Transferable Amount', d.transferable),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _box('In operation', '${op.length}', 'shipments')),
                const SizedBox(width: 10),
                Expanded(child: _box('Pickup requests', '$pickups', 'waiting to be picked up')),
              ]),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _act(Icons.add, tr(context, 'new_shipment'), () => onTab(0)),
                _act(Icons.qr_code_scanner, tr(context, 'scan_track'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackScreen()))),
                _act(Icons.local_shipping_outlined, tr(context, 'request_pickup'), () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
                }),
              ]),
              _sec('In operation by status'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(children: [
                        for (final n in names)
                          Expanded(flex: groups[n]!, child: Container(color: statusColor(n))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 12, runSpacing: 6, children: [
                    for (final n in names.take(6))
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor(n), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('$n ${groups[n]}', style: const TextStyle(fontSize: 11, color: Brand.muted)),
                      ]),
                  ]),
                ]),
              ),
              _sec('Newest shipments'),
              for (final s in d.shipments.take(3))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipment: s))),
                    title: Text('#${Api.code(s)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([Api.name(s), Api.status(s), if (Api.pick(s, ['order_id']).isNotEmpty) 'Order ${Api.pick(s, ['order_id'])}'].where((e) => e.isNotEmpty).join('  •  ')),
                    trailing: Text('${fmt(Api.num(Api.cod(s)))} EGP', style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (d.error != null && d.shipments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(d.error!, style: const TextStyle(color: Brand.red)),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _chip(String label, num v, {bool outlined = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: outlined ? Brand.dark : Brand.text,
            borderRadius: BorderRadius.circular(16),
            border: outlined ? Border.all(color: Brand.orange, width: 1.5) : null,
          ),
          child: Column(children: [
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: outlined ? Brand.muted : const Color(0xFF55503F))),
            const SizedBox(height: 3),
            Text(fmt(v), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: outlined ? Brand.orange : Brand.dark)),
          ]),
        ),
      );

  Widget _box(String t, String big, String small) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 11, color: Brand.muted)),
          Text(big, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text(small, style: const TextStyle(fontSize: 11, color: Brand.muted)),
        ]),
      );

  Widget _act(IconData i, String t, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(30),
        child: Column(children: [
          CircleAvatar(radius: 24, backgroundColor: Brand.card, child: Icon(i, color: Brand.orange)),
          const SizedBox(height: 6),
          Text(t, style: const TextStyle(fontSize: 11, color: Brand.muted)),
        ]),
      );

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12, color: Brand.muted, letterSpacing: .8)),
      );
}
