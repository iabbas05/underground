import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'member_detail.dart';

/// Search box + results. Used for admin "Members" and staff "Check-in".
class MembersList extends StatefulWidget {
  final bool showFilters;
  final bool requireQuery; // staff: show hint until they type
  const MembersList({super.key, this.showFilters = false, this.requireQuery = false});
  @override
  State<MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<MembersList> {
  final search = TextEditingController();
  Timer? timer;
  String q = '';
  int? branch;
  String? status;
  int version = 0;

  void onChanged(String v) {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 350), () => setState(() { q = v.trim(); version++; }));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = const [null, 'active', 'expiring', 'expired'];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: search,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: tr('search_hint'), prefixIcon: const Icon(Icons.search)),
        ),
      ),
      if (widget.showFilters) ...[
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BranchChips(selected: branch, onChanged: (v) => setState(() { branch = v; version++; }))),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final s in statuses)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8, top: 6),
                child: ChoiceChip(label: Text(s == null ? tr('all') : statusText(s)), selected: status == s, onSelected: (_) => setState(() { status = s; version++; })),
              ),
          ]),
        ),
      ],
      Expanded(
        child: (widget.requireQuery && q.isEmpty)
            ? Center(child: Text(tr('start_typing'), style: const TextStyle(color: Palette.mute)))
            : Loader<List<Map<String, dynamic>>>(
                key: ValueKey('$version'),
                load: () async => asMaps(await Api.get('/api/members', query: {
                  if (q.isNotEmpty) 'q': q,
                  if (branch != null) 'branch_id': '$branch',
                  if (status != null) 'status': status!,
                })),
                builder: (context, list, reload) {
                  if (list.isEmpty) return Center(child: Text(tr('no_results'), style: const TextStyle(color: Palette.mute)));
                  return RefreshIndicator(
                    onRefresh: reload,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final m = list[i];
                        final s = m['status'] as String;
                        return UgCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => MemberDetail(id: m['id'] as int)));
                            if (mounted) reload();
                          },
                          child: Row(children: [
                            Container(width: 6, height: 44, decoration: BoxDecoration(color: statusColor(s), borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text('${m['phone']} · ${loc(m, 'branch_name')}', style: const TextStyle(color: Palette.mute, fontSize: 12), textDirection: TextDirection.ltr),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Pill(statusText(s), statusColor(s)),
                              const SizedBox(height: 4),
                              Text(m['end_date'] as String, style: const TextStyle(color: Palette.mute, fontSize: 11)),
                            ]),
                          ]),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}
