import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../build_info.dart';
import 'api.dart';
import 'i18n.dart';

/// Asks the server whether a newer app was released. Returns the release info or null.
Future<Map<String, dynamic>?> fetchRelease() async {
  try {
    final r = asMap(await Api.get('/api/app/version'));
    final build = (r['build'] as num?)?.toInt() ?? 0;
    if (build > appBuild && r['url'] is String) return r;
  } catch (_) {}
  return null;
}

Future<void> showUpdateDialog(BuildContext context, Map<String, dynamic> r) async {
  final notes = (r['notes'] as String?) ?? '';
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('update_title')),
      content: Text(notes.isEmpty ? tr('update_body') : '${tr('update_body')}\n\n$notes'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('update_later'))),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('update_now')),
        ),
      ],
    ),
  );
  if (go == true) {
    await launchUrl(Uri.parse(r['url'] as String), mode: LaunchMode.externalApplication);
  }
}

/// Wrap the signed-in home screen: checks for an update once when it opens.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final r = await fetchRelease();
      if (r != null && mounted) await showUpdateDialog(context, r);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> checkUpdateManually(BuildContext context) async {
  final r = await fetchRelease();
  if (!context.mounted) return;
  if (r == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('update_none'))));
  } else {
    await showUpdateDialog(context, r);
  }
}
