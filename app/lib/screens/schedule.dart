import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'roster.dart';

/// Class schedule: Men / Ladies, day chips (Sun..Sat). Friday is the rest day.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String audience = 'men';
  // Dart weekday: Mon=1..Sun=7 -> our day: Sun=0..Sat=6. Bahrain is UTC+3.
  late int day = DateTime.now().toUtc().add(const Duration(hours: 3)).weekday % 7;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: 'men', label: Text(tr('men'))), ButtonSegment(value: 'ladies', label: Text(tr('ladies')))],
          selected: {audience},
          onSelectionChanged: (s) => setState(() => audience = s.first),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (var d = 0; d < 7; d++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(label: Text(tr('d$d')), selected: day == d, onSelected: (_) => setState(() => day = d)),
            ),
        ]),
      ),
      Expanded(
        child: Loader<Map<String, dynamic>>(
          key: ValueKey('$audience-$day'),
          load: () async => asMap(await Api.get('/api/schedule', query: {'audience': audience, 'day': '$day', if (Session.branchId != null) 'branch_id': '${Session.branchId}'})),
          builder: (context, d, reload) {
            final items = asMaps(d['items']);
            if (d['rest_day'] == true) return Center(child: Text(tr('rest_day'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Palette.mute)));
            if (items.isEmpty) return Center(child: Text(tr('no_schedule'), style: const TextStyle(color: Palette.mute)));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final it = items[i];
                final beast = it['level'] == 'beast';
                return UgCard(
                  onTap: () => showRoster(context, (it['id'] as num).toInt(), dateForDay(day)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Text(fmtTime(it['time'] as String), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${it['capacity'] ?? 20}', style: const TextStyle(color: Palette.mute, fontSize: 12)),
                    const SizedBox(width: 8),
                    Pill(tr('lvl_${it['level']}'), beast ? Palette.warn : Palette.violetSoft),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
