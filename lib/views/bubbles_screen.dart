// Bubble Pop: slow pastel bubbles drift up; a touch pops one with a soft,
// low-passed "plop" and a small ripple. Nothing can be missed: bubbles that
// reach the top simply fade and new ones rise. Low Motion halves the speed.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/audio.dart';
import '../services/stats.dart';
import '../services/store.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

class Bubble {
  double x, y, r, vy, wobble, phase;
  int tone;
  double life = 1; // 1 = whole; after a pop it shrinks to 0 quickly
  bool popped = false;
  Bubble(this.x, this.y, this.r, this.vy, this.wobble, this.phase, this.tone);
}

class Pop {
  final double x, y, r;
  final int tone;
  double age = 0;
  Pop(this.x, this.y, this.r, this.tone);
}

/// Pure simulation, unit-testable without widgets.
class BubbleSim {
  BubbleSim({this.motion = 1, Random? random, this.maxBubbles = 7}) : _rand = random ?? Random();

  final Random _rand;
  double motion;
  int maxBubbles;
  Size size = Size.zero;
  final bubbles = <Bubble>[];
  final pops = <Pop>[];
  double _spawnIn = 0;

  void resize(Size s) => size = s;

  void reset() {
    bubbles.clear();
    pops.clear();
  }

  void step(double dt) {
    if (size == Size.zero) return;
    final m = motion.clamp(0.25, 2.0);
    _spawnIn -= dt;
    if (_spawnIn <= 0 && bubbles.where((b) => !b.popped).length < maxBubbles) {
      spawn();
      _spawnIn = 0.9 + _rand.nextDouble() * 1.2;
    }
    for (final b in bubbles) {
      if (b.popped) {
        b.life -= dt * 5;
        continue;
      }
      b.phase += dt;
      b.y -= b.vy * m * dt;
      b.x += sin(b.phase * 1.3) * b.wobble * m * dt;
      // Gone off the top: fade out (never "lost", just floated away).
      if (b.y + b.r < -10) b.life -= dt * 2;
    }
    bubbles.removeWhere((b) => b.life <= 0);
    for (final p in pops) {
      p.age += dt;
    }
    pops.removeWhere((p) => p.age > 0.7);
  }

  void spawn() {
    final r = 34 + _rand.nextDouble() * 34; // 34..68 px: every bubble is a 72 dp target with its halo
    bubbles.add(Bubble(
      r + _rand.nextDouble() * (size.width - 2 * r),
      size.height + r,
      r,
      // Rise speed scales with the screen so a bubble crosses it in about
      // 20-30 s at motion 1 (half that fast in Low Motion).
      size.height / (30 - _rand.nextDouble() * 10),
      6 + _rand.nextDouble() * 8,
      _rand.nextDouble() * 6,
      _rand.nextInt(3),
    ));
  }

  /// Pops the bubble nearest to the touch, if the touch is on or near it.
  Bubble? touch(double x, double y) {
    Bubble? best;
    var bestD = double.infinity;
    for (final b in bubbles) {
      if (b.popped) continue;
      final d = sqrt((b.x - x) * (b.x - x) + (b.y - y) * (b.y - y));
      if (d <= b.r + 24 && d < bestD) {
        bestD = d;
        best = b;
      }
    }
    if (best != null) {
      best.popped = true;
      pops.add(Pop(best.x, best.y, best.r, best.tone));
    }
    return best;
  }
}

class BubblesScreen extends ConsumerStatefulWidget {
  const BubblesScreen({super.key});

  @override
  ConsumerState<BubblesScreen> createState() => _BubblesScreenState();
}

class _BubblesScreenState extends ConsumerState<BubblesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final BubbleSim sim;
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  // Visit length from the ticker (it stops while the app is in the background).
  double _elapsed = 0;
  int _touches = 0;
  int _popped = 0;
  DateTime _started = DateTime.now();
  DateTime _lastHaptic = DateTime(2000);
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
    sim = BubbleSim(motion: _child.sensory.motionFactor);
    _ticker = createTicker(_tick)..start();
    _started = DateTime.now();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 1 / 60 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _elapsed += min(dt, 0.1);
    sim.motion = _child.sensory.motionFactor;
    sim.step(min(dt, 0.1));
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
        mode: 'bubbles',
        start: _started,
        durationSeconds: secs,
        touchRhythm: touchRhythmLabel(_touches, secs),
      ),
    );
  }

  void _down(PointerDownEvent e) {
    _touches++;
    final b = sim.touch(e.localPosition.dx, e.localPosition.dy);
    if (b == null) return;
    _popped++;
    _sound.playSfx('pop');
    final now = DateTime.now();
    if (_child.sensory.hapticFeedback && now.difference(_lastHaptic).inMilliseconds > 250) {
      _lastHaptic = now;
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = SC.paletteTones(_child.sensory.palette);
    return Scaffold(
      backgroundColor: SC.slate,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: const [
                  HomeButton(),
                  SizedBox(width: 12),
                  Expanded(child: Text('Bubble Pop', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                  MuteButton(),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  sim.resize(Size(c.maxWidth, c.maxHeight));
                  return Semantics(
                    label: 'Bubble pop. Touch a bubble to pop it softly.',
                    child: Listener(
                      key: const ValueKey('bubble_canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      child: RepaintBoundary(
                        child: CustomPaint(painter: BubblePainter(sim, tones, _frame), size: Size.infinite),
                      ),
                    ),
                  );
                },
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (context, _, _) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _popped == 0 ? 'Touch a bubble' : '',
                  key: const ValueKey('bubble_hint'),
                  style: const TextStyle(color: SC.textDim, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  final BubbleSim sim;
  final List<Color> tones;
  BubblePainter(this.sim, this.tones, Listenable repaint) : super(repaint: repaint);

  final _fill = Paint();
  final _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final _shine = Paint()..color = Colors.white.withValues(alpha: 0.35);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SC.slate, tones[2].withValues(alpha: 0.08)],
        ).createShader(rect),
    );
    for (final p in sim.pops) {
      final a = (1 - p.age / 0.7).clamp(0.0, 1.0);
      _rim
        ..color = tones[p.tone].withValues(alpha: 0.5 * a)
        ..strokeWidth = 2 + 3 * a;
      canvas.drawCircle(Offset(p.x, p.y), p.r * (1 + 0.8 * (1 - a)), _rim);
    }
    for (final b in sim.bubbles) {
      final r = b.r * (b.popped ? b.life : 1);
      final a = b.life.clamp(0.0, 1.0);
      final c = tones[b.tone];
      final o = Offset(b.x, b.y);
      _fill.color = c.withValues(alpha: 0.18 * a);
      canvas.drawCircle(o, r, _fill);
      _rim
        ..color = c.withValues(alpha: 0.75 * a)
        ..strokeWidth = 2.5;
      canvas.drawCircle(o, r, _rim);
      _shine.color = Colors.white.withValues(alpha: 0.35 * a);
      canvas.drawCircle(o + Offset(-r * 0.35, -r * 0.35), r * 0.18, _shine);
    }
  }

  @override
  bool shouldRepaint(BubblePainter old) => old.tones != tones;
}
