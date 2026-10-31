import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Date (YYYY-MM-DD, Bahrain) of the next occurrence of weekday [day] (Sun=0..Sat=6), starting today.
String dateForDay(int day) {
  final bh = DateTime.now().toUtc().add(const Duration(hours: 3));
  final today = DateTime.utc(bh.year, bh.month, bh.day);
  final diff = (day - today.weekday % 7 + 7) % 7;
  final d = today.add(Duration(days: diff));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Staff view of one class on one date: who booked, who waits; remove or mark attended.
Future<void> showRoster(BuildContext context, int scheduleId, String date) =>
    showSheet<void>(context, _RosterBody(scheduleId: scheduleId, date: date));

class _RosterBody extends StatefulWidget {
  final int scheduleId;
  final String date;
  const _RosterBody({required this.scheduleId, required this.date});
  @override
  State<_RosterBody> createState() => _RosterBodyState();
}

class _RosterBodyState extends State<_RosterBody> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = asMap(await Api.get('/api/classes/roster', query: {'schedule_id': '${widget.scheduleId}', 'date': widget.date}));
      if (mounted) setState(() { data = r; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    }
  }

  Future<void> act(String path) async {
    try {
      await Api.post(path, {});
      await load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> editCapacity(int current) async {
    final ctrl = TextEditingController(text: '$current');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        title: Text(tr('capacity')),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.put('/api/schedule/${widget.scheduleId}', {'capacity': int.tryParse(ctrl.text.trim()) ?? current});
      await load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Color color(String s) => s == 'booked' || s == 'attended' ? Palette.ok : s == 'no_show' ? Palette.bad : Palette.warn;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (error != null) return Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: const TextStyle(color: Palette.bad)));
    if (d == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    final sc = asMap(d['schedule']);
    final items = asMaps(d['items']);
    final cap = (sc['capacity'] as num).toInt();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${fmtTime(sc['time'] as String)} · ${tr('lvl_${sc['level']}')}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('${widget.date} · ${d['taken']}/$cap', textAlign: TextAlign.center, style: const TextStyle(color: Palette.mute)),
      if (Session.isAdmin) TextButton(onPressed: () => editCapacity(cap), child: Text(tr('capacity'))),
      const SizedBox(height: 8),
      if (items.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(tr('roster_empty'), style: const TextStyle(color: Palette.mute)))),
      for (final it in items)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Palette.bg, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(it['phone'] as String, style: const TextStyle(color: Palette.mute, fontSize: 12)),
              ]),
            ),
            Pill(tr('st_${it['status']}'), color(it['status'] as String)),
            if (it['status'] == 'booked') IconButton(tooltip: tr('mark_attended'), icon: const Icon(Icons.check_circle_outline, color: Palette.ok), onPressed: () => act('/api/class-bookings/${it['id']}/attend')),
            if (it['status'] == 'booked' || it['status'] == 'waitlist' || it['status'] == 'offered')
              IconButton(tooltip: tr('remove_booking'), icon: const Icon(Icons.person_remove_outlined, color: Palette.bad), onPressed: () => act('/api/class-bookings/${it['id']}/cancel')),
          ]),
        ),
    ]);
  }
}
