// Screen 4: Visual Transition & Task Cards. The current step glows; tapping
// it finishes it with a small star burst and a warm marimba chime. Other
// cards just read themselves aloud (errorless: nothing is ever "wrong").

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';

class RoutinePlayerScreen extends ConsumerStatefulWidget {
  final String routineId;
  const RoutinePlayerScreen({super.key, required this.routineId});

  @override
  ConsumerState<RoutinePlayerScreen> createState() => _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends ConsumerState<RoutinePlayerScreen> {
  String? _burstStepId;
  int _burstSeq = 0;
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final r = ref.read(storeProvider).routineById(widget.routineId);
      if (r == null) return;
      final i = r.currentIndex;
      if (r.isFinished) {
        setState(() => _celebrate = true);
      } else if (i >= 0) {
        _say(i == 0 ? '${r.title}. First, ${r.steps[i].title}.' : 'Now: ${r.steps[i].title}.');
      }
    });
  }

  void _say(String text) => ref.read(speechProvider).say(text);

  void _tapStep(Routine r, int i) {
    final step = r.steps[i];
    if (i != r.currentIndex) {
      // Preview or re-hear a card; never an error.
      _say(step.story.isNotEmpty ? '${step.title}. ${step.story}' : step.title);
      return;
    }
    final store = ref.read(storeProvider);
    final finished = store.completeStep(r, i);
    setState(() {
      _burstStepId = step.id;
      _burstSeq++;
    });
    if (finished) {
      ref.read(soundProvider).playSfx('done');
      _say('All done! Great job, ${store.activeChild?.alias ?? ''}!');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _celebrate = true);
      });
    } else {
      ref.read(soundProvider).playSfx('step');
      final next = r.steps[r.currentIndex];
      _say('Well done. Next: ${next.title}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final r = store.routineById(widget.routineId);
    if (r == null) return const Scaffold();
    final child = store.activeChild;
    final calm = child?.sensory.lowMotion ?? false;
    final cur = r.currentIndex;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(children: [
                        const HomeButton(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(r.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          key: const ValueKey('progress_pill'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: SC.slate2, borderRadius: BorderRadius.circular(20)),
                          child: Text('${r.doneCount}/${r.steps.length} Done',
                              style: const TextStyle(fontSize: 16, color: SC.mint, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        const MuteButton(),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: r.steps.isEmpty ? 0 : r.doneCount / r.steps.length),
                          duration: const Duration(milliseconds: 700),
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 14,
                            backgroundColor: SC.slate3,
                            color: SC.mint,
                            semanticsLabel: '${r.doneCount} of ${r.steps.length} steps done',
                          ),
                        ),
                      ),
                    ),
                    if (cur >= 0) _FirstThen(routine: r, current: cur),
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final cols = c.maxWidth > 600 ? 3 : 2;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: r.steps.length,
                          itemBuilder: (context, i) => _StepCard(
                            key: ValueKey('step_$i'),
                            step: r.steps[i],
                            index: i,
                            state: r.steps[i].isCompleted
                                ? _StepState.done
                                : i == cur
                                    ? _StepState.current
                                    : _StepState.upcoming,
                            calm: calm,
                            burstSeq: _burstStepId == r.steps[i].id ? _burstSeq : 0,
                            onTap: () => _tapStep(r, i),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            if (_celebrate)
              _Celebration(
                alias: child?.alias ?? '',
                calm: calm,
                onHome: () => Navigator.of(context).maybePop(),
                onAgain: () {
                  store.resetRoutine(r);
                  setState(() => _celebrate = false);
                  _say('${r.title}. First, ${r.steps.first.title}.');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FirstThen extends StatelessWidget {
  final Routine routine;
  final int current;
  const _FirstThen({required this.routine, required this.current});

  @override
  Widget build(BuildContext context) {
    final first = routine.steps[current];
    final then = current + 1 < routine.steps.length ? routine.steps[current + 1] : null;
    Widget half(String label, RoutineStep s, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(children: [
          StepPicture(iconKey: s.iconKey, photoPath: s.photoPath, size: 44),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.bold)),
              Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
            ]),
          ),
        ]),
      ),
    );
    return Padding(
      key: const ValueKey('first_then'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        half('FIRST', first, SC.lavender),
        if (then != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded, color: SC.textDim),
          ),
          half('THEN', then, SC.mint),
        ],
      ]),
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepCard extends StatefulWidget {
  final RoutineStep step;
  final int index;
  final _StepState state;
  final bool calm;
  final int burstSeq;
  final VoidCallback onTap;

  const _StepCard({super.key, required this.step, required this.index, required this.state, required this.calm, required this.burstSeq, required this.onTap});

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> with TickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.state == _StepState.current && !widget.calm) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(_StepCard old) {
    super.didUpdateWidget(old);
    _syncPulse();
    if (widget.burstSeq != 0 && widget.burstSeq != old.burstSeq) _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    final (label, color) = switch (widget.state) {
      _StepState.done => ('DONE', SC.mint),
      _StepState.current => ('NOW', SC.lavender),
      _StepState.upcoming => ('NEXT UP', SC.textDim),
    };
    return Semantics(
      button: true,
      label: '${widget.index + 1}. ${s.title}. $label.',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _burst]),
        builder: (context, _) {
          final glow = widget.state == _StepState.current ? 0.35 + 0.35 * _pulse.value : 0.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: widget.state == _StepState.upcoming ? 0.7 : 1,
                  child: Material(
                    color: SC.slate2,
                    borderRadius: BorderRadius.circular(kRadius),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(kRadius),
                      onTap: widget.onTap,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(kRadius),
                          border: Border.all(
                            color: widget.state == _StepState.upcoming ? SC.slate3 : color.withValues(alpha: 0.7),
                            width: widget.state == _StepState.current ? 4 : 2,
                          ),
                          boxShadow: glow > 0
                              ? [BoxShadow(color: SC.lavender.withValues(alpha: glow * 0.5), blurRadius: 18, spreadRadius: 1)]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Row(children: [
                              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                              const Spacer(),
                              if (widget.state == _StepState.done)
                                const Icon(Icons.check_circle_rounded, color: SC.mint, size: 26)
                              else if (s.story.isNotEmpty)
                                const Icon(Icons.record_voice_over_rounded, color: SC.textDim, size: 20),
                            ]),
                            Expanded(
                              child: Center(
                                child: Opacity(
                                  opacity: widget.state == _StepState.done ? 0.55 : 1,
                                  child: StepPicture(iconKey: s.iconKey, photoPath: s.photoPath, size: 88),
                                ),
                              ),
                            ),
                            Text('${widget.index + 1}. ${s.title}',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_burst.isAnimating)
                Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _BurstPainter(_burst.value)))),
            ],
          );
        },
      ),
    );
  }
}

