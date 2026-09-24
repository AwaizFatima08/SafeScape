// Wait Timer: a slowly shrinking pastel disc for "a few more minutes" before
// a transition. No numbers counting down and no alarm: it ends with one soft,
// low marimba note (design review §2.3).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/audio.dart';
import '../services/speech.dart';
import '../services/store.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';

class WaitTimerScreen extends ConsumerStatefulWidget {
  const WaitTimerScreen({super.key});

  @override
  ConsumerState<WaitTimerScreen> createState() => _WaitTimerScreenState();
}

class _WaitTimerScreenState extends ConsumerState<WaitTimerScreen> with SingleTickerProviderStateMixin {
  late final AppStore _store;
  late final SoundService _sound;
  late final Speech _speech;
  late final AnimationController _c = AnimationController(vsync: this)..addStatusListener(_status);

  @override
  void initState() {
    super.initState();
    // Read once here: `ref` can't be used from dispose().
    _store = ref.read(storeProvider);
    _sound = ref.read(soundProvider);
    _speech = ref.read(speechProvider);
  }
  int _minutes = 2;
  String _thenIcon = 'play';
  bool _running = false;
  bool _finished = false;
  DateTime? _started;

  static const _thenChoices = ['play', 'meal', 'car', 'bath', 'bed', 'school', 'park', 'tablet'];

  void _status(AnimationStatus s) {
    if (s == AnimationStatus.completed && _running) {
      setState(() {
        _running = false;
        _finished = true;
      });
      _sound.playSfx('wait_end');
      _speech.say('Time for ${iconLabels[_thenIcon]!.toLowerCase()}.');
      _log();
    }
  }

  void _start() {
    _c.duration = Duration(minutes: _minutes);
    _started = DateTime.now();
    setState(() {
      _running = true;
      _finished = false;
    });
    _c.forward(from: 0);
  }

  void _log() {
    final child = _store.activeChild;
    final start = _started;
    if (child == null || start == null) return;
    // Time actually waited, from the timer itself (not the wall clock).
    final secs = (_c.value * (_c.duration?.inSeconds ?? 0)).round();
    if (secs < 10) return;
    _store.logSession(SensorySession(
      id: newId('sess'),
      childId: child.id,
      mode: 'wait_timer',
      start: start,
      durationSeconds: secs,
    ));
    _started = null;
  }

  @override
  void dispose() {
    if (_running) _log();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = _store.activeChild?.sensory.lowMotion ?? false;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: const [
                  HomeButton(),
                  SizedBox(width: 12),
                  Expanded(child: Text('Wait Timer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                  MuteButton(),
                ]),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 1.15,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => LayoutBuilder(builder: (context, box) {
                      final d = min(box.maxWidth, box.maxHeight) * 0.86;
                      return Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: d,
                          height: d,
                          child: CustomPaint(
                            key: const ValueKey('wait_disc'),
                            painter: _DiscPainter(remaining: _running ? 1 - _c.value : (_finished ? 0 : 1)),
                          ),
                        ),
                        if (_finished)
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Sammy(size: 150, mood: SammyMood.celebrating, animate: !calm),
                            Text('Time for ${iconLabels[_thenIcon]!.toLowerCase()}!',
                                key: const ValueKey('wait_done'),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ])
                        else
                          StepPicture(iconKey: _thenIcon, size: d * 0.3),
                      ]);
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_running) ...[
                  const Text('How long?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final m in const [1, 2, 5, 10, 15])
                      ChoiceChip(
                        key: ValueKey('wait_$m'),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: Text('$m min', style: const TextStyle(fontSize: 18)),
                        ),
                        selected: _minutes == m,
                        selectedColor: SC.sand.withValues(alpha: 0.3),
                        onSelected: (_) => setState(() => _minutes = m),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Then it\'s time for...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final k in _thenChoices)
                      Semantics(
                        button: true,
                        selected: _thenIcon == k,
                        label: iconLabels[k],
                        child: InkWell(
                          key: ValueKey('then_$k'),
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() => _thenIcon = k),
                          child: Container(
                            width: kTouch,
                            height: kTouch,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: SC.slate2,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _thenIcon == k ? SC.sand : SC.slate3, width: _thenIcon == k ? 3 : 2),
                            ),
                            child: StepPicture(iconKey: k, size: 48),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: kTouch,
                    child: FilledButton.icon(
                      key: const ValueKey('wait_start'),
                      style: FilledButton.styleFrom(backgroundColor: SC.sand, foregroundColor: SC.slate),
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      label: Text(_finished ? 'Start another' : 'Start', style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ] else
                  SizedBox(
                    height: kTouch,
                    child: OutlinedButton.icon(
                      key: const ValueKey('wait_stop'),
                      onPressed: () {
                        _c.stop();
                        _log();
                        setState(() => _running = false);
                      },
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop', style: TextStyle(fontSize: 18)),
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

class _DiscPainter extends CustomPainter {
  final double remaining; // 1 -> 0
  _DiscPainter({required this.remaining});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect, Paint()..color = SC.slate2);
    canvas.drawArc(rect.deflate(6), -pi / 2, 2 * pi * remaining, true, Paint()..color = SC.sand.withValues(alpha: 0.55));
    canvas.drawOval(
      rect.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = SC.sand.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_DiscPainter o) => o.remaining != remaining;
}
