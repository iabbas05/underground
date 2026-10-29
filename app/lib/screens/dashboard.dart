import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int? branch;

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      key: ValueKey('${monthKey(month)}-$branch'),
      load: () async => asMap(await Api.get('/api/reports/summary', query: {'month': monthKey(month), if (branch != null) 'branch_id': '$branch'})),
      builder: (context, r, reload) {
        final members = asMap(r['members']);
        final daily = asMaps(r['daily']);
        final kinds = asMaps(r['by_kind']);
        final branches = asMaps(r['branches']);
        final profit = dbl(r['profit']);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MonthBar(month: month, onChanged: (d) => setState(() => month = d)),
            BranchChips(selected: branch, onChanged: (v) => setState(() => branch = v)),
            const SizedBox(height: 14),
            UgCard(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('profit'), style: const TextStyle(color: Palette.mute)),
                const SizedBox(height: 4),
                Text(money(profit), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: profit >= 0 ? Palette.ok : Palette.bad)),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatTile(tr('income'), money(dbl(r['income'])), color: Palette.violetSoft)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(tr('expenses'), money(dbl(r['expenses'])))),
              const SizedBox(width: 10),
              Expanded(child: StatTile(tr('salaries'), money(dbl(r['salaries'])))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatTile(tr('members_active'), '${members['active']}')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(tr('members_expiring'), '${members['expiring_7d']}', color: Palette.warn)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(tr('members_new'), '${members['new_this_month']}')),
            ]),
            SectionTitle(tr('daily_income')),
            UgCard(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: SizedBox(height: 170, child: BarChart(values: [for (final d in daily) dbl(d['v'])], labels: [for (final d in daily) (d['date'] as String).substring(8)])),
            ),
            if (kinds.isNotEmpty) ...[
              SectionTitle(tr('by_type')),
              UgCard(child: Column(children: [
                for (final k in kinds) _bar(tr('k_${k['kind']}'), dbl(k['v']), dbl(r['income'])),
              ])),
            ],
            if (branch == null) ...[
              SectionTitle(tr('by_branch')),
              for (final b in branches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: UgCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Expanded(child: Text(loc(b, 'name'), style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('+${money(dbl(b['income']))}', style: const TextStyle(color: Palette.ok, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      Text('-${money(dbl(b['expenses']))}', style: const TextStyle(color: Palette.bad)),
                    ]),
                  ),
                ),
            ],
          ]),
        );
      },
    );
  }

  Widget _bar(String label, double v, double total) {
    final f = total <= 0 ? 0.0 : (v / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(money(v), style: const TextStyle(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: f, minHeight: 8, backgroundColor: Palette.line, color: Palette.violet)),
      ]),
    );
  }
}

/// Simple bar chart drawn with CustomPaint (no extra packages).
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const BarChart({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return Center(child: Text(tr('no_results'), style: const TextStyle(color: Palette.mute)));
    return CustomPaint(painter: _BarPainter(values, labels, Directionality.of(context) == TextDirection.rtl), size: Size.infinite);
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final bool rtl;
  _BarPainter(this.values, this.labels, this.rtl);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final chartH = size.height - 20;
    final slot = size.width / values.length;
    final barW = (slot * 0.6).clamp(3.0, 22.0);
    final paint = Paint()..color = Palette.violet;
    final step = (values.length / 8).ceil();
    for (var n = 0; n < values.length; n++) {
      final i = rtl ? values.length - 1 - n : n;
      final h = maxV <= 0 ? 0.0 : (values[n] / maxV) * (chartH - 14);
      final x = i * slot + (slot - barW) / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, chartH - h, barW, h < 2 ? 2 : h), const Radius.circular(4));
      canvas.drawRRect(rect, paint);
      if (n % step == 0) {
        final tp = TextPainter(text: TextSpan(text: labels[n], style: const TextStyle(color: Palette.mute, fontSize: 10)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(i * slot + (slot - tp.width) / 2, chartH + 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.values != values;
}
