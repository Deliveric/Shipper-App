import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'shipment_details_screen.dart';

class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});
  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [], _statuses = [];
  String _status = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    _load();
  }

  Future<void> _loadStatuses() async {
    try {
      final r = await Api.get('shipment_statuses.php');
      if (mounted) setState(() => _statuses = Api.listOf(r));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.get('my_shipments.php', {
        'page': '1',
        if (_status.isNotEmpty) 'general_status': _status,
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      });
      if (mounted) setState(() => _items = Api.listOf(r));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/image/icon.png', height: 34),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: tr(context, 'search'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Image.asset('assets/image/scanner.png', width: 24),
                  onPressed: () {},
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _chip(tr(context, 'all'), ''),
                for (final s in _statuses)
                  _chip(Api.pick(s, ['name', 'title', 'status_name']),
                      Api.pick(s, ['key', 'general_status', 'id', 'slug'])),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final on = _status == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        selectedColor: Brand.orange,
        labelStyle: TextStyle(color: on ? Colors.white : Brand.dark),
        onSelected: (_) {
          _status = value;
          _load();
        },
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Brand.orange));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: Text(tr(context, 'retry'))),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/image/empty_box.png', width: 140),
          Text(tr(context, 'empty')),
        ]),
      );
    }
    return RefreshIndicator(
      color: Brand.orange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) => _card(_items[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final code = Api.pick(s, ['code', 'tracking', 'shipment_code', 'id']);
    final name = Api.pick(s, ['client_name', 'customer_name', 'name', 'receiver_name']);
    final status = Api.pick(s, ['status_name', 'status', 'general_status']);
    final cod = Api.pick(s, ['cod', 'amount', 'total', 'price']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipment: s)),
        ),
        leading: Image.asset('assets/image/shipment_car.png', width: 46),
        title: Text('#$code', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([name, status].where((e) => e.isNotEmpty).join('  •  ')),
        trailing: cod.isEmpty
            ? null
            : Text('$cod', style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
