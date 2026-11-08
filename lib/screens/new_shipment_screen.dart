import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/data.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'shipment_details_screen.dart';

/// New shipment: posts the same fields the website form uses to create_shipment.php.
class NewShipmentScreen extends StatefulWidget {
  const NewShipmentScreen({super.key});
  @override
  State<NewShipmentScreen> createState() => _NewShipmentScreenState();
}

class _NewShipmentScreenState extends State<NewShipmentScreen> {
  final _f = GlobalKey<FormState>();
  final _name = TextEditingController(), _p1 = TextEditingController(), _p2 = TextEditingController();
  final _addr = TextEditingController(), _prod = TextEditingController(), _cod = TextEditingController();
  final _order = TextEditingController(), _notes = TextEditingController();
  final _weight = TextEditingController(text: '1'), _qty = TextEditingController(text: '1');
  List<Map<String, dynamic>> _sectors = [], _types = [];
  String? _sector, _type;
  String _cost = '';
  bool _busy = false, _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = Api.listOf(await Api.get('sectors.php'));
      final t = Api.listOf(await Api.get('service_types.php'));
      if (mounted) setState(() { _sectors = s; _types = t; _loaded = true; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load areas: $e'; _loaded = true; });
    }
  }

  String _areaLabel(Map s) {
    final p = '${s['name']}'.split(' - ');
    return p.length > 1 ? '${p[0]} · ${p[1]}' : p[0];
  }

  Future<String?> _pickArea() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Brand.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(builder: (ctx, set) {
          final list = _sectors.where((s) => '${s['name']}'.toLowerCase().contains(q.toLowerCase())).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * .8,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 16, 14, MediaQuery.of(ctx).viewInsets.bottom + 10),
              child: Column(children: [
                TextField(
                  autofocus: true,
                  onChanged: (v) => set(() => q = v),
                  decoration: InputDecoration(hintText: tl('Search area'), prefixIcon: Icon(Icons.search)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_areaLabel(list[i])),
                      onTap: () => Navigator.of(ctx).pop('${list[i]['id']}'),
                    ),
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  Future<void> _price(String? id) async {
    setState(() { _sector = id; _cost = ''; });
    if (id == null) return;
    try {
      final r = await Api.get('getDeliveryCost.php', {'sector_id': id, 'lang': 'en'});
      if (r is Map && mounted) {
        final v = r['delivery_cost'] ?? r['cost'] ?? r['price'] ?? r['data'];
        if (v != null && v is! Map && v is! List) setState(() => _cost = '$v');
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_f.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final r = await Api.post('create_shipment.php', {
        'client_name': _name.text.trim(),
        'phone_1': _p1.text.trim(),
        'phone_2': _p2.text.trim(),
        'address': _addr.text.trim(),
        'sector_id': _sector,
        'product_name': _prod.text.trim(),
        'price': _cod.text.trim(),
        'order_id': _order.text.trim(),
        'notes': _notes.text.trim(),
        'weight': _weight.text.trim(),
        'quantity': _qty.text.trim(),
        if (_type != null) 'service_type': _type,
      });
      if (!mounted) return;
      String id = '', wb = '';
      Map<String, dynamic> shipment = {};
      if (r is Map) {
        for (final k in ['shipment', 'data', 'result']) {
          if (r[k] is Map) {
            shipment = Map<String, dynamic>.from(r[k] as Map);
            break;
          }
        }
        id = Api.pick(shipment.isNotEmpty ? shipment : r, ['id', 'shipment_id', 'shipping_id']);
        if (id.isEmpty) id = Api.pick(r, ['id', 'shipment_id', 'shipping_id']);
        wb = Api.pick(shipment.isNotEmpty ? shipment : r, ['waybill']);
      }
      await AppData.I.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wb.isEmpty ? tl('Shipment created') : '${tl('Shipment created')} $wb')));
      if (id.isEmpty && wb.isNotEmpty) {
        // find it in the refreshed list
        for (final x in AppData.I.shipments) {
          if (Api.pick(x, ['waybill']) == wb) {
            shipment = x;
            id = Api.pick(x, ['id']);
            break;
          }
        }
      }
      if (id.isNotEmpty) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipment: {...shipment, 'id': id})));
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String hint, TextEditingController c, {bool req = false, TextInputType? kt, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: kt,
          maxLines: lines,
          validator: req ? (v) => (v == null || v.trim().isEmpty) ? tl('Required') : null : null,
          decoration: InputDecoration(hintText: tl(hint) + (req ? ' *' : '')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tl('New shipment'))),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          _field('Customer name', _name, req: true),
          _field('Phone', _p1, req: true, kt: TextInputType.phone),
          _field('Second phone', _p2, kt: TextInputType.phone),
          _field('Address', _addr, req: true, lines: 2),
          FormField<String>(
            validator: (_) => _sector == null ? tl('Required') : null,
            builder: (st) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: !_loaded || _sectors.isEmpty ? null : () async {
                  final id = await _pickArea();
                  if (id != null) {
                    await _price(id);
                    st.didChange(id);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), errorText: st.errorText),
                  child: Text(
                    _sector != null ? _areaLabel(_sectors.firstWhere((e) => '${e['id']}' == _sector)) : (!_loaded ? tl('Loading areas…') : (_sectors.isEmpty ? tl('No areas returned') : tl('Area * (tap to search)'))),
                    style: TextStyle(color: _sector != null ? Brand.text : Brand.muted),
                  ),
                ),
              ),
            ]),
          ),
          if (_cost.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text('${tl('Shipping cost')}: $_cost ${tl('EGP')}', style: const TextStyle(color: Brand.orange))),
          const SizedBox(height: 8),
          if (_types.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _type,
                hint: Text(tl('Service type')),
                items: [for (final t in _types) DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}'))],
                onChanged: (v) => setState(() => _type = v),
              ),
            ),
          _field('Product', _prod, req: true),
          _field('COD amount (EGP)', _cod, req: true, kt: TextInputType.number),
          _field('Order number', _order),
          Row(children: [
            Expanded(child: _field('Weight (kg)', _weight, kt: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _field('Quantity', _qty, kt: TextInputType.number)),
          ]),
          _field('Notes', _notes, lines: 2),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: Brand.red))),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.dark)) : Text(tl('Create shipment')),
          ),
        ]),
      ),
    );
  }
}
