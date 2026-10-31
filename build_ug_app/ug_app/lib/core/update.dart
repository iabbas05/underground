import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../build_info.dart';
import 'api.dart';
import 'i18n.dart';

/// Asks the server whether a newer app was released. Returns the release info or null.
Future<Map<String, dynamic>?> fetchRelease() async {
  if (Platform.isIOS) return null; // APK updates are Android only
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
  if (go == true && context.mounted) await installUpdate(context, r['url'] as String);
}

/// Downloads the new APK inside the app (with a percentage) and opens the system installer.
/// If anything goes wrong it falls back to opening the download link in the browser.
Future<void> installUpdate(BuildContext context, String url) async {
  final prog = ValueNotifier<String>('0%');
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  void closeDialog() {
    if (open) {
      open = false;
      nav.pop();
    }
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<String>(
          valueListenable: prog,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('update_downloading')),
            const SizedBox(height: 14),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(v),
          ]),
        ),
      ),
    ),
  );
  try {
    OtaUpdate().execute(url, destinationFilename: 'UNDERGROUND-Staff.apk').listen(
      (e) {
        if (e.status == OtaStatus.DOWNLOADING) {
          prog.value = '${e.value}%';
        } else if (e.status == OtaStatus.INSTALLING || e.status == OtaStatus.INSTALLATION_DONE || e.status == OtaStatus.CANCELED) {
          closeDialog();
        } else if (e.status.name.contains('ERROR')) {
          closeDialog();
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      onError: (_) {
        closeDialog();
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      onDone: closeDialog,
    );
  } catch (_) {
    closeDialog();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
