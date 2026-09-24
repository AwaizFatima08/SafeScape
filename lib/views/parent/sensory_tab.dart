// Sensory Sensitivity controls (PDD Screen 5 + the Sensory Control Board).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class SensoryTab extends ConsumerWidget {
  const SensoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild!;
    final s = child.sensory;
    void edit(void Function(SensoryProfile s) f) {
      f(s);
      store.updateChild(child);
    }

    Widget toggle(String key, String title, String subtitle, bool value, void Function(bool) set) => Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        key: ValueKey(key),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: SC.textDim)),
        value: value,
        onChanged: (v) => edit((_) => set(v)),
      ),
    );

    Widget slider(String key, String title, String low, String high, double value, double min, double max,
            void Function(double) set) =>
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Slider(key: ValueKey(key), value: value.clamp(min, max), min: min, max: max, onChanged: (v) => edit((_) => set(v))),
              Row(children: [
                Text(low, style: const TextStyle(color: SC.textDim)),
                const Spacer(),
                Text(high, style: const TextStyle(color: SC.textDim)),
              ]),
            ]),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('Settings for ${child.alias}', style: const TextStyle(color: SC.textDim, fontSize: 16)),
        const SectionTitle('Light & motion'),
        toggle('set_low_motion', 'Low Motion Mode', 'Halves particle speed and stops pulsing cards.', s.lowMotion,
            (v) => s.lowMotion = v),
        slider('set_motion', 'Motion speed', 'Slow', 'Lively', s.motionSpeed, 0.3, 1.0, (v) => s.motionSpeed = v),
        slider('set_density', 'Particle density', 'Few', 'Many', s.particleDensity, 0.2, 1.0, (v) => s.particleDensity = v),
        toggle('set_soft_light', 'Soft Lighting', 'A warm colour wash over every screen.', s.softLighting,
            (v) => s.softLighting = v),
        slider('set_warmth', 'Colour temperature', 'Neutral', 'Warm', s.colorTemperature, 0, 1, (v) => s.colorTemperature = v),
        toggle('set_breath', 'Breathing ring', 'Shows the 4-in / 6-out breathing guide on the canvas.', s.breathingRing,
            (v) => s.breathingRing = v),
        toggle('set_haptics', 'Gentle vibration', 'A light tap feeling when the canvas is touched.', s.hapticFeedback,
            (v) => s.hapticFeedback = v),
        const SectionTitle('Sound'),
        toggle('set_mute_high', 'Mute High Pitch', 'Keeps every sound below 4 kHz.', s.muteHighPitch,
            (v) => s.muteHighPitch = v),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Audio pitch cut-off', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Text('Sounds above this pitch are removed. Lower is softer and more muffled.',
                  style: TextStyle(color: SC.textDim)),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                key: const ValueKey('set_cutoff'),
                segments: const [
                  ButtonSegment(value: 6000, label: Text('6 kHz')),
                  ButtonSegment(value: 4000, label: Text('4 kHz')),
                  ButtonSegment(value: 2500, label: Text('2.5 kHz')),
                ],
                selected: {s.audioCutoffHz},
                onSelectionChanged: (v) => edit((s) => s.audioCutoffHz = v.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 6),
              Text('Now using: ${s.effectiveCutoffHz} Hz${s.muteHighPitch && s.audioCutoffHz > 4000 ? ' (Mute High Pitch is on)' : ''}',
                  style: const TextStyle(color: SC.textDim)),
            ]),
          ),
        ),
        toggle('set_canvas_sound', 'Ambient hum on the canvas', 'Plays a warm, low hum while the canvas is open.',
            s.canvasSound, (v) => s.canvasSound = v),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            key: const ValueKey('set_speak'),
            title: const Text('Read steps aloud', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            subtitle: const Text('Routine steps and stories are spoken slowly (all children).',
                style: TextStyle(color: SC.textDim)),
            value: store.settings.speakSteps,
            onChanged: (v) => store.updateSettings((g) => g.speakSteps = v),
          ),
        ),
      ],
    );
  }
}
