// Screen 3: the Flow Canvas. Touching or dragging (with any number of
// fingers or a whole palm) stirs glowing pastel waves; a breathing ring
// guides 4 s in / 6 s out, and Sammy breathes along.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/audio.dart';
import '../services/stats.dart';
import '../services/store.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';
import 'flow_sim.dart';

class FlowCanvasScreen extends ConsumerStatefulWidget {
  const FlowCanvasScreen({super.key});

  @override
  ConsumerState<FlowCanvasScreen> createState() => _FlowCanvasScreenState();
}

class _FlowCanvasScreenState extends ConsumerState<FlowCanvasScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final FlowSim sim;
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _clock = 0;
  final _pointers = <int, (Offset, Duration)>{};

  // Session tracking: foreground time and touch count only.
  final _watch = Stopwatch();
  int _touches = 0;
  final _paletteSeconds = <String, double>{};
  DateTime _started = DateTime.now();
  DateTime _lastTapSound = DateTime(2000);
  DateTime _lastHaptic = DateTime(2000);
  late ChildProfile _child;
  late final AppStore _store;
  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    // Read once here: `ref` can't be used from dispose().
    _store = ref.read(storeProvider);
    _sound = ref.read(soundProvider);
    WidgetsBinding.instance.addObserver(this);
    _child = _store.activeChild!;
    sim = FlowSim(density: _child.sensory.particleDensity, motion: _child.sensory.motionFactor);
    _ticker = createTicker(_tick)..start();
    _started = DateTime.now();
    _watch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSound());
  }

  void _syncSound() {
    final sound = _sound;
    if (_child.sensory.canvasSound) {
      sound.playLoop('hum', _child.sensory.audioVariant, level: 0.55);
    } else {
      sound.stopLoop();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 1 / 60 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _clock += dt;
    sim.density = _child.sensory.particleDensity;
    sim.motion = _child.sensory.motionFactor;
    sim.step(dt);
    final p = _child.sensory.palette;
    _paletteSeconds[p] = (_paletteSeconds[p] ?? 0) + dt;
    _frame.value++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watch.start();
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      _watch.stop();
      if (_ticker.isActive) _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    _logSession();
    _sound.stopLoop();
    super.dispose();
  }

  void _logSession() {
    final secs = _watch.elapsed.inSeconds;
    if (secs < 10) return;
    // The palette used longest in this visit is the one recorded.
    var palette = _child.sensory.palette;
    var best = -1.0;
    _paletteSeconds.forEach((k, v) {
      if (v > best) {
        best = v;
        palette = k;
      }
    });
    _store.logSession(
      SensorySession(
        id: newId('sess'),
        childId: _child.id,
        mode: 'flow_canvas',
        start: _started,
        durationSeconds: secs,
        palette: palette,
        touchRhythm: touchRhythmLabel(_touches, secs),
      ),
    );
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = (e.localPosition, e.timeStamp);
    _touches++;
    sim.touchDown(e.localPosition.dx, e.localPosition.dy);
    final now = DateTime.now();
    if (now.difference(_lastTapSound).inMilliseconds > 450) {
      _lastTapSound = now;
      _sound.playSfx('tap');
    }
    if (_child.sensory.hapticFeedback && now.difference(_lastHaptic).inMilliseconds > 250) {
      _lastHaptic = now;
      HapticFeedback.lightImpact();
    }
  }

  void _move(PointerMoveEvent e) {
    final prev = _pointers[e.pointer];
    final dt = prev == null ? 1 / 60 : max(1, (e.timeStamp - prev.$2).inMicroseconds) / 1e6;
    sim.touchMove(e.localPosition.dx, e.localPosition.dy, e.delta.dx, e.delta.dy, dt);
    _pointers[e.pointer] = (e.localPosition, e.timeStamp);
  }

  void _up(PointerEvent e) => _pointers.remove(e.pointer);

  void _setPalette(String p) {
    setState(() => _child.sensory.palette = p);
    _store.updateChild(_child);
  }

  void _toggleSound() {
    setState(() => _child.sensory.canvasSound = !_child.sensory.canvasSound);
    _store.updateChild(_child);
    _syncSound();
  }

  @override
  Widget build(BuildContext context) {
    final s = _child.sensory;
    final tones = SC.paletteTones(s.palette);
    return Scaffold(
      backgroundColor: SC.slate,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(children: const [HomeButton(), Spacer(), MuteButton()]),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  sim.resize(Size(c.maxWidth, c.maxHeight));
                  return Semantics(
                    label: 'Calming canvas. Touch and drag anywhere to make gentle waves.',
                    child: Listener(
                      key: const ValueKey('flow_canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      onPointerMove: _move,
                      onPointerUp: _up,
                      onPointerCancel: _up,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(child: CustomPaint(painter: FlowPainter(sim, tones, _frame))),
                          ),
                          if (s.breathingRing)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _frame,
                                  builder: (context, _, _) {
                                    final (b, inhale) = FlowSim.breathAt(_clock);
                                    return _BreathingGuide(
                                      breath: b,
                                      inhale: inhale,
                                      color: tones[0],
                                      calm: s.lowMotion,
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _BottomBar(
              palette: s.palette,
              soundOn: s.canvasSound,
              onPalette: _setPalette,
              onSound: _toggleSound,
              onReset: sim.reset,
            ),
          ],
        ),
      ),
    );
  }
}

class FlowPainter extends CustomPainter {
  final FlowSim sim;
  final List<Color> tones;
  FlowPainter(this.sim, this.tones, Listenable repaint) : super(repaint: repaint);

  final _glow = Paint()..blendMode = BlendMode.plus;
  final _core = Paint();
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.9,
          colors: [tones[0].withValues(alpha: 0.07), SC.slate],
        ).createShader(rect),
    );
    for (final r in sim.ripples) {
      final a = (1 - r.age / r.life).clamp(0.0, 1.0);
      _ring
        ..color = tones[r.tone].withValues(alpha: 0.35 * a)
        ..strokeWidth = 2 + 4 * a;
      canvas.drawCircle(Offset(r.x, r.y), r.r, _ring);
    }
    for (final p in sim.particles) {
      if (p.life <= 0) continue;
      // Fade in quickly, fade out slowly.
      final a = min(1.0, (1 - p.life) * 8) * min(1.0, p.life * 1.6);
      final c = tones[p.tone];
      final o = Offset(p.x, p.y);
      _glow.color = c.withValues(alpha: 0.10 * a);
      canvas.drawCircle(o, p.size * 3, _glow);
      _core.color = c.withValues(alpha: (p.ambient ? 0.45 : 0.75) * a);
      canvas.drawCircle(o, p.size, _core);
    }
  }

  @override
  bool shouldRepaint(FlowPainter old) => old.tones != tones;
}

