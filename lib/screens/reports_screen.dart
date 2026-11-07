import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/strings.dart';
import '../core/theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.get('my_shipments.php', {'page': '1', 'limit': '1000'});
      final c = <String, int>{};
      for (final s in Api.listOf(r)) {
        final st = Api.status(s).isEmpty ? '-' : Api.status(s);
        c[st] = (c[st] ?? 0) + 1;
      }
      if (mounted) setState(() => _counts..clear()..addAll(c));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _counts.values.fold<int>(0, (a, b) => a + b);
    final entries = _counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'reports'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Brand.orange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                Text(tr(context, 'by_status'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (entries.isEmpty) Text(tr(context, 'empty'), style: const TextStyle(color: Brand.muted)),
                for (final e in entries)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(e.key)),
                          Text('${e.value}',
                              style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : e.value / total,
                            minHeight: 8,
                            color: Brand.orange,
                            backgroundColor: Brand.card2,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}
