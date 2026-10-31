import 'package:flutter/material.dart';

import 'api.dart';
import 'i18n.dart';
import 'theme.dart';

void toast(BuildContext c, String msg, {bool error = false}) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? Palette.bad : Palette.violet,
    behavior: SnackBarBehavior.floating,
  ));
}

String errText(Object e) => e is ApiException ? e.message : e.toString();

class UgCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const UgCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Palette.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

Color statusColor(String s) => s == 'active' ? Palette.ok : s == 'expiring' ? Palette.warn : Palette.bad;
String statusText(String s) => tr('status_$s');

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const StatTile(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) => UgCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Palette.mute, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color ?? Palette.text)),
          ),
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

/// Loads data, shows spinner / error with retry / content. Call state.reload() to refresh.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  const Loader({super.key, required this.load, required this.builder});

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? data;
  Object? error;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      busy = data == null;
      error = null;
    });
    try {
      final d = await widget.load();
      if (mounted) setState(() { data = d; busy = false; });
    } catch (e) {
      if (mounted) setState(() { error = e; busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (busy) return const Center(child: CircularProgressIndicator());
    if (error != null && data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: Palette.mute),
            const SizedBox(height: 12),
            Text(errText(error!), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(width: 180, child: OutlinedButton(onPressed: reload, child: Text(tr('retry')))),
          ]),
        ),
      );
    }
    return widget.builder(context, data as T, reload);
  }
}

Future<bool> confirmDialog(BuildContext c, String text) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.panel,
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('delete'), style: const TextStyle(color: Palette.bad)),
        ),
      ],
    ),
  );
  return r == true;
}

/// Bottom sheet wrapper that lifts above the keyboard.
Future<T?> showSheet<T>(BuildContext c, Widget child) => showModalBottomSheet<T>(
      context: c,
      isScrollControlled: true,
      backgroundColor: Palette.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: child),
      ),
    );

class Choice<V> extends StatelessWidget {
  final String label;
  final V? value;
  final List<MapEntry<V, String>> options;
  final ValueChanged<V?> onChanged;
  const Choice({super.key, required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<V>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        dropdownColor: Palette.panel2,
        items: [for (final o in options) DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      );
}

List<MapEntry<int, String>> branchOptions({bool gymOnly = true}) => [
      for (final b in (gymOnly ? Lookups.gymBranches : Lookups.branches)) MapEntry(b['id'] as int, loc(b, 'name')),
    ];

const methods = ['cash', 'card', 'benefit', 'transfer'];
List<MapEntry<String, String>> methodOptions() => [for (final m in methods) MapEntry(m, tr('m_$m'))];

String planLabel(Map<String, dynamic> p) => '${loc(p, 'name')} — ${money(dbl(p['price']))}';

/// Branch filter chips: "All" + each gym branch.
class BranchChips extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;
  const BranchChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(label: Text(tr('all_branches')), selected: selected == null, onSelected: (_) => onChanged(null)),
            ),
            for (final b in Lookups.gymBranches)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(label: Text(loc(b, 'name')), selected: selected == b['id'], onSelected: (_) => onChanged(b['id'] as int)),
              ),
          ],
        ),
      );
}

class MonthBar extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const MonthBar({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: Icon(isAr ? Icons.chevron_right : Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        SizedBox(width: 150, child: Text(monthLabel(month), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        IconButton(
          icon: Icon(isAr ? Icons.chevron_left : Icons.chevron_right),
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ]);
}

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
