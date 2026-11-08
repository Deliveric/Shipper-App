import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'shipment_details_screen.dart';

/// Scan & track: type or paste a waybill / order number, open its details.
class TrackScreen extends StatefulWidget {
  final String initial;
  const TrackScreen({super.key, this.initial = ''});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  bool _busy = false;
  String? _msg;
  List<Map<String, dynamic>> _found = [];

  Future<void> _go() async {
    final q = _c.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _msg = null;
      _found = [];
    });
    try {
      var list = <Map<String, dynamic>>[];
      try {
        list = Api.listOf(await Api.get('my_shipments.php', {'general_status': 'delivere', 'start': '0', 'limit': '50', 'lang': 'en', 'searchKey': q}));
      } catch (_) {}
      if (list.isEmpty) {
        // not among the open shipments: ask the lookup endpoint of the original app
        try {
          final r = await Api.post('scan_shipment.php', {'waybill': q});
          final found = <Map<String, dynamic>>[];
          void take(dynamic v) {
            if (v is Map && (v['waybill'] != null || v['id'] != null)) found.add(Map<String, dynamic>.from(v));
          }
          if (r is Map) {
            for (final k in ['shipment', 'data', 'result']) {
              final v = r[k];
              if (v is List) {
                v.forEach(take);
              } else {
                take(v);
              }
            }
            if (found.isEmpty) take(r);
          } else if (r is List) {
            r.forEach(take);
          }
          list = found;
        } catch (_) {}
      }
      setState(() {
        _found = list;
        if (list.isEmpty) _msg = 'No shipment found for "$q"';
      });
      if (list.length == 1 && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipment: list.first)));
      }
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan & track')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _go(),
          decoration: InputDecoration(
            hintText: 'Waybill or order number',
            prefixIcon: const Icon(Icons.qr_code_scanner),
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _go),
          ),
        ),
        const SizedBox(height: 14),
        if (_busy) const Center(child: CircularProgressIndicator(color: Brand.orange)),
        if (_msg != null) Text(_msg!, style: const TextStyle(color: Brand.muted)),
        for (final s in _found)
          Card(
            child: ListTile(
              title: Text(Api.code(s), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${Api.name(s)} · ${Api.status(s)}${Api.pick(s, ['order_id']).isEmpty ? '' : '\nOrder ${Api.pick(s, ['order_id'])}'}'),
              trailing: Text('${Api.cod(s)} EGP', style: const TextStyle(color: Brand.orange)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipment: s))),
            ),
          ),
      ]),
    );
  }
}
