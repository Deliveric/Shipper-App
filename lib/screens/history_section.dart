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
  int _lastLen = -1;

  /// start at the newest period (right end), as the curve does
  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

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
    final target = (ri * 204.0 - (pos.viewportDimension / 2 - 98)).clamp(0.0, pos.maxScrollExtent);
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
          ] else ...[
            Text(tl('No history yet'), style: const TextStyle(color: Brand.muted)),
            if (d.historyError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(d.historyError!, textAlign: TextAlign.center, style: const TextStyle(color: Brand.red, fontSize: 11))),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.orange, foregroundColor: Brand.dark),
              onPressed: () => d.reloadAll(),
              icon: const Icon(Icons.download),
              label: Text(tl('Load history')),
            ),
          ],
        ]),
      );
    }
    final keys = ps.map((e) => e.key).toList();
    if (ps.length != _lastLen) {
      _lastLen = ps.length;
      _toEnd();
    }
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
                _lastLen = -1;
              })),
          seg(tl('Years'), _years, () => setState(() {
                _years = true;
                _sel = null;
                _lastLen = -1;
              })),
        ]),
      ),
      const SizedBox(height: 8),
      // slider of periods, oldest on the left (same direction as the curves)
      SizedBox(
        height: 124,
        child: ListView(controller: _scroll, scrollDirection: Axis.horizontal, children: [
          for (final e in ps)
            GestureDetector(
              onTap: () {
                setState(() => _sel = e.key);
                _follow(keys.indexOf(e.key));
              },
              child: Container(
                width: 196,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  // green = both up, red = both down, amber = mixed
                  color: _tint(chg(cnt, keys.indexOf(e.key)), chg(net, keys.indexOf(e.key))),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: e.key == sel ? Brand.orange : Colors.transparent, width: 1.6),
                ),
                child: Builder(builder: (context) {
                  final ix = keys.indexOf(e.key);
                  final pc = chg(cnt, ix), pn = chg(net, ix);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_isCurrent(e.key) ? '${_label(e.key)} *' : _label(e.key), style: TextStyle(fontSize: 15, color: e.key == sel ? Brand.orange : Brand.muted, fontWeight: FontWeight.w800)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tl('Shipments delivered'), style: const TextStyle(fontSize: 9.5, color: Brand.muted)),
                      Row(children: [
                        Text(fmt(e.value.delivered), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _trendColor(pc))),
                        const Spacer(),
                        _pct(pc, small: true),
                      ]),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tl('Net profit (EGP)'), style: const TextStyle(fontSize: 9.5, color: Brand.muted)),
                      Row(children: [
                        Text(fmt(_net(e.value)), maxLines: 1, softWrap: false, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: pn == null ? (_net(e.value) >= 0 ? const Color(0xFF5BC47A) : Brand.red) : _trendColor(pn))), // fixed size, never shrinks
                        const Spacer(),
                        _pct(pn, small: true),
                      ]),
                    ]),
                  ]);
                }),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 18),
      // chosen period
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // darker than the period cards above, with a thin frame and a soft shadow, so it reads as its own card
          color: const Color(0xFF16160F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x55E2964E), width: 1.2),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_label(sel, full: true), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Brand.orange, letterSpacing: .3)),
            if (si > 0) Text('% ${_years ? tl('vs previous year') : tl('vs previous month')}${_isCurrent(sel) ? ' *' : ''}', style: const TextStyle(color: Brand.muted, fontSize: 10.5)),
          ]),
          Container(height: 2, margin: const EdgeInsets.only(top: 8, bottom: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [Brand.orange, Color(0x00E2964E)]))),
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
                    '${_years ? tl('Current year') : tl('Current month')} — ${tl('numbers are up to today')} (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}). ${_years ? tl('The year is not over yet, so numbers may look lower.') : tl('The month is not over yet, so numbers may look lower.')}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFB74D), height: 1.35),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          Row(children: [
            _mini('${tl('Delivered')} / ${tl('Returned')}', '', valueWidget: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt(cur.delivered), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Brand.orange)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text('/', style: TextStyle(fontSize: 14, color: Brand.muted))),
              Padding(padding: const EdgeInsets.only(bottom: 1), child: Text(fmt(cur.returned), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFF9800)))),
            ])),
            const SizedBox(width: 8),
            _mini(tl('COD collected'), '${fmt(cur.cod)} ${tl('EGP')}', pct: pctCod),
          ]),
          const SizedBox(height: 16),
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
          _follow(i); // the slider (oldest on the left, like the curves) moves with them
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

  Color? _trendColor(double? p) => p == null ? null : (p >= 0 ? const Color(0xFF5BC47A) : Brand.red);

  /// card background from the shipments and the net profit trends:
  /// both up = green, both down = red, one up and one down = amber
  Color _tint(double? a, double? b) {
    final l = [a, b].whereType<double>().toList();
    if (l.isEmpty) return Brand.card;
    final c = l.every((x) => x >= 0) ? const Color(0xFF5BC47A) : (l.every((x) => x < 0) ? Brand.red : const Color(0xFFFFB74D));
    return Color.alphaBlend(c.withOpacity(.16), Brand.card);
  }

  /// small arrow + percentage versus the previous period
  Widget _pct(double? p, {bool small = false}) {
    if (p == null) return const SizedBox.shrink();
    final up = p >= 0;
    final c = up ? const Color(0xFF5BC47A) : Brand.red;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: small ? 10 : 14, color: c),
      Text('${p.abs().toStringAsFixed(2)}%', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: small ? 10 : 13)),
    ]);
  }

  Widget _trend(double pct, String sub) {
    final up = pct >= 0;
    final c = up ? const Color(0xFF5BC47A) : Brand.red;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: c),
      Text('${pct.abs().toStringAsFixed(2)}%', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
      const SizedBox(width: 4),
      Flexible(child: Text(sub, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 10.5))),
    ]);
  }

  Widget _mini(String k, String v, {bool green = false, String? note, double? pct, Color? valueColor, Widget? valueWidget}) {
    // growth = green, decline = red: the box and the figure take the colour of the arrow
    final Color? c = pct == null ? null : (pct >= 0 ? const Color(0xFF5BC47A) : Brand.red);
    return Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c == null ? Brand.card2 : c.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
            valueWidget ?? Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c ?? valueColor)),
            if (pct != null) Padding(padding: const EdgeInsets.only(top: 2), child: _pct(pct)),
            if (note != null) Text(note, style: const TextStyle(fontSize: 9.5, color: Brand.muted)),
          ]),
        ),
      );
  }
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
