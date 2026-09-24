// Soothing Sounds: four pre-filtered loops, a big volume slider, and an
// optional slow fade-out for bedtime.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/audio.dart';
import '../services/store.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

class SoundsScreen extends ConsumerStatefulWidget {
  const SoundsScreen({super.key});

  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> with WidgetsBindingObserver {
  late final AppStore _store;
  late final SoundService _sound;
  String? _playing;
  DateTime? _started;
  final _watch = Stopwatch();
  int _fadeMinutes = 0;
  Timer? _fadeTimer;
  DateTime? _fadeStart;
  double _fadeLevel = 1;

  static const _icons = {
    'hum': Icons.spa_rounded,
    'rain': Icons.water_drop_rounded,
    'ocean': Icons.waves_rounded,
    'marimba': Icons.piano_rounded,
  };
  static const _colors = {'hum': SC.lavender, 'rain': SC.blue, 'ocean': SC.mint, 'marimba': SC.sand};

  @override
  void initState() {
    super.initState();
    // Read once here: `ref` can't be used from dispose().
    _store = ref.read(storeProvider);
    _sound = ref.read(soundProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sound keeps playing with the screen off (bedtime); time still counts.
    if (state == AppLifecycleState.detached) _stop();
  }

  void _logCurrent() {
    final name = _playing;
    final start = _started;
    if (name == null || start == null) return;
    final secs = _watch.elapsed.inSeconds;
    _watch
      ..stop()
      ..reset();
    if (secs < 10) return;
    final child = _store.activeChild;
    if (child == null) return;
    _store.logSession(
      SensorySession(
        id: newId('sess'),
        childId: child.id,
        mode: 'sounds',
        start: start,
        durationSeconds: secs,
        sound: name,
      ),
    );
  }

  Future<void> _toggle(String name) async {
    if (_playing == name) {
      _stop();
      setState(() {});
      return;
    }
    _logCurrent();
    final child = _store.activeChild!;
    _playing = name;
    _started = DateTime.now();
    _watch.start();
    _fadeLevel = 1;
    _startFadeTimer();
    setState(() {});
    await _sound.playLoop(name, child.sensory.audioVariant);
  }

  void _stop() {
    _logCurrent();
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _playing = null;
    _sound.stopLoop(fade: const Duration(milliseconds: 1500));
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    if (_fadeMinutes == 0 || _playing == null) return;
    _fadeStart = DateTime.now();
    final total = Duration(minutes: _fadeMinutes).inMilliseconds;
    _fadeTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      final gone = DateTime.now().difference(_fadeStart!).inMilliseconds / total;
      // Full volume for the first half, then a slow fade to silence.
      _fadeLevel = gone < 0.5 ? 1 : (1 - (gone - 0.5) * 2).clamp(0.0, 1.0);
      _sound.setLoopLevel(_fadeLevel);
      if (gone >= 1) {
        _stop();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final vol = store.settings.masterVolume;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // Pinned: the way home is always visible, even on small phones.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: const [
                      HomeButton(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Soothing Sounds', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      MuteButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.1,
                        children: [
                          for (final n in soundNames)
                            _SoundCard(
                              key: ValueKey('sound_$n'),
                              title: soundTitles[n]!,
                              icon: _icons[n]!,
                              color: _colors[n]!,
                              playing: _playing == n,
                              onTap: () => _toggle(n),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text('Volume', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.volume_down_rounded, color: SC.textDim),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 14,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18),
                              ),
                              child: Slider(
                                key: const ValueKey('volume'),
                                value: vol,
                                onChanged: (v) {
                                  store.updateSettings((s) => s.masterVolume = v);
                                  _sound.configure(muted: store.settings.audioMuted, volume: v);
                                },
                              ),
                            ),
                          ),
                          const Icon(Icons.volume_up_rounded, color: SC.textDim),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Slowly fade out after', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final m in const [0, 10, 20, 30])
                            ChoiceChip(
                              key: ValueKey('fade_$m'),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Text(m == 0 ? 'Keep playing' : '$m min', style: const TextStyle(fontSize: 17)),
                              ),
                              selected: _fadeMinutes == m,
                              selectedColor: SC.mint.withValues(alpha: 0.3),
                              onSelected: (_) {
                                setState(() => _fadeMinutes = m);
                                _fadeLevel = 1;
                                _sound.setLoopLevel(1);
                                _startFadeTimer();
                              },
                            ),
                        ],
                      ),
                      if (store.activeChild?.sensory.muteHighPitch ?? false) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'High pitches are filtered out for a softer sound.',
                          style: TextStyle(color: SC.textDim),
                        ),
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

class _SoundCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool playing;
  final VoidCallback onTap;
  const _SoundCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: playing,
      label: '$title${playing ? ', playing. Tap to stop.' : ''}',
      excludeSemantics: true,
      child: Material(
        color: SC.slate2,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              color: playing ? color.withValues(alpha: 0.2) : Colors.transparent,
              border: Border.all(color: playing ? color : SC.slate3, width: playing ? 4 : 2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 52, color: color),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playing ? 'Playing' : 'Tap to play',
                    style: TextStyle(fontSize: 14, color: playing ? color : SC.textDim),
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
