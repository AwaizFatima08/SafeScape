// Child profiles (PDD Q3): one parent, several children, each with their own
// sensory profile, routines and history.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../onboarding_screen.dart';

class FamilyTab extends ConsumerWidget {
  const FamilyTab({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, ChildProfile c) async {
    final name = TextEditingController(text: c.alias);
    var age = c.ageGroup;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit child'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const ValueKey('edit_alias'),
              controller: name,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [for (final a in ageGroups) ButtonSegment(value: a, label: Text(a))],
              selected: {age},
              onSelectionChanged: (v) => setState(() => age = v.first),
              showSelectedIcon: false,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(key: const ValueKey('edit_save'), onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true) {
      c.alias = name.text.trim().isEmpty ? c.alias : name.text.trim();
      c.ageGroup = age;
      ref.read(storeProvider).updateChild(c);
    }
    name.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final active = store.activeChild!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionTitle('Children'),
        const Text('Each child has their own sensory settings, routines and progress. '
            'The highlighted child is the one using the app now.',
            style: TextStyle(color: SC.textDim)),
        const SizedBox(height: 8),
        for (final c in store.data.children)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius),
              side: BorderSide(color: c.id == active.id ? SC.mint : Colors.transparent, width: 2),
            ),
            child: ListTile(
              key: ValueKey('child_${c.id}'),
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              leading: CircleAvatar(
                backgroundColor: c.id == active.id ? SC.mint : SC.slate3,
                foregroundColor: SC.slate,
                child: Text(c.alias.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(c.alias, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text('Age ${c.ageGroup}${c.id == active.id ? ' · using the app now' : ''}'),
              onTap: () => store.setActiveChild(c.id),
              trailing: PopupMenuButton<String>(
                color: SC.slate3,
                onSelected: (v) async {
                  if (v == 'use') store.setActiveChild(c.id);
                  if (v == 'edit') await _edit(context, ref, c);
                  if (v == 'delete' && context.mounted) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: Text('Remove ${c.alias}?'),
                        content: const Text('This deletes their settings, routines and progress from this device '
                            'and from the cloud backup. This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
                        ],
                      ),
                    );
                    if (ok == true) store.deleteChild(c.id);
                  }
                },
                itemBuilder: (_) => [
                  if (c.id != active.id) const PopupMenuItem(value: 'use', child: Text('Switch to this child')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit name and age')),
                  if (store.data.children.length > 1) const PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            key: const ValueKey('add_child'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OnboardingScreen(addingChild: true)),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add another child', style: TextStyle(fontSize: 17)),
          ),
        ),
      ],
    );
  }
}
