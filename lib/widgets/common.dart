import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content.dart';
import '../core/theme.dart';
import '../state/providers.dart';

/// A 72 x 72 dp rounded icon button (PDD "chubby touch boundaries").
class ChunkyIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color? background;

  const ChunkyIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = SC.text,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: background ?? SC.slate2,
          borderRadius: BorderRadius.circular(kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius),
            onTap: onTap,
            child: SizedBox(width: kTouch, height: kTouch, child: Icon(icon, size: 34, color: color)),
          ),
        ),
      ),
    );
  }
}

/// Global one-tap mute, on every child screen (PDD Step 3).
class MuteButton extends ConsumerWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final muted = store.settings.audioMuted;
    return ChunkyIconButton(
      key: const ValueKey('mute'),
      icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
      label: muted ? 'Sound off' : 'Sound on',
      color: muted ? SC.peach : SC.mint,
      onTap: () {
        store.updateSettings((s) => s.audioMuted = !s.audioMuted);
        final sound = ref.read(soundProvider);
        sound.configure(muted: store.settings.audioMuted, volume: store.settings.masterVolume);
        if (store.settings.audioMuted) ref.read(speechProvider).stop();
      },
    );
  }
}

/// Back-to-hub button used on child screens.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) => ChunkyIconButton(
    key: const ValueKey('home'),
    icon: Icons.home_rounded,
    label: 'Back to hub',
    onTap: () => Navigator.of(context).maybePop(),
  );
}

/// Shows a routine picture: the parent's photo if there is one, else the icon.
class StepPicture extends StatelessWidget {
  final String iconKey;
  final String? photoPath;
  final double size;

  const StepPicture({super.key, required this.iconKey, this.photoPath, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _icon()),
      );
    }
    return _icon();
  }

  Widget _icon() => Image.asset(iconAsset(iconKey), width: size, height: size,
      filterQuality: FilterQuality.medium, excludeFromSemantics: true);
}

/// Parent gate (L14): a multiplication question a young child can't answer.
Future<bool> showParentGate(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ParentGateDialog(),
  );
  return ok ?? false;
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog();
  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _rand = Random();
  late int a, b;
  String entry = '';
  bool wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    a = 3 + _rand.nextInt(7); // 3..9
    b = 6 + _rand.nextInt(4); // 6..9
    entry = '';
  }

  void _press(String k) {
    setState(() {
      wrong = false;
      if (k == 'del') {
        if (entry.isNotEmpty) entry = entry.substring(0, entry.length - 1);
        return;
      }
      if (entry.length < 3) entry += k;
      if (entry.length >= '${a * b}'.length) {
        if (int.tryParse(entry) == a * b) {
          Navigator.of(context).pop(true);
        } else {
          wrong = true;
          _newQuestion();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget key(String k) => Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 64,
        height: 56,
        child: FilledButton.tonal(
          key: ValueKey('gate_$k'),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(56, 52)),
          onPressed: () => _press(k),
          child: k == 'del'
              ? const Icon(Icons.backspace_outlined, semanticLabel: 'Delete')
              : Text(k, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
    return AlertDialog(
      title: const Text('For grown-ups'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('What is $a × $b?', key: const ValueKey('gate_question'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: 140,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: SC.slate, borderRadius: BorderRadius.circular(14)),
              child: Text(entry.isEmpty ? ' ' : entry, style: const TextStyle(fontSize: 26)),
            ),
            SizedBox(
              height: 24,
              child: wrong ? const Text('Not quite. Here is a new one.', style: TextStyle(color: SC.peach)) : null,
            ),
            for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', 'del']])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final k in row) k.isEmpty ? const SizedBox(width: 72) : key(k)],
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel'))],
    );
  }
}

/// Section heading used in the parent dashboard.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SC.lavender)),
  );
}
