import 'package:flutter/material.dart';

import '../core/i18n.dart';
import 'dashboard.dart';
import 'member_form.dart';
import 'members_list.dart';
import 'money.dart';
import 'more.dart';
import 'team.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  int membersVersion = 0;

  Future<void> addMember() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(tr('nav_new'))),
      body: MemberForm(onDone: () => Navigator.pop(context)),
    )));
    if (mounted) setState(() => membersVersion++);
  }

  @override
  Widget build(BuildContext context) {
    final titles = [tr('nav_dashboard'), tr('nav_members'), tr('nav_money'), tr('nav_team'), tr('nav_more')];
    final pages = <Widget>[
      const DashboardScreen(),
      MembersList(key: ValueKey(membersVersion), showFilters: true),
      const MoneyScreen(),
      const TeamScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [if (index == 1) IconButton(onPressed: addMember, icon: const Icon(Icons.person_add_alt_1))],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights), label: tr('nav_dashboard')),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups), label: tr('nav_members')),
          NavigationDestination(icon: const Icon(Icons.payments_outlined), selectedIcon: const Icon(Icons.payments), label: tr('nav_money')),
          NavigationDestination(icon: const Icon(Icons.badge_outlined), selectedIcon: const Icon(Icons.badge), label: tr('nav_team')),
          NavigationDestination(icon: const Icon(Icons.more_horiz), selectedIcon: const Icon(Icons.more_horiz), label: tr('nav_more')),
        ],
      ),
    );
  }
}
