import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Staff side of the store: approve pickup orders and enter today's stock for the branch.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int version = 0;
  bool stockMode = false;

  Future<void> setStatus(int id, String status) async {
    try {
      await Api.post('/api/store/orders/$id/status', {'status': status});
      if (mounted) setState(() => version++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> setQty(int productId, String text) async {
    final q = int.tryParse(text.trim());
    if (q == null) return;
    try {
      await Api.put('/api/store/stock', {'product_id': productId, 'qty': q});
      if (mounted) {
        toast(context, tr('saved'));
        setState(() => version++);
      }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  List<Widget> actions(Map<String, dynamic> o) {
    final id = (o['id'] as num).toInt();
    switch (o['status']) {
      case 'pending':
        return [
          FilledButton(onPressed: () => setStatus(id, 'approved'), child: Text(tr('st_approve'))),
          OutlinedButton(onPressed: () => setStatus(id, 'rejected'), child: Text(tr('st_reject'))),
        ];
      case 'approved':
        return [
          FilledButton(onPressed: () => setStatus(id, 'ready'), child: Text(tr('st_ready_btn'))),
          OutlinedButton(onPressed: () => setStatus(id, 'rejected'), child: Text(tr('st_reject'))),
        ];
      case 'ready':
        return [FilledButton(onPressed: () => setStatus(id, 'picked'), child: Text(tr('st_picked_btn')))];
    }
    return [];
  }

  Widget orders() => Loader<Map<String, dynamic>>(
        key: ValueKey('o$version'),
        load: () async => asMap(await Api.get('/api/store/orders')),
        builder: (context, d, reload) {
          final items = asMaps(d['items']);
          if (items.isEmpty) return Center(child: Text(tr('no_orders'), style: const TextStyle(color: Palette.mute)));
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final o = items[i];
                final lines = asMaps(o['items']).map((x) => '${x['qty']} × ${loc(x, 'name')}').join('\n');
                return UgCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('#${o['id']}  ${o['customer']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text(money(dbl(o['total'])), style: const TextStyle(color: Palette.violetSoft, fontWeight: FontWeight.w800)),
                    ]),
                    Text('${o['phone']}', style: const TextStyle(color: Palette.mute, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(lines),
                    if ((o['note'] as String?)?.isNotEmpty ?? false) Text('“${o['note']}”', style: const TextStyle(color: Palette.mute)),
                    const SizedBox(height: 6),
                    Text(tr('st_${o['status']}'), style: const TextStyle(color: Palette.warn, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: actions(o)),
                  ]),
                );
              },
            ),
          );
        },
      );

  Widget stock() => Loader<Map<String, dynamic>>(
        key: ValueKey('s$version'),
        load: () async => asMap(await Api.get('/api/store/stock')),
        builder: (context, d, reload) {
          final items = asMaps(d['items']);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = items[i];
              final c = TextEditingController(text: '${p['stock']}');
              return UgCard(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(loc(p, 'name'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${tr('reserved')}: ${p['reserved']}  ·  ${tr('available')}: ${p['available']}', style: TextStyle(fontSize: 12, color: p['sold_out'] == true ? Palette.bad : Palette.mute)),
                    ]),
                  ),
                  SizedBox(width: 70, child: TextField(controller: c, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                  IconButton(onPressed: () => setQty((p['id'] as num).toInt(), c.text), icon: const Icon(Icons.check_circle_outline)),
                ]),
              );
            },
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: false, label: Text(tr('store_orders'))), ButtonSegment(value: true, label: Text(tr('store_stock')))],
          selected: {stockMode},
          onSelectionChanged: (s) => setState(() { stockMode = s.first; version++; }),
        ),
      ),
      Expanded(child: stockMode ? stock() : orders()),
    ]);
  }
}
