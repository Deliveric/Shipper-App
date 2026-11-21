import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/util.dart';

/// Stats → "Months": a slider of every past month (or year), the figures of the chosen one
/// and a curve of the growth / decline over time. Follows the accounts shown (combined too).
class HistorySection extends StatefulWidget {
  const HistorySection({super.key});
  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  bool _years = false;
  String? _sel; // selected period key
  final _scroll = ScrollController();

  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  num _net(MonthStat s) => s.cod - s.fees; // net profit = COD collected - shipping fees

  /// ordered (oldest first) list of period key -> totals
  List<MapEntry<String, MonthStat>> _periods(Map<String, MonthStat> m) {
    if (!_years) return (m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    final y = <String, MonthStat>{};
    m.forEach((k, v) => (y[k.substring(0, 4)] ??= MonthStat()).add(v));
    return y.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  bool _isCurrent(String k) {
    final n = DateTime.now();
    return _years ? k == '${n.year}' : k == '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  String _label(String k, {bool full = false}) {
    if (_years) return k;
    final mo = int.parse(k.substring(5));
    final y = k.substring(0, 4);
    return full ? '${tl(_mon[mo - 1])} $y' : '${tl(_mon[mo - 1])} ${y.substring(2)}';
  }

  /// scroll the period slider so card [ri] (position from the left) sits in the middle
  void _follow(int ri) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = (ri * 120.0 - (pos.viewportDimension / 2 - 56)).clamp(0.0, pos.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 140), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = AppData.I;
    final ps = _periods(d.monthly);
    if (ps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          if (d.historyLoading) ...[
            const SizedBox(width: 38, height: 38, child: CircularProgressIndicator(color: Brand.orange, strokeWidth: 4)),
            const SizedBox(height: 12),
            Text(tl('Loading history… the first time takes a minute'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ] else
            Text(tl('No history yet'), style: const TextStyle(color: Brand.muted)),
        ]),
      );
    }
    final keys = ps.map((e) => e.key).toList();
    final sel = (_sel != null && keys.contains(_sel)) ? _sel! : keys.last;
    final si = keys.indexOf(sel);
    final cnt = ps.map((e) => e.value.delivered).toList();
    final net = ps.map((e) => _net(e.value)).toList();
    final cur = ps[si].value;
    double? chg(List<num> v, int i) => (i == 0 || v[i - 1] == 0) ? null : (v[i] - v[i - 1]) / v[i - 1] * 100;
    double? overall(List<num> v) => v.first == 0 ? null : (v.last - v.first) / v.first * 100;
    final cod = ps.map((e) => e.value.cod).toList();
    final pctCnt = chg(cnt, si), pctCod = chg(cod, si), pctNet = chg(net, si);

    Widget seg(String t, bool on, VoidCallback f) => Expanded(
          child: GestureDetector(
            onTap: f,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? Brand.orange : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Brand.dark : Brand.muted)),
            ),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (d.historyLoading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(color: Brand.orange, minHeight: 3)),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          seg(tl('Months'), !_years, () => setState(() {
                _years = false;
                _sel = null;
              })),
          seg(tl('Years'), _years, () => setState(() {
                _years = true;
                _sel = null;
              })),
        ]),
      ),
      const SizedBox(height: 8),
      // slider of periods, newest first
      SizedBox(
        height: 92,
        child: ListView(controller: _scroll, scrollDirection: Axis.horizontal, children: [
          for (final e in ps.reversed)
            GestureDetector(
              onTap: () {
                setState(() => _sel = e.key);
                _follow(ps.length - 1 - keys.indexOf(e.key));
              },
              child: Container(
                width: 112,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Brand.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: e.key == sel ? Brand.orange : Colors.transparent, width: 1.6),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_isCurrent(e.key) ? '${_label(e.key)} *' : _label(e.key), style: TextStyle(fontSize: 12, color: e.key == sel ? Brand.orange : Brand.muted, fontWeight: FontWeight.w600)),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${e.value.delivered}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(tl('shipments'), style: const TextStyle(fontSize: 10.5, color: Brand.muted))),
                  ]),
                  Text('${fmt(_net(e.value))} ${tl('EGP')}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF5BC47A), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      // chosen period
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_label(sel, full: true).toUpperCase(), style: const TextStyle(fontSize: 12, color: Brand.muted, letterSpacing: .8)),
            if (si > 0) Text('% ${_years ? tl('vs previous year') : tl('vs previous month')}${_isCurrent(sel) ? ' *' : ''}', style: const TextStyle(color: Brand.muted, fontSize: 10.5)),
          ]),
          if (_isCurrent(sel))
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0x22FFB74D), borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFFFFB74D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_years ? tl('Current year') : tl('Current month')} — ${tl('numbers are up to today')} (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}). ${tl('The period is not over yet, so they look lower.')}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFB74D), height: 1.35),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${cur.delivered}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Brand.orange)),
            const Padding(padding: EdgeInsets.fromLTRB(6, 0, 6, 6), child: Text('/', style: TextStyle(fontSize: 24, color: Brand.muted))),
            Text('${cur.returned}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Brand.red)),
            const Spacer(),
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _pct(pctCnt)),
          ]),
          Text('${tl('Delivered')} / ${tl('Returned')} (${tl('shipments')})', style: const TextStyle(color: Brand.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            _mini(tl('COD collected'), '${fmt(cur.cod)} ${tl('EGP')}', pct: pctCod),
            const SizedBox(width: 8),
            _mini(tl('Net profit'), '${fmt(_net(cur))} ${tl('EGP')}', green: true, note: tl('COD − shipping fees'), pct: pctNet),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      // curve
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tl('Growth curve'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _chart(tl('Shipments delivered (count)'), cnt.map((e) => e.toDouble()).toList(), keys, si, overall(cnt), (i) => '${fmt(cnt[i])} ${tl('shipments')}'),
          const SizedBox(height: 14),
          _chart(tl('Net profit (EGP)'), net.map((e) => e.toDouble()).toList(), keys, si, overall(net), (i) => '${fmt(net[i])} ${tl('EGP')}'),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_label(keys.first), style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
            if (keys.length > 2) Text(_label(keys[keys.length ~/ 2]), style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
            Text(_label(keys.last), style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
          ]),
        ]),
      ),
    ]);
  }

  Widget _chart(String title, List<double> v, List<String> keys, int si, double? overall, String Function(int) tipOf) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(title, style: const TextStyle(fontSize: 11.5, color: Brand.muted))),
      ]),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (context, c) {
        void pick(double dx) {
          final n = keys.length;
          final i = n == 1 ? 0 : (((dx - 6) / (c.maxWidth - 12)) * (n - 1)).round().clamp(0, n - 1);
          setState(() => _sel = keys[i]);
          _follow(n - 1 - i); // the slider (newest first) moves with the curves
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => pick(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(painter: _CurvePainter(v, si, '${_label(keys[si], full: true)}${_isCurrent(keys[si]) ? ' *' : ''}\n${tipOf(si)}')),
          ),
        );
      }),
    ]);
  }

  /// small arrow + percentage versus the previous period
  Widget _pct(double? p) {
    if (p == null) return const SizedBox.shrink();
    final up = p >= 0;
    final c = up ? const Color(0xFF5BC47A) : Brand.red;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: c),
      Text('${p.abs().toStringAsFixed(0)}%', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
    ]);
  }

  Widget _trend(double pct, String sub) {
    final up = pct >= 0;
    final c = up ? const Color(0xFF5BC47A) : Brand.red;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: c),
      Text('${pct.abs().toStringAsFixed(0)}%', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
      const SizedBox(width: 4),
      Flexible(child: Text(sub, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 10.5))),
    ]);
  }

  Widget _mini(String k, String v, {bool green = false, String? note, double? pct}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: green ? const Color(0xFF2C3A2C) : Brand.card2, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
            Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: green ? const Color(0xFF5BC47A) : null)),
            if (pct != null) Padding(padding: const EdgeInsets.only(top: 2), child: _pct(pct)),
            if (note != null) Text(note, style: const TextStyle(fontSize: 9.5, color: Brand.muted)),
          ]),
        ),
      );
}

