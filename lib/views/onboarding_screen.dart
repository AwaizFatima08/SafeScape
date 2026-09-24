// Screen 1: child nickname, age group and sensory presets (about 30 s).
//
// Worded so it can't be mistaken for a sign-in form (a lesson from Play
// review of the owner's other apps): the nickname is optional and the page
// says plainly that no account is needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import '../widgets/sammy.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  /// When true this adds another child from the Parent Zone instead of
  /// running first-launch setup.
  final bool addingChild;
  const OnboardingScreen({super.key, this.addingChild = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  String _age = '5-7';
  bool _lowMotion = false;
  bool _lowMotionTouched = false;
  bool _softLighting = false;
  bool _muteHighPitch = true;
  bool _cloud = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _enter() {
    final store = ref.read(storeProvider);
    if (!widget.addingChild) store.updateSettings((s) => s.cloudBackup = _cloud);
    store.addChild(
      alias: _name.text,
      ageGroup: _age,
      lowMotion: _lowMotion,
      softLighting: _softLighting,
      muteHighPitch: _muteHighPitch,
    );
    if (store.settings.cloudBackup) {
      final cloud = ref.read(cloudProvider);
      cloud.ensureSignedIn().then((_) => cloud.pushAll(store.data));
    }
    if (widget.addingChild) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.addingChild ? AppBar(title: const Text('Add a child')) : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                if (!widget.addingChild) ...[
                  const Center(child: Sammy(size: 170, mood: SammyMood.idle)),
                  const SizedBox(height: 8),
                  const Text('Welcome to SafeScape',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: SC.text)),
                  const SizedBox(height: 6),
                  const Text('A calm place to play, breathe and get ready for what comes next.\n'
                      'No sign-up needed.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: SC.textDim)),
                  const SizedBox(height: 24),
                ],
                const Text('Child\'s nickname (optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('alias_field'),
                  controller: _name,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 22),
                  decoration: const InputDecoration(hintText: 'e.g. Sunny', counterText: ''),
                ),
                const SizedBox(height: 18),
                const Text('Age group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final a in const ['2-4', '5-7', '8-10'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _Pill(
                            key: ValueKey('age_$a'),
                            label: a,
                            selected: _age == a,
                            onTap: () => setState(() {
                              _age = a;
                              if (!_lowMotionTouched) _lowMotion = a == '2-4';
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Sensory presets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('You can change these any time in the grown-ups area.',
                    style: TextStyle(color: SC.textDim)),
                const SizedBox(height: 6),
                _Toggle(
                  keyName: 'low_motion',
                  title: 'Low Motion Mode',
                  subtitle: 'Slows moving particles by half.',
                  value: _lowMotion,
                  onChanged: (v) => setState(() {
                    _lowMotion = v;
                    _lowMotionTouched = true;
                  }),
                ),
                _Toggle(
                  keyName: 'soft_lighting',
                  title: 'Soft Lighting',
                  subtitle: 'Adds a warm colour wash to every screen.',
                  value: _softLighting,
                  onChanged: (v) => setState(() => _softLighting = v),
                ),
                _Toggle(
                  keyName: 'mute_high_pitch',
                  title: 'Mute High Pitch',
                  subtitle: 'Removes sharp, high sounds (keeps everything below 4 kHz).',
                  value: _muteHighPitch,
                  onChanged: (v) => setState(() => _muteHighPitch = v),
                ),
                if (!widget.addingChild) ...[
                  const SizedBox(height: 8),
                  _Toggle(
                    keyName: 'cloud_backup',
                    title: 'Private cloud backup',
                    subtitle: 'Keeps the nickname, settings, routines and activity times safe if this device '
                        'is lost or replaced. No photos, audio or location are ever uploaded. '
                        'You can turn this off or delete it at any time.',
                    value: _cloud,
                    onChanged: (v) => setState(() => _cloud = v),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 72,
                  child: FilledButton(
                    key: const ValueKey('enter_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SC.lavender,
                      shape: const StadiumBorder(),
                      shadowColor: SC.lavender,
                      elevation: 8,
                    ),
                    onPressed: _enter,
                    child: Text(widget.addingChild ? 'Add child' : 'Enter SafeScape',
                        style: const TextStyle(fontSize: 22, color: SC.slate)),
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

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Age $label',
      child: Material(
        color: selected ? SC.mint : SC.slate2,
        shape: StadiumBorder(side: BorderSide(color: selected ? SC.mint : SC.slate3, width: 2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: kTouch,
            child: Center(
              child: Text(label,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: selected ? SC.slate : SC.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String keyName;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.keyName, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: SwitchListTile(
        key: ValueKey(keyName),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: SC.textDim)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
