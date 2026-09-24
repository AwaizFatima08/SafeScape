// Screen 2: the Main Sensory Hub. Uncluttered: four big cards, mute, and a
// lock that leads to the Parent Zone behind the grown-up gate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';
import 'flow_canvas_screen.dart';
import 'parent/parent_dashboard.dart';
import 'routines_screen.dart';
import 'sounds_screen.dart';
import 'wait_timer_screen.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild;
    if (child == null) return const SizedBox.shrink();
    final calm = child.sensory.lowMotion;

    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      ChunkyIconButton(
                        key: const ValueKey('parent_lock'),
                        icon: Icons.lock_rounded,
                        label: 'Grown-ups area',
                        color: SC.textDim,
                        onTap: () async {
                          if (await showParentGate(context) && context.mounted) {
                            open(const ParentDashboard());
                          }
                        },
                      ),
                      const Spacer(),
                      const MuteButton(),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Sammy(size: 120, animate: !calm),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text('Hi, ${child.alias}!',
                              key: const ValueKey('hub_greeting'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      final wide = c.maxWidth > 560;
                      final cards = [
                        _HubCard(
                          key: const ValueKey('card_canvas'),
                          title: 'Calming Canvas',
                          subtitle: 'Touch, drag, and relax with gentle waves.',
                          icon: Icons.water_rounded,
                          color: SC.lavender,
                          onTap: () => open(const FlowCanvasScreen()),
                        ),
                        _HubCard(
                          key: const ValueKey('card_routines'),
                          title: 'My Visual Routines',
                          subtitle: 'Step-by-step guides for today\'s activities.',
                          icon: Icons.view_agenda_rounded,
                          color: SC.mint,
                          onTap: () => open(const RoutinesScreen()),
                        ),
                        _HubCard(
                          key: const ValueKey('card_sounds'),
                          title: 'Soothing Sounds',
                          subtitle: 'Listen to warm rain and ambient hums.',
                          icon: Icons.graphic_eq_rounded,
                          color: SC.blue,
                          onTap: () => open(const SoundsScreen()),
                        ),
                        _HubCard(
                          key: const ValueKey('card_wait'),
                          title: 'Wait Timer',
                          subtitle: 'See how long until what comes next.',
                          icon: Icons.hourglass_bottom_rounded,
                          color: SC.sand,
                          onTap: () => open(const WaitTimerScreen()),
                        ),
                      ];
                      return GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: wide ? 1.35 : (c.maxWidth / 2) / ((c.maxHeight - 14) / 2),
                        physics: const NeverScrollableScrollPhysics(),
                        children: cards,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({super.key, required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: SC.slate2,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          splashColor: color.withValues(alpha: 0.15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.16), SC.slate2],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, color: color, size: 34),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: SC.textDim, height: 1.25)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
