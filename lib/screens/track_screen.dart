import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'shipment_details_screen.dart';

/// Scan & track: type or paste a waybill / order number, open its details.
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _c = TextEditingController();
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
      final r = await Api.get('my_shipments.php', {'general_status': 'delivere', 'start': '0', 'limit': '50', 'lang': 'en', 'searchKey': q});
      final list = Api.listOf(r);
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
