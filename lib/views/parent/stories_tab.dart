// Grown-ups → Stories (v1.2, scope V5): write a Picture Story for this child,
// from scratch or by copying a built-in one, with a pictogram or the family's
// own photo on each page. Photos stay on the device (§0 L6).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/photos.dart';
import '../stories_screen.dart';
import 'routine_editor.dart' show pickIcon;

class StoriesTab extends ConsumerWidget {
  const StoriesTab({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final store = ref.read(storeProvider);
    final child = store.activeChild!;
    final templates = ref.read(learningProvider).stories;
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: SC.slate2,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                key: const ValueKey('story_new_blank'),
                leading: const Icon(Icons.add_rounded, color: SC.mint),
                title: const Text('Start from scratch', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context, -1),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Or copy a story and make it your own (for example, add photos of the real place):',
                    style: TextStyle(color: SC.textDim)),
              ),
              for (final (i, t) in templates.indexed)
                ListTile(
                  key: ValueKey('story_copy_${t.id}'),
                  leading: StepPicture(iconKey: t.icon, size: 36),
                  title: Text(t.title),
                  subtitle: Text('${t.pages.length} pages'),
                  onTap: () => Navigator.pop(context, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final story = choice < 0
        ? PictureStory(id: newId('story'), childId: child.id, title: '', iconKey: 'story', pages: [])
        : PictureStory(
            id: newId('story'),
            childId: child.id,
            title: templates[choice].title,
            iconKey: templates[choice].icon,
            pages: [
              for (final p in templates[choice].pages) StoryPage(id: newId('page'), text: p.text, iconKey: p.icon),
            ],
          );
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryEditor(story: story, isNew: true)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild!;
    final stories = store.storiesFor(child.id);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_story'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New story'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const SectionTitle('My stories'),
          Text(
            'Write a short story for ${child.alias} about something coming up: a trip, a new school, a visit. '
            'Short, calm sentences work best, like "I will…", "It might feel…", "I can…". '
            'It appears in Picture Stories under "My stories". The ${ref.watch(learningProvider).stories.length} '
            'built-in stories are always there too.',
            style: const TextStyle(color: SC.textDim),
          ),
          const SizedBox(height: 8),
          if (stories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No stories of your own yet. Tap "New story".', style: TextStyle(color: SC.textDim)),
            ),
          for (final st in stories)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                key: ValueKey('edit_story_${st.id}'),
                contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                leading: StepPicture(
                  iconKey: st.iconKey,
                  photoPath: st.pages.isEmpty ? null : st.pages.first.photoPath,
                  size: 44,
                ),
                title: Text(st.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                subtitle: Text('${st.pages.length} pages'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryEditor(story: st))),
                trailing: PopupMenuButton<String>(
                  key: ValueKey('story_menu_${st.id}'),
                  color: SC.slate3,
                  onSelected: (v) async {
                    if (v == 'preview' && st.pages.isNotEmpty) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => StoryReaderScreen(story: StoryToRead.own(st))),
                      );
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('Delete "${st.title}"?'),
                          content: const Text('Its photos are removed from this device too.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) store.deleteStory(st);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'preview', child: Text('Preview')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StoryEditor extends ConsumerStatefulWidget {
  final PictureStory story;
  final bool isNew;
  const StoryEditor({super.key, required this.story, this.isNew = false});

  @override
  ConsumerState<StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends ConsumerState<StoryEditor> {
  late final PictureStory st = PictureStory.fromJson(widget.story.toJson()); // edit a copy
  late final _title = TextEditingController(text: st.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty || st.pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(title.isEmpty ? 'Please give the story a title.' : 'Please add at least one page.')));
      return;
    }
    st.title = title;
    ref.read(storeProvider).upsertStory(st);
    Navigator.of(context).pop();
  }

  Future<void> _editPage([int? index]) async {
    final page = index == null
        ? StoryPage(id: newId('page'), text: '', iconKey: 'star')
        : StoryPage.fromJson(st.pages[index].toJson());
    final result = await showModalBottomSheet<StoryPage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SC.slate2,
      showDragHandle: true,
      builder: (_) => _PageEditor(page: page),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        st.pages.add(result);
      } else {
        st.pages[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New story' : 'Edit story'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(key: const ValueKey('save_story'), onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_page'),
        onPressed: () => _editPage(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add page'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Row(children: [
            InkWell(
              key: const ValueKey('story_cover'),
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                final k = await pickIcon(context, st.iconKey);
                if (k != null) setState(() => st.iconKey = k);
              },
              child: Container(
                width: kTouch,
                height: kTouch,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: SC.slate2, borderRadius: BorderRadius.circular(18)),
                child: StepPicture(iconKey: st.iconKey, size: 48),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey('story_title_field'),
                controller: _title,
                maxLength: 40,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(labelText: 'Story title', counterText: ''),
              ),
            ),
          ]),
          const SectionTitle('Pages'),
          if (st.pages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No pages yet. Tap "Add page".', style: TextStyle(color: SC.textDim)),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (a, b) => setState(() {
              if (b > a) b--;
              st.pages.insert(b, st.pages.removeAt(a));
            }),
            children: [
              for (final (i, p) in st.pages.indexed)
                Card(
                  key: ValueKey(p.id),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.drag_indicator_rounded, color: SC.textDim),
                        const SizedBox(width: 4),
                        StepPicture(iconKey: p.iconKey, photoPath: p.photoPath, size: 44),
                      ]),
                    ),
                    title: Text('${i + 1}. ${p.text}', maxLines: 3, overflow: TextOverflow.ellipsis),
                    onTap: () => _editPage(i),
                    trailing: IconButton(
                      tooltip: 'Remove page',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => setState(() => st.pages.removeAt(i)),
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

class _PageEditor extends StatefulWidget {
  final StoryPage page;
  const _PageEditor({required this.page});
  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  late final _text = TextEditingController(text: widget.page.text);
  late String _icon = widget.page.iconKey;
  late String? _photo = widget.page.photoPath;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final path = await pickLocalPhoto(source);
      if (path != null) setState(() => _photo = path);
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
            const Text('Page', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('page_text'),
              controller: _text,
              maxLength: 160,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'What happens on this page',
                hintText: 'e.g. We will go to the airport in the car.',
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              InkWell(
                key: const ValueKey('page_icon'),
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
              key: const ValueKey('page_done'),
              onPressed: () {
                final t = _text.text.trim();
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write the page.')));
                  return;
                }
                Navigator.pop(context, StoryPage(id: widget.page.id, text: t, iconKey: _icon, photoPath: _photo));
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
