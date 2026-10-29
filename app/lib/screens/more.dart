import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/update.dart';
import '../build_info.dart';
import '../core/widgets.dart';
import 'gate.dart';

class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});
  @override
  Widget build(BuildContext context) => UgCard(
        child: Row(children: [
          const Icon(Icons.language, color: Palette.violetSoft),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('language'), style: const TextStyle(fontWeight: FontWeight.w700))),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('EN'))],
            selected: {langNotifier.value},
            onSelectionChanged: (s) => Session.setLang(s.first),
          ),
        ]),
      );
}

Widget signOutButton(BuildContext context) => OutlinedButton.icon(
      onPressed: Session.end,
      icon: const Icon(Icons.logout),
      label: Text(tr('sign_out')),
    );

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Future<void> editPrice(Map<String, dynamic> p) async {
    final c = TextEditingController(text: '${p['price']}');
    final ok = await showSheet<bool>(context, Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(loc(p, 'name'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('price'))),
      const SizedBox(height: 16),
      Builder(builder: (ctx) => FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save')))),
    ]));
    final v = double.tryParse(c.text.trim());
    if (ok != true || v == null || !mounted) return;
    try {
      await Api.put('/api/plans/${p['id']}', {'price': v});
      await Lookups.load();
      if (mounted) { toast(context, tr('saved')); setState(() {}); }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      UgCard(child: Row(children: [
        const CircleAvatar(backgroundColor: Palette.violet, child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Session.user?['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(Session.user?['username'] as String? ?? '', style: const TextStyle(color: Palette.mute, fontSize: 12)),
        ])),
      ])),
      const SizedBox(height: 10),
      const LanguageTile(),
      const SizedBox(height: 10),
      UgCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GateLogScreen())),
        child: Row(children: [
          const Icon(Icons.meeting_room_outlined, color: Palette.violetSoft),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('gate_log'), style: const TextStyle(fontWeight: FontWeight.w700))),
          const Icon(Icons.chevron_right, color: Palette.mute),
        ]),
      ),
      const SizedBox(height: 10),
      UgCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(tr('gate_scan'))), body: const GateScanScreen()))),
        child: Row(children: [
          const Icon(Icons.qr_code_scanner, color: Palette.violetSoft),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('gate_scan'), style: const TextStyle(fontWeight: FontWeight.w700))),
          const Icon(Icons.chevron_right, color: Palette.mute),
        ]),
      ),
      const SizedBox(height: 10),
      UgCard(
        onTap: () => checkUpdateManually(context),
        child: Row(children: [
          const Icon(Icons.system_update, color: Palette.violetSoft),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('update_check'), style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('v$appBuild', style: const TextStyle(color: Palette.mute, fontSize: 12)),
        ]),
      ),
      SectionTitle(tr('plans_prices')),
      for (final p in Lookups.plans)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: UgCard(
            onTap: () => editPrice(p),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(loc(p, 'name'))),
              Text(money(dbl(p['price'])), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 16, color: Palette.mute),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      signOutButton(context),
    ]);
  }
}
