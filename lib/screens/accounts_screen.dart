import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/util.dart';

/// Wallet tab: Net Deserved, The Transferable Amount, details and latest transactions.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String _f = 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final d = AppData.I;
        final tx = d.tx.where((t) {
          switch (_f) {
            case 'Delivered':
              return t.isDelivery;
            case 'Returns':
              return t.isReturn;
            case 'Payouts':
              return t.isPayout;
          }
          return true;
        }).take(25).toList();
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'wallet'))),
          body: RefreshIndicator(
            color: Brand.orange,
            onRefresh: d.refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 110), children: [
              if (d.loading) const LinearProgressIndicator(color: Brand.orange, minHeight: 3),
              const SizedBox(height: 6),
              Row(children: [
                _chip(tl('Net Deserved'), d.net, outlined: true),
                const SizedBox(width: 10),
                _chip(tl('The Transferable Amount'), d.transferable),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
                child: Text(tl('LATEST TRANSACTIONS'), style: const TextStyle(fontSize: 12, color: Brand.muted, letterSpacing: .8)),
              ),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final n in ['All', 'Delivered', 'Returns', 'Payouts'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                      child: ChoiceChip(
                        label: Text(tl(n)),
                        selected: _f == n,
                        selectedColor: Brand.orange,
                        labelStyle: TextStyle(fontSize: 12, color: _f == n ? Brand.dark : Brand.muted),
                        backgroundColor: Brand.card,
                        side: BorderSide.none,
                        onSelected: (_) => setState(() => _f = n),
                      ),
                    ),
                ]),
              ),
              if (tx.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(d.loading ? tl('Loading transactions…') : tr(context, 'empty'), style: const TextStyle(color: Brand.muted))),
                ),
              for (final t in tx) _tx(context, t),
            ]),
          ),
        );
      },
    );
  }

  Widget _tx(BuildContext context, Tx t) {
    final n = t.net;
    final d = t.date;
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: Brand.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.isPayout ? '${t.label} ${tl('to you')}' : t.waybill, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _row(tl('Type'), t.label),
              _row(tl('Date'), date),
              _row(tl('Amount'), '${fmt(t.value)} ${tl('EGP')}'),
              if (!t.isPayout && t.type != '60' && t.type != '151') ...[
                _row(tl('Shipping fee'), '${fmt(t.fee)} ${tl('EGP')}'),
                _row(tl('Commission'), '${fmt(t.commission)} ${tl('EGP')}'),
                _row(tl('Net to you'), '${fmt(t.value - t.fee)} ${tl('EGP')}'),
              ],
              _row(tl('Payment report'), t.report > 0 ? '#${t.report}' : tl('not paid yet')),
              _row(tl('Transaction id'), '${t.id}'),
            ]),
          ),
        ),
        title: Text(t.isPayout ? '${t.label} ${tl('to you')}' : (t.waybill.isEmpty ? t.label : t.waybill), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text('${t.label} · $date', style: const TextStyle(fontSize: 11.5)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${n < 0 ? '-' : '+'}${fmt(n.abs())} ${tl('EGP')}', style: TextStyle(color: n < 0 ? Brand.red : Brand.green, fontWeight: FontWeight.w700)),
          Text(t.isPayout ? tl('payout') : 'COD ${fmt(t.value)} · ${tl('Shipping fee')} ${fmt(t.fee)}', style: const TextStyle(fontSize: 11, color: Brand.muted)),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Brand.muted, fontSize: 13)),
          Flexible(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _chip(String label, num v, {bool outlined = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: outlined ? Brand.dark : Brand.orange,
            borderRadius: BorderRadius.circular(18),
            border: outlined ? Border.all(color: Brand.orange, width: 1.5) : null,
          ),
          child: Column(children: [
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: outlined ? Brand.muted : const Color(0xFF3B2A14))),
            const SizedBox(height: 4),
            Text(fmt(v), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: outlined ? Brand.orange : Brand.dark)),
          ]),
        ),
      );
}
