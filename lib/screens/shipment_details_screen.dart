import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/strings.dart';
import '../core/theme.dart';

class ShipmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> shipment;
  const ShipmentDetailsScreen({super.key, required this.shipment});
  @override
  State<ShipmentDetailsScreen> createState() => _ShipmentDetailsScreenState();
}

class _ShipmentDetailsScreenState extends State<ShipmentDetailsScreen> {
  late Map<String, dynamic> s = widget.shipment;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final id = Api.pick(s, ['id', 'shipment_id']);
    if (id.isEmpty) return;
    try {
      final r = await Api.get('shipment.php', {'id': id});
      final d = r is Map ? (r['data'] is Map ? r['data'] : r) : null;
      if (d is Map && mounted) setState(() => s = {...s, ...Map<String, dynamic>.from(d)});
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final phone = Api.pick(s, ['phone', 'client_phone', 'mobile', 'receiver_phone']);
    final wa = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'details'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Center(child: Image.asset('assets/image/logo.png', height: 90)),
          _row(tr(context, 'status'), Api.pick(s, ['status_name', 'status'])),
          _row(tr(context, 'customer'), Api.pick(s, ['client_name', 'customer_name', 'name'])),
          _row(tr(context, 'address'), Api.pick(s, ['address', 'client_address', 'city'])),
          _row(tr(context, 'cod'), Api.pick(s, ['cod', 'amount', 'total'])),
          const SizedBox(height: 14),
          if (phone.isNotEmpty)
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: Text(tr(context, 'call')),
                  onPressed: () => _open('tel:$phone'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Brand.green),
                  icon: const Icon(Icons.chat),
                  label: Text(tr(context, 'whatsapp')),
                  onPressed: () => _open('https://wa.me/$wa'),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => v.isEmpty
      ? const SizedBox.shrink()
      : Card(
          child: ListTile(
            title: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            subtitle: Text(v, style: const TextStyle(color: Brand.dark, fontSize: 16)),
          ),
        );
}
