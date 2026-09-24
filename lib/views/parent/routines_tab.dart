// Custom Routine Builder: list, add (blank or from a ready-made routine),
// edit, reset progress, delete.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'routine_editor.dart';

class RoutinesTab extends ConsumerWidget {
  const RoutinesTab({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final store = ref.read(storeProvider);
    final child = store.activeChild!;
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: SC.slate2,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const ValueKey('new_blank'),
              leading: const Icon(Icons.add_rounded, color: SC.mint),
              title: const Text('Start from scratch', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context, -1),
            ),
            const Divider(color: SC.slate3),
            for (final (i, t) in routineTemplates.indexed)
              ListTile(
                leading: StepPicture(iconKey: t.icon, size: 36),
                title: Text(t.title),
                subtitle: Text('${t.steps.length} steps'),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final routine = choice < 0
        ? Routine(id: newId('routine'), childId: child.id, title: '', iconKey: 'star', steps: [])
        : routineTemplates[choice].build(child.id);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoutineEditor(routine: routine, isNew: true)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild!;
    final routines = store.routinesFor(child.id);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_routine'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New routine'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const SectionTitle('Visual routines'),
          Text('Routines ${child.alias} sees. Tap one to edit its steps, pictures and stories.',
              style: const TextStyle(color: SC.textDim)),
          const SizedBox(height: 8),
          for (final r in routines)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                key: ValueKey('edit_${r.id}'),
                contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                leading: StepPicture(iconKey: r.iconKey, size: 44),
                title: Text(r.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                subtitle: Text('${r.steps.length} steps · ${r.doneCount} done'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoutineEditor(routine: r))),
                trailing: PopupMenuButton<String>(
                  key: ValueKey('menu_${r.id}'),
                  color: SC.slate3,
                  onSelected: (v) async {
                    if (v == 'reset') {
                      store.resetRoutine(r);
                    } else if (v == 'copy') {
                      final others = store.data.children.where((c) => c.id != child.id).toList();
                      for (final o in others) {
                        store.upsertRoutine(r.copyFor(o.id));
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Copied to ${others.map((o) => o.alias).join(', ')}.')));
                      }
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('Delete "${r.title}"?'),
                          content: const Text('Its past activity stays in the progress summary.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) store.deleteRoutine(r);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'reset', child: Text('Reset progress')),
                    if (store.data.children.length > 1)
                      const PopupMenuItem(value: 'copy', child: Text('Copy to other children')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
