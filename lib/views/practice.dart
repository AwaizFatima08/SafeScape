// The practice step at the end of a Learn with Sammy chapter (scope V2).
// All four kinds are errorless: every choice gets a warm reply, nothing has to
// be finished, and the lesson's Next button is always available.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/learning.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';
import 'flow_sim.dart';

class PracticeView extends StatelessWidget {
  final Practice practice;
  final bool calm;
  final bool haptics;

  /// Reads a line aloud (respects mute and "read steps aloud").
  final ValueChanged<String> say;

  /// Called once when the child has completed the practice.
  final VoidCallback onDone;

  const PracticeView({
    super.key,
    required this.practice,
    required this.calm,
    required this.say,
    required this.onDone,
    this.haptics = false,
  });

  @override
  Widget build(BuildContext context) {
    return switch (practice.type) {
      PracticeType.choose => _ChoosePractice(practice: practice, say: say, onDone: onDone),
      PracticeType.breathe => _BreathePractice(practice: practice, say: say, onDone: onDone),
      PracticeType.squeeze => _SqueezePractice(practice: practice, say: say, onDone: onDone, calm: calm, haptics: haptics),
      PracticeType.count => _CountPractice(practice: practice, say: say, onDone: onDone),
    };
  }
}

/// Sammy's warm answer after a practice.
class _Reply extends StatelessWidget {
  final String text;
  const _Reply(this.text);

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('practice_reply'),
    children: [
      const Sammy(size: 84, mood: SammyMood.celebrating),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SC.slate2,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: SC.mint.withValues(alpha: 0.5), width: 2),
          ),
          child: Text(text, style: const TextStyle(fontSize: 18, height: 1.3)),
        ),
      ),
    ],
  );
}

class _Prompt extends StatelessWidget {
  final String text;
  const _Prompt(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, key: const ValueKey('practice_prompt'), textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.25)),
  );
}

// ---------------------------------------------------------------- choose

class _ChoosePractice extends StatefulWidget {
  final Practice practice;
  final ValueChanged<String> say;
  final VoidCallback onDone;
  const _ChoosePractice({required this.practice, required this.say, required this.onDone});

  @override
  State<_ChoosePractice> createState() => _ChoosePracticeState();
}

class _ChoosePracticeState extends State<_ChoosePractice> {
  int? _picked;

  void _pick(int i) {
    final first = _picked == null;
    setState(() => _picked = i);
    widget.say('${widget.practice.options[i].label}. ${widget.practice.reply}');
    if (first) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.practice;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Prompt(p.prompt),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final (i, o) in p.options.indexed)
                SizedBox(
                  width: (c.maxWidth - 12) / 2,
                  child: Semantics(
                    button: true,
                    selected: _picked == i,
                    label: o.label,
                    excludeSemantics: true,
                    child: Material(
                      color: _picked == i ? SC.mint.withValues(alpha: 0.18) : SC.slate2,
                      borderRadius: BorderRadius.circular(kRadius),
                      child: InkWell(
                        key: ValueKey('choose_$i'),
                        borderRadius: BorderRadius.circular(kRadius),
                        onTap: () => _pick(i),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 120),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(kRadius),
                            border: Border.all(color: _picked == i ? SC.mint : SC.slate3, width: _picked == i ? 3 : 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StepPicture(iconKey: o.icon, size: 64),
                              const SizedBox(height: 6),
                              Text(o.label, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_picked != null) ...[const SizedBox(height: 16), _Reply(p.reply)],
      ],
    );
  }
}

// ---------------------------------------------------------------- breathe

class _BreathePractice extends StatefulWidget {
  final Practice practice;
  final ValueChanged<String> say;
  final VoidCallback onDone;
  const _BreathePractice({required this.practice, required this.say, required this.onDone});

  @override
  State<_BreathePractice> createState() => _BreathePracticeState();
}

class _BreathePracticeState extends State<_BreathePractice> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  bool _done = false;
  bool? _lastInhale;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      final (_, inhale) = FlowSim.breathAt(t);
      if (_lastInhale != inhale) widget.say(inhale ? 'Breathe in' : 'Breathe out');
      _lastInhale = inhale;
      final breaths = (t / 10).floor();
      if (!_done && breaths >= widget.practice.repeats) {
        _done = true;
        _ticker.stop();
        widget.say(widget.practice.reply);
        widget.onDone();
      }
      setState(() => _t = t);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.practice;
    final (b, inhale) = FlowSim.breathAt(_t);
    final done = _done ? p.repeats : (_t / 10).floor() + 1;
    return Column(
      children: [
        _Prompt(p.prompt),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final d = (c.biggest.shortestSide * 0.85) * (0.55 + 0.45 * (_done ? 0.5 : b));
            return Center(
              child: Container(
                key: const ValueKey('breathe_circle'),
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SC.blue.withValues(alpha: 0.15),
                  border: Border.all(color: SC.blue, width: 4),
                ),
                child: Text(
                  _done ? 'Well done' : (inhale ? 'Breathe in' : 'Breathe out'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ),
        Text(_done ? '' : 'Breath $done of ${p.repeats}', style: const TextStyle(fontSize: 18, color: SC.textDim)),
        if (_done) _Reply(p.reply),
      ],
    );
  }
}

// ---------------------------------------------------------------- squeeze

class _SqueezePractice extends StatefulWidget {
  final Practice practice;
  final ValueChanged<String> say;
  final VoidCallback onDone;
  final bool calm;
  final bool haptics;
  const _SqueezePractice({required this.practice, required this.say, required this.onDone, required this.calm, required this.haptics});

