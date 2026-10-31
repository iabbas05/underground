import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});
  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 2, vsync: this);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int version = 0;

  String get from => '${monthKey(month)}-01';
  String get to => '${monthKey(month)}-31';

  Future<void> addIncome() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    int? branch = Session.branchId ?? (Lookups.gymBranches.isNotEmpty ? Lookups.gymBranches.first['id'] as int : null);
    String method = 'cash';
    String kind = 'recovery';
    final ok = await showSheet<bool>(context, StatefulBuilder(builder: (ctx, set) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('add_income'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Choice<int>(label: tr('branch'), value: branch, options: branchOptions(gymOnly: false), onChanged: (v) => set(() => branch = v)),
        const SizedBox(height: 12),
        Choice<String>(label: tr('type'), value: kind, options: [for (final k in ['subscription', 'trial', 'recovery', 'nutrition', 'other']) MapEntry(k, tr('k_$k'))], onChanged: (v) => set(() => kind = v ?? 'other')),
        const SizedBox(height: 12),
        Choice<String>(label: tr('payment_method'), value: method, options: methodOptions(), onChanged: (v) => set(() => method = v ?? 'cash')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('amount'))),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: InputDecoration(labelText: tr('note'))),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
      ]);
    }));
    final a = double.tryParse(amount.text.trim());
    if (ok != true || a == null || branch == null || !mounted) return;
    try {
      await Api.post('/api/payments', {'amount': a, 'method': method, 'kind': kind, 'branch_id': branch, 'note': note.text.trim()});
      if (mounted) { toast(context, tr('saved')); setState(() => version++); }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> addExpense() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    int? branch;
    String cat = 'rent';
    final ok = await showSheet<bool>(context, StatefulBuilder(builder: (ctx, set) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('add_expense'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Choice<int?>(label: tr('branch'), value: branch, options: [MapEntry<int?, String>(null, tr('general')), ...branchOptions().map((e) => MapEntry<int?, String>(e.key, e.value))], onChanged: (v) => set(() => branch = v)),
        const SizedBox(height: 12),
        Choice<String>(label: tr('category'), value: cat, options: [for (final k in ['rent', 'utilities', 'equipment', 'marketing', 'maintenance', 'supplies', 'other']) MapEntry(k, tr('cat_$k'))], onChanged: (v) => set(() => cat = v ?? 'other')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('amount'))),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: InputDecoration(labelText: tr('note'))),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
      ]);
    }));
    final a = double.tryParse(amount.text.trim());
    if (ok != true || a == null || !mounted) return;
    try {
      await Api.post('/api/expenses', {'amount': a, 'category': cat, 'branch_id': branch, 'note': note.text.trim()});
      if (mounted) { toast(context, tr('saved')); setState(() => version++); }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Widget _list(bool income) {
    return Loader<Map<String, dynamic>>(
      key: ValueKey('$income-${monthKey(month)}-$version'),
      load: () async => asMap(await Api.get(income ? '/api/payments' : '/api/expenses', query: income ? {'from': from, 'to': to} : {'month': monthKey(month)})),
      builder: (context, d, reload) {
        final items = asMaps(d['items']);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), children: [
            UgCard(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(tr('total')),
              Text(money(dbl(d['total'])), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: income ? Palette.ok : Palette.bad)),
            ])),
            const SizedBox(height: 10),
            if (items.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(tr('no_results'), style: const TextStyle(color: Palette.mute)))),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: ValueKey('${income ? 'p' : 'e'}${it['id']}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => confirmDialog(context, tr('confirm_delete')),
                  onDismissed: (_) async {
                    try {
                      await Api.delete('${income ? '/api/payments' : '/api/expenses'}/${it['id']}');
                    } catch (e) {
                      if (mounted) toast(context, errText(e), error: true);
                    }
                    if (mounted) setState(() => version++);
                  },
                  background: Container(
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: Palette.bad, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: UgCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(income ? ((it['member_name'] as String?) ?? tr('k_${it['kind']}')) : tr('cat_${it['category']}'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text([
                          it['date'],
                          if (income) tr('m_${it['method']}'),
                          if (it['branch_name'] != null) loc(it, 'branch_name'),
                          if ((it['note'] as String?)?.isNotEmpty ?? false) it['note'],
                        ].join(' · '), style: const TextStyle(color: Palette.mute, fontSize: 12)),
                      ])),
                      Text('${income ? '+' : '-'}${money(dbl(it['amount']))}', style: TextStyle(fontWeight: FontWeight.w800, color: income ? Palette.ok : Palette.bad)),
                    ]),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AnimatedBuilder(
        animation: tabs,
        builder: (_, __) => FloatingActionButton.extended(
          backgroundColor: Palette.violet,
          foregroundColor: Colors.white,
          onPressed: tabs.index == 0 ? addIncome : addExpense,
          icon: const Icon(Icons.add),
          label: Text(tabs.index == 0 ? tr('add_income') : tr('add_expense')),
        ),
      ),
      body: Column(children: [
        MonthBar(month: month, onChanged: (d) => setState(() => month = d)),
        TabBar(controller: tabs, indicatorColor: Palette.violet, tabs: [Tab(text: tr('income')), Tab(text: tr('expenses'))]),
        const SizedBox(height: 10),
        Expanded(child: TabBarView(controller: tabs, children: [_list(true), _list(false)])),
      ]),
    );
  }
}
