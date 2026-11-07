import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../core/theme.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onTab;
  const HomeScreen({super.key, required this.onTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _wallet = 0, _out = 0, _delivered = 0, _total = 0;
  bool _hide = false, _loading = true;
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _num(String v) => double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;

  Future<void> _load() async {
    try {
      final b = await Api.get('getShipperBalance.php');
      final bd = b is Map ? (b['data'] is Map ? b['data'] : b) : {};
      final w = _num(Api.pick(bd, ['balance', 'amount', 'total'], '0'));
      final r = await Api.get('my_shipments.php', {'page': '1', 'limit': '1000'});
      final list = Api.listOf(r);
      double out = 0, del = 0, tot = 0;
      for (final s in list) {
        final cod = _num(Api.cod(s));
        final st = (Api.pick(s, ['status_en']) + ' ' + Api.pick(s, ['status_ar'])).toLowerCase();
        tot += cod;
        if (st.contains('deliver') && !st.contains('out') || st.contains('تسليم') || st.contains('تم')) {
          del += cod;
        } else if (st.contains('out') || st.contains('خروج') || st.contains('جاري')) {
          out += cod;
        }
      }
      if (!mounted) return;
      setState(() {
        _wallet = w;
        _out = out;
        _delivered = del;
        _total = tot;
        _recent = list.take(3).toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(double v) => _hide ? '••••' : v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final sum = (_out + _delivered + _wallet);
    final f1 = sum == 0 ? 1 : (_out / sum * 100).round().clamp(1, 98);
    return RefreshIndicator(
      color: Brand.orange,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2A17), Color(0xFF8A5624), Brand.orange],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
            ),
            child: Column(children: [
              Row(children: [
                ClipOval(child: Image.asset('assets/image/logo.png', width: 42, height: 42)),
                const Expanded(
                  child: Center(
                    child: Text('Shipper Deliveric',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Brand.text)),
                  ),
                ),
                IconButton(
                  onPressed: () => widget.onTab(4),
                  icon: const Icon(Icons.notifications_none, color: Brand.text),
                ),
              ]),
              const SizedBox(height: 14),
              Text(tr(context, 'total_cod'), style: const TextStyle(color: Color(0xFFF0DCC6))),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('EGP ', style: TextStyle(fontSize: 16, color: Color(0xFFF0DCC6))),
                Text(_loading ? '...' : _money(_total),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Brand.text)),
                IconButton(
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(_hide ? Icons.visibility_off : Icons.visibility,
                      color: Brand.text, size: 20),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(children: [
                  Expanded(flex: f1.toInt(), child: Container(color: Brand.orangeLight)),
                  const SizedBox(width: 2),
                  Expanded(flex: 100 - f1.toInt(), child: Container(color: Brand.orange)),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Brand.dark.withOpacity(.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(children: [
                  _row(Brand.orangeLight, tr(context, 'out_delivery'), _out),
                  _row(Brand.orangeDeep, tr(context, 'delivered_val'), _delivered),
                  _row(Brand.green, tr(context, 'wallet_bal'), _wallet),
                ]),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _action(Icons.add, tr(context, 'new_shipment'), () => widget.onTab(0)),
                _action(Icons.qr_code_scanner, tr(context, 'scan_track'), () => widget.onTab(0)),
                _action(Icons.local_shipping_outlined, tr(context, 'request_pickup'), () {}),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, 'recent'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (_recent.isEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text(tr(context, 'empty'), style: const TextStyle(color: Brand.muted))),
                ),
              for (final s in _recent)
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: const Color(0xFF3A2B17), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.local_shipping_outlined, color: Brand.orange),
                    ),
                    title: Text('#${Api.code(s)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(Api.name(s),
                        style: const TextStyle(color: Brand.muted)),
                    trailing: Text(Api.cod(s),
                        style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
                    onTap: () => widget.onTab(0),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(Color c, String label, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Text('EGP ${_money(v)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      );

  Widget _action(IconData i, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 100,
          child: Column(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 1.5),
              ),
              child: Icon(i, color: Brand.text),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
          ]),
        ),
      );
}
