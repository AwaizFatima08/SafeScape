// Feelings Check-in: four big faces. The child taps how they feel; Sammy
// answers with one gentle sentence and offers a calming tool. The pick is
// logged (no duration) so the Parent & Therapist dashboard can show feelings
// over the week. No feeling is wrong, and nothing has to be chosen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';
import 'breathing_screen.dart';
import 'bubbles_screen.dart';
import 'flow_canvas_screen.dart';
import 'sounds_screen.dart';

class FeelingsScreen extends ConsumerStatefulWidget {
  const FeelingsScreen({super.key});

  @override
  ConsumerState<FeelingsScreen> createState() => _FeelingsScreenState();
}

class _FeelingsScreenState extends ConsumerState<FeelingsScreen> {
  Feeling? _picked;

  void _pick(Feeling f) {
    final store = ref.read(storeProvider);
    final child = store.activeChild!;
    ref.read(soundProvider).playSfx('tap');
    store.logSession(
      SensorySession(
        id: newId('sess'),
        childId: child.id,
        mode: 'feeling',
        start: DateTime.now(),
        sound: f.id,
      ),
    );
    setState(() => _picked = f);
    if (store.settings.speakSteps) ref.read(speechProvider).say(f.sammySays);
  }

  Widget _suggested(String mode) => switch (mode) {
        'sounds' => const SoundsScreen(),
        'breathing' => const BreathingScreen(),
        'bubbles' => const BubblesScreen(),
        _ => const FlowCanvasScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild;
    if (child == null) return const SizedBox.shrink();
    final calm = child.sensory.lowMotion;
    final picked = _picked;
    return Scaffold(
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
                        child: Text('How do you feel?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      MuteButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: picked == null ? _faces(context) : _answer(context, picked, calm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _faces(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: (c.maxWidth / 2) / ((c.maxHeight - 14) / 2),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final f in feelings)
            Semantics(
              button: true,
              label: 'I feel ${f.label}',
              excludeSemantics: true,
              child: Material(
                key: ValueKey('feel_${f.id}'),
                color: SC.slate2,
                borderRadius: BorderRadius.circular(kRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(kRadius),
                  onTap: () => _pick(f),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(color: SC.slate3, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Image.asset(iconAsset(f.icon), fit: BoxFit.contain),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(f.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _answer(BuildContext context, Feeling f, bool calm) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Sammy(size: 120, animate: !calm, mood: f.id == 'happy' ? SammyMood.celebrating : SammyMood.idle),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SC.slate2,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: SC.slate3, width: 2),
                ),
                child: Text(
                  f.sammySays,
                  key: const ValueKey('sammy_says'),
                  style: const TextStyle(fontSize: 20, height: 1.3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 110,
          height: 110,
          child: Image.asset(iconAsset(f.icon)),
        ),
        const Spacer(),
        SizedBox(
          height: 72,
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('feel_go'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => _suggested(f.suggestedMode)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              f.suggestionLabel,
              key: const ValueKey('feel_go_label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('feel_done'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Just checking in', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
