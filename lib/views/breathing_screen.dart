// Breathing Buddy: Sammy breathes with the child. Three patterns chosen by
// picture (Balloon 4/6, Flower & Candle 3/5, Box 4-4-4). No counting down,
// no scores; the session simply ends when the child goes home.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/audio.dart';
import '../services/store.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';

enum BreathPhase { inhale, hold, exhale }

/// Where in the pattern we are at [seconds]: ring size 0..1 and the phase.
(double, BreathPhase) breathPhaseAt(BreathPattern p, double seconds) {
  final t = seconds % p.cycle;
  if (t < p.inhale) return (0.5 - 0.5 * cos(pi * t / p.inhale), BreathPhase.inhale);
  if (t < p.inhale + p.hold) return (1, BreathPhase.hold);
  final x = (t - p.inhale - p.hold) / p.exhale;
  return (0.5 + 0.5 * cos(pi * x), BreathPhase.exhale);
}

class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key, this.initialPattern = 'balloon'});

  final String initialPattern;

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _clock = 0;
  late BreathPattern _pattern;
  BreathPhase _lastPhase = BreathPhase.inhale;
  int _cycles = 0;
  // Visit length from the ticker (it stops while the app is in the background).
  double _elapsed = 0;
  DateTime _started = DateTime.now();
  late ChildProfile _child;
  late final AppStore _store;
  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    _store = ref.read(storeProvider);
    _sound = ref.read(soundProvider);
    WidgetsBinding.instance.addObserver(this);
    _child = _store.activeChild!;
    _pattern = breathPatterns.firstWhere((p) => p.id == widget.initialPattern, orElse: () => breathPatterns.first);
    _ticker = createTicker(_tick)..start();
    _started = DateTime.now();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 1 / 60 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _clock += dt;
    _elapsed += dt;
    final (_, phase) = breathPhaseAt(_pattern, _clock);
    if (phase != _lastPhase) {
      _lastPhase = phase;
      if (phase == BreathPhase.inhale) _cycles++;
      // A gentle tap on each phase change, only if the parent turned haptics on.
      if (_child.sensory.hapticFeedback) HapticFeedback.lightImpact();
    }
    _frame.value++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    _logSession();
    super.dispose();
  }

  void _logSession() {
    final secs = _elapsed.round();
    if (secs < 10) return;
    _store.logSession(
      SensorySession(
        id: newId('sess'),
        childId: _child.id,
        mode: 'breathing',
        start: _started,
        durationSeconds: secs,
        sound: _pattern.id,
      ),
    );
  }

  void _choose(BreathPattern p) {
    if (p.id == _pattern.id) return;
    _sound.playSfx('tap');
    setState(() {
      _pattern = p;
      _clock = 0;
      _lastPhase = BreathPhase.inhale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _child.sensory;
    final tones = SC.paletteTones(s.palette);
    return Scaffold(
      backgroundColor: SC.slate,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: const [
                      HomeButton(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Breathing Buddy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      MuteButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: 'Breathing guide. Sammy breathes in and out with you.',
                    child: ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (context, _, _) {
                        final (b, phase) = breathPhaseAt(_pattern, _clock);
                        return _BreathView(
                          breath: b,
                          phase: phase,
                          pattern: _pattern,
                          color: tones[0],
                          calm: s.lowMotion,
                          cycles: _cycles,
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      for (final p in breathPatterns) ...[
                        Expanded(
                          child: _PatternChip(
                            key: ValueKey('breath_${p.id}'),
                            pattern: p,
                            selected: p.id == _pattern.id,
                            color: tones[0],
                            onTap: () => _choose(p),
                          ),
                        ),
                        if (p != breathPatterns.last) const SizedBox(width: 10),
                      ],
                    ],
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

class _BreathView extends StatelessWidget {
  final double breath;
  final BreathPhase phase;
  final BreathPattern pattern;
  final Color color;
  final bool calm;
  final int cycles;
  const _BreathView({
    required this.breath,
    required this.phase,
    required this.pattern,
    required this.color,
    required this.calm,
    required this.cycles,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      BreathPhase.inhale => pattern.inLabel,
      BreathPhase.hold => 'Hold',
      BreathPhase.exhale => pattern.outLabel,
    };
    return LayoutBuilder(
      builder: (context, c) {
        final base = min(c.maxWidth, c.maxHeight) * 0.6;
        final d = base * (0.55 + 0.45 * breath);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Soft glow that swells with the breath; no flashing (L16).
            Container(
              width: d * 1.25,
              height: d * 1.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color.withValues(alpha: 0.10 + 0.08 * breath), Colors.transparent]),
              ),
            ),
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08 + 0.06 * breath),
                border: Border.all(color: color.withValues(alpha: 0.5), width: 4),
              ),
            ),
            Sammy(size: base * 0.55, breath: breath, animate: !calm, mood: SammyMood.idle),
            Positioned(
              bottom: 12,
              child: Column(
                children: [
                  Text(
                    label,
                    key: const ValueKey('breath_label'),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SC.text.withValues(alpha: 0.85)),
                  ),
                  if (cycles > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < min(cycles, 10); i++)
                            Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(Icons.circle, size: 10, color: color.withValues(alpha: 0.7)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PatternChip extends StatelessWidget {
  final BreathPattern pattern;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PatternChip({super.key, required this.pattern, required this.selected, required this.color, required this.onTap});

  static const _icons = {
    'balloon': Icons.circle_outlined,
    'flower': Icons.local_florist_rounded,
    'box': Icons.crop_square_rounded,
  };

  /// One word per chip: three chips must fit a 360 dp phone without clipping.
  static const _short = {'balloon': 'Balloon', 'flower': 'Flower', 'box': 'Box'};

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${pattern.title} breathing',
      excludeSemantics: true,
      child: Material(
        color: selected ? color.withValues(alpha: 0.22) : SC.slate2,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : SC.slate3, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icons[pattern.id], color: color, size: 32),
                const SizedBox(height: 4),
                Text(
                  _short[pattern.id] ?? pattern.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