  @override
  State<_SqueezePractice> createState() => _SqueezePracticeState();
}

class _SqueezePracticeState extends State<_SqueezePractice> {
  bool _pressed = false;
  int _count = 0;

  void _down() {
    setState(() => _pressed = true);
    widget.say('Squeeze');
    if (widget.haptics) HapticFeedback.lightImpact();
  }

  void _up() {
    if (!_pressed) return;
    final wasDone = _count >= widget.practice.repeats;
    setState(() {
      _pressed = false;
      _count++;
    });
    if (!wasDone && _count >= widget.practice.repeats) {
      widget.say(widget.practice.reply);
      widget.onDone();
    } else {
      widget.say('And let go');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.practice;
    final done = _count >= p.repeats;
    return Column(
      children: [
        _Prompt(p.prompt),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final d = c.biggest.shortestSide * 0.8;
            return Center(
              child: Semantics(
                button: true,
                label: 'Squeeze ball. Press and hold, then let go.',
                child: Listener(
                  key: const ValueKey('squeeze_ball'),
                  onPointerDown: (_) => _down(),
                  onPointerUp: (_) => _up(),
                  onPointerCancel: (_) => _up(),
                  child: AnimatedScale(
                    scale: _pressed ? 0.72 : 1,
                    duration: Duration(milliseconds: widget.calm ? 600 : 350),
                    curve: Curves.easeInOut,
                    child: Container(
                      width: d,
                      height: d,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [SC.sand, SC.sand.withValues(alpha: 0.55)]),
                      ),
                      child: Text(
                        _pressed ? 'Squeeze…' : (done ? 'Soft hands' : 'Press and hold'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SC.slate),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Text(done ? '' : 'Squeeze ${_count + 1 > p.repeats ? p.repeats : _count + 1} of ${p.repeats}',
            style: const TextStyle(fontSize: 18, color: SC.textDim)),
        if (done) _Reply(p.reply),
      ],
    );
  }
}

// ---------------------------------------------------------------- count (grounding)

class _CountPractice extends StatefulWidget {
  final Practice practice;
  final ValueChanged<String> say;
  final VoidCallback onDone;
  const _CountPractice({required this.practice, required this.say, required this.onDone});

  @override
  State<_CountPractice> createState() => _CountPracticeState();
}

class _CountPracticeState extends State<_CountPractice> {
  int _step = 0;
  int _lit = 0;
  bool _done = false;

  static const _numbers = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];

  @override
  void initState() {
    super.initState();
    final steps = widget.practice.steps;
    if (steps.isEmpty) {
      _done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.say(steps.first.label));
    }
  }

  void _tap(int i) {
    final steps = widget.practice.steps;
    final step = steps[_step];
    // Any star lights the next one: little fingers shouldn't have to aim.
    if (_lit >= step.count) return;
    setState(() => _lit++);
    widget.say(_numbers[(_lit - 1).clamp(0, 9)]);
    if (_lit >= step.count) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        if (_step + 1 < steps.length) {
          setState(() {
            _step++;
            _lit = 0;
          });
          widget.say(steps[_step].label);
        } else if (!_done) {
          setState(() => _done = true);
          widget.say(widget.practice.reply);
          widget.onDone();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.practice;
    if (_done) {
      return ListView(padding: EdgeInsets.zero, children: [_Prompt(p.prompt), const SizedBox(height: 12), _Reply(p.reply)]);
    }
    final step = p.steps[_step];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Prompt(p.prompt),
        Row(
          children: [
            StepPicture(iconKey: step.icon, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Text(step.label, key: const ValueKey('count_label'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < step.count; i++)
              Semantics(
                button: true,
                label: 'Star ${i + 1}',
                child: InkWell(
                  key: ValueKey('count_star_$i'),
                  customBorder: const CircleBorder(),
                  onTap: () => _tap(i),
                  child: SizedBox(
                    width: kTouch,
                    height: kTouch,
                    child: Icon(
                      i < _lit ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 56,
                      color: i < _lit ? SC.sand : SC.textDim,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Step ${_step + 1} of ${p.steps.length}', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: SC.textDim)),
      ],
    );
  }
}
