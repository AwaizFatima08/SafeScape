// "My Visual Routines": the child picks a routine card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'routine_player_screen.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild!;
    final routines = store.routinesFor(child.id);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: const [
                      HomeButton(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'My Visual Routines',
                          maxLines: 2,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.15),
                        ),
                      ),
                      MuteButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: routines.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No routines yet.\nA grown-up can add one in the grown-ups area.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: SC.textDim),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, c) {
                            final cols = c.maxWidth > 600 ? 3 : 2;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: c.maxWidth < 400 ? 0.82 : 0.95,
                              ),
                              itemCount: routines.length,
                              itemBuilder: (context, i) {
                                final r = routines[i];
                                final progress = r.steps.isEmpty ? 0.0 : r.doneCount / r.steps.length;
                                return Semantics(
                                  button: true,
                                  label: '${r.title}. ${r.doneCount} of ${r.steps.length} steps done.',
                                  excludeSemantics: true,
                                  child: Material(
                                    color: SC.slate2,
                                    borderRadius: BorderRadius.circular(kRadius),
                                    child: InkWell(
                                      key: ValueKey('routine_${r.id}'),
                                      borderRadius: BorderRadius.circular(kRadius),
                                      onTap: () => Navigator.of(
                                        context,
                                      ).push(MaterialPageRoute(builder: (_) => RoutinePlayerScreen(routineId: r.id))),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          children: [
                                            Expanded(child: StepPicture(iconKey: r.iconKey, size: 84)),
                                            const SizedBox(height: 8),
                                            Text(
                                              r.title,
                                              textAlign: TextAlign.center,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 10,
                                                backgroundColor: SC.slate3,
                                                color: SC.mint,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
