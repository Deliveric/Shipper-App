import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/strings.dart';
import '../core/theme.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String _balance = '-';
  List<Map<String, dynamic>> _tx = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await Api.get('getShipperBalance.php');
      final t = await Api.get('my_transactions.php');
      if (!mounted) return;
      setState(() {
        _balance = b is Map
            ? Api.pick(b['data'] is Map ? b['data'] : b, ['balance', 'amount', 'total'], '-')
            : '$b';
        _tx = Api.listOf(t);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'accounts'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Brand.orange))
          : RefreshIndicator(
              color: Brand.orange,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Brand.dark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Image.asset('assets/image/income.png', width: 44),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(context, 'balance'), style: const TextStyle(color: Colors.white70)),
                        Text(_balance,
                            style: const TextStyle(
                                color: Brand.orange, fontSize: 28, fontWeight: FontWeight.w700)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text(tr(context, 'transactions'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final t in _tx)
                    Card(
                      child: ListTile(
                        title: Text(Api.pick(t, ['title', 'type', 'note', 'description', 'id'])),
                        subtitle: Text(Api.pick(t, ['date', 'created_at'])),
                        trailing: Text(Api.pick(t, ['amount', 'total']),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
