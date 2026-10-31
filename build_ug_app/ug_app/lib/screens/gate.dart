import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

int get _gateBranch {
  final b = Session.branchId;
  if (b != null) return b;
  final g = Lookups.gymBranches;
  return g.isNotEmpty ? g.first['id'] as int : 2;
}

String _reasonText(String r) => tr('gate_$r');

/// Phone as a gate scanner: scan the member's QR, shows green / red, can send a manual open command.
class GateScanScreen extends StatefulWidget {
  const GateScanScreen({super.key});
  @override
  State<GateScanScreen> createState() => _GateScanScreenState();
}

class _GateScanScreenState extends State<GateScanScreen> {
  bool busy = false;
  Map<String, dynamic>? result;

  Future<void> onCode(String code) async {
    if (busy) return;
    setState(() { busy = true; result = null; });
    try {
      final r = asMap(await Api.post('/api/gate/verify', {'code': code, 'branch_id': _gateBranch, 'gate': 'phone'}));
      if (mounted) setState(() => result = r);
    } catch (e) {
      if (mounted) setState(() => result = {'allow': false, 'reason': 'bad_code', 'name': errText(e)});
    }
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    if (mounted) setState(() { busy = false; result = null; });
  }

  Future<void> openGate() async {
    try {
      await Api.post('/api/gate/open', {'branch_id': _gateBranch});
      if (mounted) toast(context, tr('gate_opened'));
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final ok = r != null && r['allow'] == true;
    return Column(children: [
      Expanded(
        child: Stack(children: [
          MobileScanner(
            onDetect: (capture) {
              if (capture.barcodes.isEmpty) return;
              final v = capture.barcodes.first.rawValue;
              if (v != null && v.isNotEmpty) onCode(v);
            },
          ),
          if (r == null)
            Positioned(
              left: 0, right: 0, bottom: 24,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(tr('gate_point'), style: const TextStyle(color: Colors.white)),
              )),
            ),
          if (r != null)
            Positioned.fill(
              child: Container(
                color: (ok ? Palette.ok : Palette.bad).withOpacity(0.92),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(ok ? Icons.check_circle : Icons.cancel, size: 110, color: Colors.black87),
                  const SizedBox(height: 12),
                  Text(ok ? tr('gate_ok') : _reasonText(r['reason'] as String), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87)),
                  if (r['name'] != null) Text('${r['name']}', style: const TextStyle(fontSize: 20, color: Colors.black87)),
                  if (ok && r['days_left'] != null) Text('${r['days_left']} ${tr('days_left')}', style: const TextStyle(fontSize: 16, color: Colors.black87)),
                ]),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(onPressed: openGate, icon: const Icon(Icons.lock_open), label: Text(tr('gate_open'))),
      ),
    ]);
  }
}

/// Admin: entries by day with counts of allowed / denied.
class GateLogScreen extends StatefulWidget {
  const GateLogScreen({super.key});
  @override
  State<GateLogScreen> createState() => _GateLogScreenState();
}

class _GateLogScreenState extends State<GateLogScreen> {
  DateTime day = DateTime.now().toUtc().add(const Duration(hours: 3));
  int? branch;

  String get dayKey => '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('gate_log'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: Icon(isAr ? Icons.chevron_right : Icons.chevron_left), onPressed: () => setState(() => day = day.subtract(const Duration(days: 1)))),
          SizedBox(width: 150, child: Text(dayKey, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(icon: Icon(isAr ? Icons.chevron_left : Icons.chevron_right), onPressed: () => setState(() => day = day.add(const Duration(days: 1)))),
        ]),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BranchChips(selected: branch, onChanged: (v) => setState(() => branch = v))),
        const SizedBox(height: 8),
        Expanded(
          child: Loader<Map<String, dynamic>>(
            key: ValueKey('$dayKey-$branch'),
            load: () async => asMap(await Api.get('/api/gate/log', query: {'date': dayKey, if (branch != null) 'branch_id': '$branch'})),
            builder: (context, d, reload) {
              final items = asMaps(d['items']);
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Row(children: [
                    Expanded(child: StatTile(tr('gate_allowed'), '${d['allowed']}', color: Palette.ok)),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(tr('gate_denied'), '${d['denied']}', color: Palette.bad)),
                  ]),
                  const SizedBox(height: 12),
                  if (items.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(tr('gate_none'), style: const TextStyle(color: Palette.mute)))),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: UgCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Icon(it['result'] == 'allowed' ? Icons.check_circle : Icons.cancel, color: it['result'] == 'allowed' ? Palette.ok : Palette.bad),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text((it['member_name'] as String?) ?? (it['method'] == 'manual' ? tr('gate_method_manual') : '—'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text([
                              if (it['result'] != 'allowed') _reasonText(it['reason'] as String),
                              tr('gate_method_${it['method']}'),
                              if (it['branch_name'] != null) loc(it, 'branch_name'),
                            ].join(' · '), style: const TextStyle(color: Palette.mute, fontSize: 12)),
                          ])),
                          Text((it['created_at'] as String).substring(11, 16), style: const TextStyle(color: Palette.mute)),
                        ]),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