/// A small, slow star burst (L16: no screen-wide flashes).
class _BurstPainter extends CustomPainter {
  final double t;
  _BurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ease = Curves.easeOutCubic.transform(t);
    final alpha = (1 - t).clamp(0.0, 1.0);
    final colors = [SC.sand, SC.mint, SC.lavender, SC.blue];
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + 0.3;
      final r = 20 + ease * size.shortestSide * 0.42;
      final p = Paint()..color = colors[i % 4].withValues(alpha: alpha);
      _star(canvas, c + Offset(cos(a) * r, sin(a) * r), 7 * (1 - 0.4 * t), p);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = c + Offset(rr * cos(a), rr * sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}

class _Celebration extends StatelessWidget {
  final String alias;
  final bool calm;
  final VoidCallback onHome;
  final VoidCallback onAgain;
  const _Celebration({required this.alias, required this.calm, required this.onHome, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          key: const ValueKey('celebration'),
          color: SC.slate.withValues(alpha: 0.94),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Sammy(size: 200, mood: SammyMood.celebrating, animate: !calm),
              const SizedBox(height: 12),
              const Text('All done!', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: SC.sand)),
              const SizedBox(height: 6),
              Text(alias.isEmpty ? 'Great job!' : 'Great job, $alias!',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 28),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    height: kTouch,
                    child: FilledButton.icon(
                      key: const ValueKey('celebrate_home'),
                      onPressed: onHome,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Back to Hub'),
                    ),
                  ),
                  SizedBox(
                    height: kTouch,
                    child: OutlinedButton.icon(
                      key: const ValueKey('celebrate_again'),
                      onPressed: onAgain,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Start again', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
