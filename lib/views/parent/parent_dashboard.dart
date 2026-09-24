// Screen 5: Parent & Therapist Control Dashboard (behind the grown-up gate).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import 'account_tab.dart';
import 'family_tab.dart';
import 'progress_tab.dart';
import 'routines_tab.dart';
import 'sensory_tab.dart';

class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild;
    if (child == null) return const Scaffold();
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grown-ups'),
          actions: [
            if (store.data.children.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: DropdownButton<String>(
                  key: const ValueKey('child_switcher'),
                  value: child.id,
                  underline: const SizedBox.shrink(),
                  dropdownColor: SC.slate2,
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    for (final c in store.data.children)
                      DropdownMenuItem(value: c.id, child: Text(c.alias, style: const TextStyle(fontSize: 17))),
                  ],
                  onChanged: (id) => id == null ? null : store.setActiveChild(id),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Text(child.alias, style: const TextStyle(fontSize: 17, color: SC.textDim))),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: TextStyle(fontFamily: 'Andika', fontSize: 16, fontWeight: FontWeight.bold),
            tabs: [
              Tab(key: ValueKey('tab_progress'), text: 'Progress'),
              Tab(key: ValueKey('tab_sensory'), text: 'Sensory'),
              Tab(key: ValueKey('tab_routines'), text: 'Routines'),
              Tab(key: ValueKey('tab_family'), text: 'Children'),
              Tab(key: ValueKey('tab_account'), text: 'Backup & account'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ProgressTab(), SensoryTab(), RoutinesTab(), FamilyTab(), AccountTab()],
        ),
      ),
    );
  }
}
