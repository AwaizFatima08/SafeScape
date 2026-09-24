// Edit one routine: title, cover picture, and steps (title, picture or photo,
// micro-story), reorderable. Photos stay on the device (L6).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/content.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class RoutineEditor extends ConsumerStatefulWidget {
  final Routine routine;
  final bool isNew;
  const RoutineEditor({super.key, required this.routine, this.isNew = false});

  @override
  ConsumerState<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends ConsumerState<RoutineEditor> {
  late final Routine r = Routine.fromJson(widget.routine.toJson()); // edit a copy
  late final _title = TextEditingController(text: r.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty || r.steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(title.isEmpty ? 'Please give the routine a name.' : 'Please add at least one step.')));
      return;
    }
    r.title = title;
    ref.read(storeProvider).upsertRoutine(r);
    Navigator.of(context).pop();
  }

  Future<void> _editStep([int? index]) async {
    final step = index == null
        ? RoutineStep(id: newId('step'), title: '', iconKey: 'star')
        : RoutineStep.fromJson(r.steps[index].toJson());
    final result = await showModalBottomSheet<RoutineStep>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SC.slate2,
      showDragHandle: true,
      builder: (_) => _StepEditor(step: step),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        r.steps.add(result);
      } else {
        r.steps[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New routine' : 'Edit routine'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(key: const ValueKey('save_routine'), onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_step'),
        onPressed: () => _editStep(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add step'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Row(children: [
            InkWell(
              key: const ValueKey('routine_icon'),
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                final k = await pickIcon(context, r.iconKey);
                if (k != null) setState(() => r.iconKey = k);
              },
              child: Container(
                width: kTouch,
                height: kTouch,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: SC.slate2, borderRadius: BorderRadius.circular(18)),
                child: StepPicture(iconKey: r.iconKey, size: 48),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey('routine_title'),
                controller: _title,
                maxLength: 40,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(labelText: 'Routine name', counterText: ''),
              ),
            ),
          ]),
          const SectionTitle('Steps'),
          if (r.steps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No steps yet. Tap "Add step".', style: TextStyle(color: SC.textDim)),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (a, b) => setState(() {
              if (b > a) b--;
              r.steps.insert(b, r.steps.removeAt(a));
            }),
            children: [
              for (final (i, s) in r.steps.indexed)
                Card(
                  key: ValueKey(s.id),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.drag_indicator_rounded, color: SC.textDim),
                        const SizedBox(width: 4),
                        StepPicture(iconKey: s.iconKey, photoPath: s.photoPath, size: 44),
                      ]),
                    ),
                    title: Text('${i + 1}. ${s.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: s.story.isEmpty ? null : Text(s.story, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _editStep(i),
                    trailing: IconButton(
                      tooltip: 'Remove step',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => setState(() => r.steps.removeAt(i)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grid of the bundled pictograms.
Future<String?> pickIcon(BuildContext context, String current) => showModalBottomSheet<String>(
  context: context,
  backgroundColor: SC.slate2,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SizedBox(
    height: MediaQuery.of(context).size.height * 0.7,
    child: GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(12),
      children: [
        for (final e in iconLabels.entries)
          InkWell(
            key: ValueKey('icon_${e.key}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context, e.key),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: e.key == current ? SC.lavender : Colors.transparent, width: 2),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                StepPicture(iconKey: e.key, size: 40),
                const SizedBox(height: 4),
                Text(e.value, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
      ],
    ),
  ),
);

class _StepEditor extends StatefulWidget {
  final RoutineStep step;
  const _StepEditor({required this.step});
  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  late final _title = TextEditingController(text: widget.step.title);
  late final _story = TextEditingController(text: widget.step.story);
  late String _icon = widget.step.iconKey;
  late String? _photo = widget.step.photoPath;

  @override
  void dispose() {
    _title.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 900, maxHeight: 900, imageQuality: 82);
      if (x == null) return;
      final dir = await getApplicationSupportDirectory();
      final folder = Directory('${dir.path}/photos');
      await folder.create(recursive: true);
      final dest = File('${folder.path}/${newId('photo')}.jpg');
      await File(x.path).copy(dest.path);
      setState(() => _photo = dest.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add that photo.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Step', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('step_title'),
              controller: _title,
              maxLength: 40,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(labelText: 'What happens (e.g. Put on shoes)', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('step_story'),
              controller: _story,
              maxLength: 200,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Short story (optional)',
                hintText: 'e.g. The doctor listens to my heart. It might feel cold. That is okay.',
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              InkWell(
                key: const ValueKey('step_icon'),
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  final k = await pickIcon(context, _icon);
                  if (k != null) setState(() => _icon = k);
                },
                child: Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: SC.slate, borderRadius: BorderRadius.circular(18)),
                  child: StepPicture(iconKey: _icon, photoPath: _photo, size: 72),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Camera'),
                  ),
                  if (_photo != null)
                    TextButton(onPressed: () => setState(() => _photo = null), child: const Text('Use picture instead')),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            const Text('Tap the picture to choose a different one. Photos stay on this device only.',
                style: TextStyle(color: SC.textDim)),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('step_done'),
              onPressed: () {
                final t = _title.text.trim();
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe the step.')));
                  return;
                }
                Navigator.pop(
                  context,
                  RoutineStep(
                    id: widget.step.id,
                    title: t,
                    iconKey: _icon,
                    story: _story.text.trim(),
                    photoPath: _photo,
                    isCompleted: widget.step.isCompleted,
                  ),
                );
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
