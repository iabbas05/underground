import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'pass_sheet.dart';

class MemberDetail extends StatefulWidget {
  final int id;
  const MemberDetail({super.key, required this.id});
  @override
  State<MemberDetail> createState() => _MemberDetailState();
}

class _MemberDetailState extends State<MemberDetail> {
  int version = 0;

  void refresh() => setState(() => version++);

  Future<void> renew(Map<String, dynamic> m) async {
    int? planId = m['plan_id'] as int?;
    String method = 'cash';
    final ok = await showSheet<bool>(context, StatefulBuilder(builder: (ctx, set) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(tr('renew'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Choice<int>(label: tr('plan'), value: planId, options: [for (final x in Lookups.plans) MapEntry(x['id'] as int, planLabel(x))], onChanged: (v) => set(() => planId = v)),
        const SizedBox(height: 12),
        Choice<String>(label: tr('payment_method'), value: method, options: methodOptions(), onChanged: (v) => set(() => method = v ?? 'cash')),
        const SizedBox(height: 18),
        FilledButton(onPressed: planId == null ? null : () => Navigator.pop(ctx, true), child: Text(tr('renew'))),
      ]);
    }));
    if (ok != true || !mounted) return;
    try {
      await Api.post('/api/members/${m['id']}/renew', {'plan_id': planId, 'method': method});
      if (!mounted) return;
      toast(context, tr('renewed'));
      refresh();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> extend(Map<String, dynamic> m) async {
    final days = TextEditingController();
    final note = TextEditingController();
    final ok = await showSheet<bool>(context, Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(tr('extend_days'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      TextField(controller: days, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('days'))),
      const SizedBox(height: 12),
      TextField(controller: note, decoration: InputDecoration(labelText: tr('note'))),
      const SizedBox(height: 18),
      Builder(builder: (ctx) => FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save')))),
    ]));
    final n = int.tryParse(days.text.trim());
    if (ok != true || n == null || !mounted) return;
    try {
      await Api.post('/api/members/${m['id']}/extend', {'days': n, 'note': note.text.trim()});
      if (!mounted) return;
      toast(context, tr('extended'));
      refresh();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(version),
        load: () async => asMap(await Api.get('/api/members/${widget.id}')),
        builder: (context, m, reload) {
          final status = m['status'] as String;
          final payments = asMaps(m['payments']);
          return ListView(padding: const EdgeInsets.all(16), children: [
            UgCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(m['name'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                Pill(statusText(status), statusColor(status)),
              ]),
              const SizedBox(height: 6),
              Text(m['phone'] as String, style: const TextStyle(color: Palette.mute), textDirection: TextDirection.ltr),
              const Divider(height: 28),
              _row(tr('plan'), loc(m, 'plan_name')),
              _row(tr('branch'), loc(m, 'branch_name')),
              _row(tr('ends_on'), m['end_date'] as String),
              _row(tr('days_left'), '${(m['days_left'] as num) < 0 ? 0 : m['days_left']}'),
              if ((m['notes'] as String?)?.isNotEmpty ?? false) _row(tr('note'), m['notes'] as String),
            ])),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () => showPassSheet(context, m['id'] as int, m['name'] as String), icon: const Icon(Icons.qr_code_2), label: Text(tr('pass_show'))),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: () => renew(m), icon: const Icon(Icons.autorenew), label: Text(tr('renew'))),
            if (Session.isAdmin) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: () => extend(m), icon: const Icon(Icons.add_circle_outline), label: Text(tr('extend_days'))),
            ],
            SectionTitle(tr('payments')),
            for (final p in payments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: UgCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['date'] as String),
                      Text('${tr('k_${p['kind']}')} · ${tr('m_${p['method']}')}', style: const TextStyle(color: Palette.mute, fontSize: 12)),
                    ])),
                    Text(money(dbl(p['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Palette.mute)),
          Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}
