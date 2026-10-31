import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'member_form.dart';
import 'members_list.dart';
import 'gate.dart';
import 'more.dart';
import 'schedule.dart';
import 'store.dart';

class StaffShell extends StatefulWidget {
  const StaffShell({super.key});
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [tr('nav_checkin'), tr('nav_new'), tr('gate_scan'), tr('nav_schedule'), tr('nav_store'), tr('nav_me')];
    final branch = Lookups.branch(Session.branchId);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w800)),
          if (branch != null) Text(loc(branch, 'name'), style: const TextStyle(fontSize: 12, color: Palette.violetSoft)),
        ]),
      ),
      body: IndexedStack(index: index, children: [
        const MembersList(requireQuery: true),
        MemberForm(onDone: () => setState(() => index = 0)),
        index == 2 ? const GateScanScreen() : const SizedBox.shrink(),
        const ScheduleScreen(),
        const StoreScreen(),
        const MeScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.how_to_reg_outlined), selectedIcon: const Icon(Icons.how_to_reg), label: tr('nav_checkin')),
          NavigationDestination(icon: const Icon(Icons.person_add_alt_outlined), selectedIcon: const Icon(Icons.person_add_alt_1), label: tr('nav_new')),
          NavigationDestination(icon: const Icon(Icons.qr_code_scanner), selectedIcon: const Icon(Icons.qr_code_scanner), label: tr('gate_scan')),
          NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: tr('nav_schedule')),
          NavigationDestination(icon: const Icon(Icons.restaurant_menu), selectedIcon: const Icon(Icons.restaurant_menu), label: tr('nav_store')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: tr('nav_me')),
        ],
      ),
    );
  }
}

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  int version = 0;
  bool busy = false;

  Future<void> clock(bool isIn) async {
    setState(() => busy = true);
    try {
      await Api.post('/api/attendance/clock', {'action': isIn ? 'out' : 'in'});
      if (mounted) setState(() => version++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => version++),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        UgCard(child: Text(Session.user?['name'] as String? ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: Loader<Map<String, dynamic>>(
            key: ValueKey('c$version'),
            load: () async => asMap(await Api.get('/api/attendance/today')),
            builder: (context, d, _) {
              final inNow = d['clocked_in'] == true;
              return UgCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(inNow ? '${tr('clocked_since')} ${d['since']}' : tr('not_clocked'), style: TextStyle(color: inNow ? Palette.ok : Palette.mute, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FilledButton(
                    style: inNow ? FilledButton.styleFrom(backgroundColor: Palette.panel2) : null,
                    onPressed: busy ? null : () => clock(inNow),
                    child: Text(inNow ? tr('clock_out') : tr('clock_in')),
                  ),
                ]),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: Loader<Map<String, dynamic>>(
            key: ValueKey('t$version'),
            load: () async => asMap(await Api.get('/api/payments')),
            builder: (context, d, _) => StatTile(tr('today_collected'), money(dbl(d['total'])), color: Palette.violetSoft),
          ),
        ),
        const SizedBox(height: 12),
        const LanguageTile(),
        const SizedBox(height: 16),
        signOutButton(context),
      ]),
    );
  }
}
