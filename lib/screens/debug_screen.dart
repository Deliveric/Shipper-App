import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/theme.dart';

/// Shows the raw server replies so field names can be matched exactly.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const calls = <(String, Map<String, String>)>[
    ('my_shipments.php', {'page': '1', 'limit': '2'}),
    ('statusDashboard.php', {}),
    ('shipment_statuses.php', {}),
    ('get_shipper_filter_statuses.php', {}),
    ('getShipperBalance.php', {}),
    ('transactions_sum.php', {}),
    ('get_withdrawable_amount.php', {}),
    ('my_transactions.php', {'page': '1', 'limit': '2'}),
    ('user_info.php', {}),
  ];
  final Map<String, String> out = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (final c in calls) {
      try {
        final t = await Api.raw(c.$1, c.$2.isEmpty ? null : c.$2);
        out[c.$1] = t.length > 1800 ? '${t.substring(0, 1800)}…' : t;
      } catch (e) {
        out[c.$1] = 'ERROR: $e';
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final all = out.entries.map((e) => '### ${e.key}\n${e.value}').join('\n\n');
    return Scaffold(
      appBar: AppBar(title: const Text('Server replies'), actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () => Clipboard.setData(ClipboardData(text: all)),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (loading) const LinearProgressIndicator(color: Brand.orange),
        for (final e in out.entries) ...[
          Text(e.key, style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(e.value, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          const Divider(height: 24),
        ],
      ]),
    );
  }
}
