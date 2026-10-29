import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Shows the member's rotating entry code (QR) and lets staff copy the pass link for WhatsApp.
Future<void> showPassSheet(BuildContext context, int memberId, String name) =>
    showSheet<void>(context, _PassBody(memberId: memberId, name: name));

class _PassBody extends StatefulWidget {
  final int memberId;
  final String name;
  const _PassBody({required this.memberId, required this.name});
  @override
  State<_PassBody> createState() => _PassBodyState();
}

class _PassBodyState extends State<_PassBody> {
  Map<String, dynamic>? pass;
  String? error;
  int left = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (left > 0) {
        setState(() => left--);
      } else if (pass != null) {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = asMap(await Api.get('/api/members/${widget.memberId}/pass'));
      if (mounted) setState(() { pass = p; left = (p['seconds_left'] as num).toInt(); error = null; });
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    }
  }

  Future<void> block(bool value) async {
    try {
      await Api.post('/api/members/${widget.memberId}/block', {'blocked': value});
      await load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> reissue() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        content: Text(tr('reissue_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('reissue'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('/api/members/${widget.memberId}/reissue', {});
      await load();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pass;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      if (error != null) Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Palette.bad)),
      if (p == null && error == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      if (p != null) ...[
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: QrImageView(data: p['dynamic_code'] as String, size: 220, backgroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (left / 30).clamp(0.0, 1.0), minHeight: 6, backgroundColor: Palette.line, color: Palette.violet)),
        const SizedBox(height: 8),
        Text(tr('pass_hint'), textAlign: TextAlign.center, style: const TextStyle(color: Palette.mute, fontSize: 12)),
        if (p['blocked'] == true) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Pill(tr('status_blocked'), Palette.bad))),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.link),
          label: Text(tr('pass_copy_link')),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: p['link'] as String));
            if (mounted) toast(context, tr('pass_link_copied'));
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.qr_code_2),
          label: Text(tr('pass_link_qr')),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Palette.panel,
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('pass_link_qr_hint'), textAlign: TextAlign.center, style: const TextStyle(color: Palette.mute)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: QrImageView(data: p['link'] as String, size: 230, backgroundColor: Colors.white),
                ),
              ]),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('done')))],
            ),
          ),
        ),
        if (p['ban_until'] != null) ...[
          const SizedBox(height: 12),
          Center(child: Pill('${tr('banned_until')} ${p['ban_until']}', Palette.bad)),
          if (Session.isAdmin)
            TextButton(
              onPressed: () async {
                try {
                  await Api.post('/api/members/${widget.memberId}/unban', {});
                  await load();
                } catch (e) {
                  if (mounted) toast(context, errText(e), error: true);
                }
              },
              child: Text(tr('unban')),
            ),
        ],
        if (Session.isAdmin) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => block(p['blocked'] != true), child: Text(p['blocked'] == true ? tr('unblock') : tr('block')))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: reissue, child: Text(tr('reissue')))),
          ]),
        ],
      ],
    ]);
  }
}
