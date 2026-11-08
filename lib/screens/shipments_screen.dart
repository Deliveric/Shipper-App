import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/copy_button.dart';
import '../core/data.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/util.dart';
import 'shipment_details_screen.dart';
import 'track_screen.dart';

class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});
  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _search = TextEditingController();
  String _status = '';
  final _sel = <String>{}; // waybills

  String _en(Map s) => Api.pick(s, ['status_en']);
  String _key(Map s) => Api.pick(s, ['waybill', 'id']);

  List<Map<String, dynamic>> get _view {
    final q = _search.text.trim().toLowerCase();
    return AppData.I.shipments.where((s) {
      if (_status.isNotEmpty && _en(s) != _status) return false;
      if (q.isEmpty) return true;
      final hay = [Api.code(s), Api.pick(s, ['order_id']), Api.name(s), Api.phone(s), Api.area(s), _en(s)].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _toggle(String k) => setState(() => _sel.contains(k) ? _sel.remove(k) : _sel.add(k));

  List<Map<String, dynamic>> get _chosen => AppData.I.shipments.where((s) => _sel.contains(_key(s))).toList();

  String _line(Map s) => [Api.code(s), Api.pick(s, ['order_id']), Api.name(s), Api.phone(s), Api.area(s), _en(s), '${fmt(Api.num(Api.cod(s)))} EGP'].join(' | ');

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $what')));
  }

  String _msg(Map s) => [Api.code(s), Api.area(s), Api.phone(s), Api.name(s)].join('-');

  /// WhatsApp takes one message per link, so each selected shipment gets its own
  /// message: tap a row (or "Send next") and WhatsApp opens with that shipment's text.
  void _whatsapp(List<Map<String, dynamic>> items) {
    final sent = <int>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Brand.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        Future<void> send(int i) async {
          await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_msg(items[i]))}'), mode: LaunchMode.externalApplication);
          set(() => sent.add(i));
        }

        final next = List.generate(items.length, (i) => i).where((i) => !sent.contains(i)).toList();
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * .75,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(children: [
              Text('Send on WhatsApp · ${sent.length}/${items.length} sent', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Each shipment is its own message.', style: TextStyle(color: Brand.muted, fontSize: 12)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(_msg(items[i]), style: const TextStyle(fontSize: 13)),
                    trailing: Icon(sent.contains(i) ? Icons.check_circle : Icons.send, color: sent.contains(i) ? Brand.green : Brand.orange),
                    onTap: () => send(i),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: next.isEmpty ? null : () => send(next.first),
                child: Text(next.isEmpty ? 'All sent' : 'Send next (${next.length} left)'),
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final all = AppData.I.shipments;
        final counts = <String, int>{};
        for (final s in all) {
          counts[_en(s)] = (counts[_en(s)] ?? 0) + 1;
        }
        final names = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
        final view = _view;
        final cod = view.fold<num>(0, (a, s) => a + Api.num(Api.cod(s)));
        final chosen = _chosen;
        final chosenCod = chosen.fold<num>(0, (a, s) => a + Api.num(Api.cod(s)));
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'shipments'))),
          body: RefreshIndicator(
            color: Brand.orange,
            onRefresh: AppData.I.refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 110), children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: tr(context, 'search'), prefixIcon: const Icon(Icons.search)),
              ),
              SizedBox(
                height: 48,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _chip(tr(context, 'all'), '', all.length),
                  for (final n in names) _chip(n, n, counts[n]!),
                ]),
              ),
              if (_sel.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text('${_sel.length} selected · ${fmt(chosenCod)} EGP',
                            style: const TextStyle(color: Brand.dark, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      InkWell(onTap: () => setState(_sel.clear), child: const Icon(Icons.close, color: Brand.dark)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _act('Select all ${view.length}', () => setState(() => _sel.addAll(view.map(_key)))),
                      _act('Copy waybills', () => _copy(chosen.map((s) => Api.code(s)).join('\n'), '${chosen.length} waybills')),
                      _act('Copy details', () => _copy(chosen.map(_line).join('\n'), '${chosen.length} shipments')),
                      _act('Send on WhatsApp', () => _whatsapp(chosen)),
                    ]),
                  ]),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${view.length} shipments', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                    Text('COD ${fmt(cod)} EGP', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                  ]),
                ),
              if (AppData.I.loading && all.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Brand.orange))),
              if (!AppData.I.loading && view.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(children: [
                    Image.asset('assets/image/empty_box.png', width: 120),
                    Text(tr(context, 'empty')),
                    if (_search.text.trim().isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.search),
                        label: Text('Search all shipments for "${_search.text.trim()}"'),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackScreen(initial: _search.text.trim()))),
                      ),
                  ]),
                ),
              for (final s in view) _card(s),
            ]),
          ),
        );
      },
    );
  }

  Widget _act(String t, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(color: Brand.dark, borderRadius: BorderRadius.circular(12)),
          child: Text(t, style: const TextStyle(fontSize: 12, color: Brand.text)),
        ),
      );

  Widget _chip(String label, String value, int count) {
    final on = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text('$label  $count'),
        selected: on,
        selectedColor: Brand.orange,
        labelStyle: TextStyle(fontSize: 12, color: on ? Brand.dark : Brand.muted, fontWeight: on ? FontWeight.w600 : FontWeight.w400),
        backgroundColor: Brand.card,
        side: BorderSide.none,
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final k = _key(s);
    final on = _sel.contains(k);
    final en = _en(s);
    final c = statusColor(en);
    return GestureDetector(
      onLongPress: () => _toggle(k),
      onTap: () {
        if (_sel.isNotEmpty) {
          _toggle(k);
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipment: s)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? Brand.card2 : Brand.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? Brand.orange : Colors.transparent, width: 1.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => _toggle(k),
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: BoxDecoration(
                color: on ? Brand.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: on ? Brand.orange : Brand.muted, width: 2),
              ),
              child: on ? const Icon(Icons.check, size: 16, color: Brand.dark) : null,
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(Api.code(s), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))), CopyButton(Api.code(s))])),
                Text('${fmt(Api.num(Api.cod(s)))} EGP', style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                child: Text(Api.status(s), style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 6),
              Text([Api.name(s), Api.area(s)].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: Brand.muted)),
              if (Api.pick(s, ['order_id']).isNotEmpty) Text('Order ${Api.pick(s, ['order_id'])}', style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
