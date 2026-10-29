import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int version = 0;

  Future<Map<String, dynamic>> _load() async {
    final m = monthKey(month);
    final users = asMaps(await Api.get('/api/users'));
    final att = asMap(await Api.get('/api/attendance', query: {'month': m}));
    final sal = asMap(await Api.get('/api/salaries', query: {'month': m}));
    return {'users': users, 'att': att, 'sal': sal};
  }

  Future<void> editUser(Map<String, dynamic>? u) async {
    final name = TextEditingController(text: u?['name'] as String? ?? '');
    final username = TextEditingController(text: u?['username'] as String? ?? '');
    final pass = TextEditingController();
    final salary = TextEditingController(text: u == null ? '' : '${u['base_salary']}');
    int? branch = u?['branch_id'] as int?;
    String role = u?['role'] as String? ?? 'staff';
    bool active = (u?['active'] ?? 1) == 1;
    String? err;
    final ok = await showSheet<bool>(context, StatefulBuilder(builder: (ctx, set) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(u == null ? tr('add_staff') : tr('edit_staff'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        TextField(controller: name, decoration: InputDecoration(labelText: tr('staff_name'))),
        if (u == null) ...[
          const SizedBox(height: 12),
          TextField(controller: username, autocorrect: false, decoration: InputDecoration(labelText: tr('username'))),
          const SizedBox(height: 12),
          Choice<String>(label: tr('role'), value: role, options: [MapEntry('staff', tr('role_staff')), MapEntry('admin', tr('role_admin'))], onChanged: (v) => set(() => role = v ?? 'staff')),
        ],
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: u == null ? tr('password') : tr('new_password'), helperText: tr('pass_min'))),
        const SizedBox(height: 12),
        Choice<int?>(label: tr('branch'), value: branch, options: [const MapEntry<int?, String>(null, '—'), ...branchOptions().map((e) => MapEntry<int?, String>(e.key, e.value))], onChanged: (v) => set(() => branch = v)),
        const SizedBox(height: 12),
        TextField(controller: salary, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('base_salary'))),
        if (u != null) SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('account_active')), value: active, onChanged: (v) => set(() => active = v)),
        if (err != null) Text(err!, style: const TextStyle(color: Palette.bad)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
      ]);
    }));
    if (ok != true || !mounted) return;
    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'branch_id': branch,
        'base_salary': double.tryParse(salary.text.trim()) ?? 0,
        if (pass.text.isNotEmpty) 'password': pass.text,
      };
      if (u == null) {
        await Api.post('/api/users', {...body, 'username': username.text.trim(), 'role': role});
      } else {
        await Api.put('/api/users/${u['id']}', {...body, 'active': active});
      }
      if (mounted) { toast(context, tr('saved')); setState(() => version++); }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> paySalary(Map<String, dynamic> u) async {
    final amount = TextEditingController(text: '${u['base_salary']}');
    final ok = await showSheet<bool>(context, Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${tr('pay_salary')} — ${u['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(monthLabel(month), style: const TextStyle(color: Palette.mute)),
      const SizedBox(height: 14),
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('amount'))),
      const SizedBox(height: 16),
      Builder(builder: (ctx) => FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('pay_salary')))),
    ]));
    final a = double.tryParse(amount.text.trim());
    if (ok != true || a == null || !mounted) return;
    try {
      await Api.post('/api/salaries', {'user_id': u['id'], 'month': monthKey(month), 'amount': a});
      if (mounted) { toast(context, tr('saved')); setState(() => version++); }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Palette.violet,
        foregroundColor: Colors.white,
        onPressed: () => editUser(null),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('add_staff')),
      ),
      body: Column(children: [
        MonthBar(month: month, onChanged: (d) => setState(() => month = d)),
        Expanded(
          child: Loader<Map<String, dynamic>>(
            key: ValueKey('${monthKey(month)}-$version'),
            load: _load,
            builder: (context, d, reload) {
              final users = asMaps(d['users']);
              final summary = {for (final s in asMaps(asMap(d['att'])['summary'])) s['user_id']: s};
              final paidItems = asMaps(asMap(d['sal'])['items']);
              double paidFor(int id) => paidItems.where((s) => s['user_id'] == id).fold(0.0, (a, s) => a + dbl(s['amount']));
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final base = dbl(u['base_salary']);
                    final paid = paidFor(u['id'] as int);
                    final a = summary[u['id']];
                    final fullyPaid = base > 0 && paid >= base;
                    return UgCard(
                      onTap: () => editUser(u),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(u['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                          if ((u['active'] ?? 1) != 1) Pill(tr('status_expired'), Palette.bad) else Pill(tr('role_${u['role']}'), Palette.violetSoft),
                        ]),
                        const SizedBox(height: 4),
                        Text('${u['username']}${u['branch_name'] != null ? ' · ${loc(u, 'branch_name')}' : ''}', style: const TextStyle(color: Palette.mute, fontSize: 12)),
                        const Divider(height: 22),
                        Row(children: [
                          Expanded(child: Text('${tr('attendance')}: ${a?['days'] ?? 0} ${tr('days_worked')} · ${a?['hours'] ?? 0} ${tr('hours')}', style: const TextStyle(fontSize: 12, color: Palette.mute))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: Text('${tr('due')}: ${money(base)}  ·  ${tr('paid')}: ${money(paid)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          if (!fullyPaid && base > 0)
                            SizedBox(height: 38, child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 38), textStyle: const TextStyle(fontSize: 13)), onPressed: () => paySalary(u), child: Text(tr('pay_salary'))))
                          else if (fullyPaid)
                            const Icon(Icons.check_circle, color: Palette.ok),
                        ]),
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
