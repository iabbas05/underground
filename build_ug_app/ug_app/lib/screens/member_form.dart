import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';

/// Register a new member + payment record. Used by staff (own branch, plan price) and admin.
class MemberForm extends StatefulWidget {
  final VoidCallback? onDone;
  const MemberForm({super.key, this.onDone});
  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final amount = TextEditingController();
  int? planId;
  int? branchId = Session.branchId;
  String method = 'cash';
  bool busy = false;
  String? error;

  Map<String, dynamic>? get plan {
    for (final p in Lookups.plans) {
      if (p['id'] == planId) return p;
    }
    return null;
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty || planId == null || branchId == null) {
      setState(() => error = tr('required'));
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'plan_id': planId,
        'method': method,
        'branch_id': branchId,
      };
      if (Session.isAdmin && amount.text.trim().isNotEmpty) body['amount'] = double.tryParse(amount.text.trim());
      await Api.post('/api/members', body);
      if (!mounted) return;
      toast(context, tr('registered'));
      name.clear();
      phone.clear();
      amount.clear();
      setState(() => planId = null);
      widget.onDone?.call();
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: name, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: tr('member_name'), prefixIcon: const Icon(Icons.person_outline))),
      const SizedBox(height: 14),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
        decoration: InputDecoration(labelText: tr('phone'), helperText: tr('phone_hint'), prefixIcon: const Icon(Icons.phone_outlined)),
      ),
      const SizedBox(height: 14),
      if (Session.isAdmin) ...[
        Choice<int>(label: tr('branch'), value: branchId, options: branchOptions(), onChanged: (v) => setState(() => branchId = v)),
        const SizedBox(height: 14),
      ],
      Choice<int>(
        label: tr('plan'),
        value: planId,
        options: [for (final x in Lookups.plans) MapEntry(x['id'] as int, planLabel(x))],
        onChanged: (v) => setState(() => planId = v),
      ),
      const SizedBox(height: 14),
      Choice<String>(label: tr('payment_method'), value: method, options: methodOptions(), onChanged: (v) => setState(() => method = v ?? 'cash')),
      if (Session.isAdmin) ...[
        const SizedBox(height: 14),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('amount'), helperText: p == null ? null : money(dbl(p['price']))),
        ),
      ] else if (p != null) ...[
        const SizedBox(height: 16),
        UgCard(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(tr('total')),
          Text(money(dbl(p['price'])), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ])),
      ],
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFF87171)))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : save, child: Text(tr('register'))),
    ]);
  }
}