class _CurvePainter extends CustomPainter {
  final List<double> v;
  final int sel;
  final String tip;
  _CurvePainter(this.v, this.sel, this.tip);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final mx = v.reduce((a, b) => a > b ? a : b);
    final top = mx <= 0 ? 1.0 : mx * 1.1;
    const padX = 6.0, padT = 40.0, padB = 6.0;
    final w = size.width - padX * 2, h = size.height - padT - padB;
    Offset pt(int i) => Offset(padX + (v.length == 1 ? w / 2 : w * i / (v.length - 1)), padT + h * (1 - v[i] / top));
    final grid = Paint()..color = const Color(0x22FFFFFF)..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = padT + h * g / 3;
      canvas.drawLine(Offset(padX, y), Offset(size.width - padX, y), grid);
    }
    final pts = [for (var i = 0; i < v.length; i++) pt(i)];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy); // smooth curve
    }
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, padT + h)
      ..lineTo(pts.first.dx, padT + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Brand.orange.withOpacity(.35), Brand.orange.withOpacity(0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(path, Paint()..color = Brand.orange..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
    if (v.length <= 24) {
      for (final p in pts) {
        canvas.drawCircle(p, 2.6, Paint()..color = Brand.orange);
      }
    }
    final s = pts[sel.clamp(0, pts.length - 1)];
    canvas.drawCircle(s, 7, Paint()..color = Brand.orange.withOpacity(.25));
    canvas.drawCircle(s, 4.5, Paint()..color = Brand.orange);
    canvas.drawCircle(s, 2, Paint()..color = Brand.dark);
    // guide line + bubble with the figure of the touched point
    canvas.drawLine(Offset(s.dx, s.dy), Offset(s.dx, padT + h), Paint()..color = Brand.orange.withOpacity(.4)..strokeWidth = 1);
    final tp = TextPainter(
      text: TextSpan(text: tip, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1B1B17), height: 1.25)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final bw = tp.width + 16, bh = tp.height + 10;
    final bx = (s.dx - bw / 2).clamp(0.0, size.width - bw);
    final by = (s.dy - bh - 12).clamp(0.0, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(10)), Paint()..color = Brand.orange);
    tp.paint(canvas, Offset(bx + 8, by + 5));
  }

  @override
  bool shouldRepaint(_CurvePainter o) => o.v != v || o.sel != sel || o.tip != tip;
}
