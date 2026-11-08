import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/data.dart';
import '../core/theme.dart';

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
        'price': _cod.text.trim().isEmpty ? '0' : _cod.text.trim(),
        'order_id': _order.text.trim(),
        'notes': _notes.text.trim(),
        'weight': _weight.text.trim(),
        'quantity': _qty.text.trim(),
        if (_type != null) 'service_type': _type,
      });
      if (!mounted) return;
      final wb = r is Map ? Api.pick(r, ['waybill', 'message']) : '';
      await AppData.I.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wb.isEmpty ? 'Shipment created' : 'Shipment created $wb')));
      Navigator.of(context).pop();
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
          validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
          decoration: InputDecoration(hintText: hint + (req ? ' *' : '')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New shipment')),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          _field('Customer name', _name, req: true),
          _field('Phone', _p1, req: true, kt: TextInputType.phone),
          _field('Second phone', _p2, kt: TextInputType.phone),
          _field('Address', _addr, req: true, lines: 2),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _sector,
              hint: Text(!_loaded ? 'Loading areas…' : (_sectors.isEmpty ? 'No areas returned' : 'Area *')),
              validator: (v) => v == null ? 'Required' : null,
              items: [for (final s in _sectors) DropdownMenuItem(value: '${s['id']}', child: Text('${s['name']}'.split(' - ').first, overflow: TextOverflow.ellipsis))],
              onChanged: _price,
            ),
          ),
          if (_cost.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text('Shipping cost: $_cost EGP', style: const TextStyle(color: Brand.orange))),
          const SizedBox(height: 8),
          if (_types.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _type,
                hint: const Text('Service type'),
                items: [for (final t in _types) DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}'))],
                onChanged: (v) => setState(() => _type = v),
              ),
            ),
          _field('Product', _prod, req: true),
          _field('COD amount (EGP)', _cod, kt: TextInputType.number),
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
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.dark)) : const Text('Create shipment'),
          ),
        ]),
      ),
    );
  }
}