class _BreathingGuide extends StatelessWidget {
  final double breath;
  final bool inhale;
  final Color color;
  final bool calm;
  const _BreathingGuide({required this.breath, required this.inhale, required this.color, required this.calm});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final base = min(c.maxWidth, c.maxHeight) * 0.42;
        final d = base * (0.62 + 0.38 * breath);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.06 + 0.05 * breath),
                border: Border.all(color: color.withValues(alpha: 0.45), width: 3),
              ),
            ),
            Positioned(
              bottom: 8,
              child: Column(
                children: [
                  Sammy(size: 96, breath: breath, animate: !calm, mood: SammyMood.idle),
                  Text(
                    inhale ? 'Breathe in' : 'Breathe out',
                    style: TextStyle(fontSize: 18, color: SC.text.withValues(alpha: 0.75)),
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

class _BottomBar extends StatelessWidget {
  final String palette;
  final bool soundOn;
  final ValueChanged<String> onPalette;
  final VoidCallback onSound;
  final VoidCallback onReset;

  const _BottomBar({
    required this.palette,
    required this.soundOn,
    required this.onPalette,
    required this.onSound,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final sound = ChunkyIconButton(
      key: const ValueKey('canvas_sound'),
      icon: soundOn ? Icons.music_note_rounded : Icons.music_off_rounded,
      label: soundOn ? 'Soft ambient hum playing' : 'Ambient hum off',
      color: soundOn ? SC.mint : SC.textDim,
      onTap: onSound,
    );
    final reset = ChunkyIconButton(
      key: const ValueKey('canvas_reset'),
      icon: Icons.refresh_rounded,
      label: 'Reset canvas',
      onTap: onReset,
    );
    final chips = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [for (final p in palettes) _chip(p)],
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: SC.slate2, borderRadius: BorderRadius.circular(kRadius)),
      child: LayoutBuilder(
        builder: (context, c) {
          // 6 x 72 dp targets need ~450 dp; narrower phones get two rows.
          if (c.maxWidth >= 6 * kTouch + 12) {
            return Row(
              children: [
                sound,
                Expanded(child: Center(child: chips)),
                reset,
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              chips,
              Row(children: [sound, const Spacer(), reset]),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String p) => Semantics(
    button: true,
    selected: p == palette,
    label: '${paletteNames[p]} colours',
    child: InkWell(
      key: ValueKey('palette_$p'),
      customBorder: const CircleBorder(),
      onTap: () => onPalette(p),
      child: SizedBox(
        width: kTouch,
        height: kTouch,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: p == palette ? 44 : 34,
            height: p == palette ? 44 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SC.palette(p),
              border: Border.all(color: p == palette ? SC.text : Colors.transparent, width: 3),
            ),
          ),
        ),
      ),
    ),
  );
}
