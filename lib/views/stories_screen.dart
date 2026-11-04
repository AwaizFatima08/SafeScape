// Picture Stories (v1.2, docs/v1.2-scope.md V4–V6): built-in first-person
// stories for real situations plus stories a grown-up wrote for this child,
// read page by page and aloud.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/learning.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/audio.dart';
import '../services/speech.dart';
import '../services/store.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/sammy.dart';

/// What the reader shows, from a built-in story or a parent's own.
class StoryToRead {
  final String id;
  final String title;
  final String icon;
  final bool own;
  final List<({String text, String icon, String? photo})> pages;
  const StoryToRead({required this.id, required this.title, required this.icon, required this.own, required this.pages});

  factory StoryToRead.builtIn(StoryTemplate t) => StoryToRead(
    id: t.id,
    title: t.title,
    icon: t.icon,
    own: false,
    pages: [for (final p in t.pages) (text: p.text, icon: p.icon, photo: null)],
  );

  factory StoryToRead.own(PictureStory s) => StoryToRead(
    id: s.id,
    title: s.title,
    icon: s.iconKey,
    own: true,
    pages: [for (final p in s.pages) (text: p.text, icon: p.iconKey, photo: p.photoPath)],
  );
}

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild;
    if (child == null) return const SizedBox.shrink();
    final own = store.storiesFor(child.id).where((s) => s.pages.isNotEmpty).map(StoryToRead.own).toList();
    final builtIn = ref.watch(learningProvider).stories.map(StoryToRead.builtIn).toList();

    void open(StoryToRead s) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryReaderScreen(story: s)));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(children: const [
                    HomeButton(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Picture Stories',
                          maxLines: 2, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.15)),
                    ),
                    MuteButton(),
                  ]),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 600 ? 3 : 2;
                    final delegate = SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: c.maxWidth < 400 ? 0.78 : 0.95,
                    );
                    Widget grid(List<StoryToRead> list) => SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: delegate,
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _StoryCard(story: list[i], onTap: () => open(list[i])),
                          childCount: list.length,
                        ),
                      ),
                    );
                    Widget heading(String t) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SC.lavender)),
                      ),
                    );
                    return CustomScrollView(
                      key: const ValueKey('stories_list'),
                      slivers: [
                        if (own.isNotEmpty) ...[heading('My stories'), grid(own)],
                        if (own.isNotEmpty) heading('More stories'),
                        grid(builtIn),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final StoryToRead story;
  final VoidCallback onTap;
  const _StoryCard({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${story.title}. ${story.pages.length} pages.',
      excludeSemantics: true,
      child: Material(
        color: SC.slate2,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          key: ValueKey('story_${story.id}'),
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: story.own ? SC.sand.withValues(alpha: 0.6) : SC.slate3, width: 2),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: StepPicture(
                      iconKey: story.icon,
                      photoPath: story.own ? story.pages.first.photo : null,
                      size: 84,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(story.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoryReaderScreen extends ConsumerStatefulWidget {
  final StoryToRead story;
  const StoryReaderScreen({super.key, required this.story});

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> {
  late final AppStore _store;
  late final SoundService _sound;
  late final Speech _speech;
  late final ChildProfile _child;
  final _pages = PageController();
  final _watch = Stopwatch()..start();
  DateTime _started = DateTime.now();
  int _page = 0;
  int _furthest = 0;
  bool _ended = false;
  bool _logged = false; // this reading is already recorded

  StoryToRead get s => widget.story;

  @override
  void initState() {
    super.initState();
    // Read once here: `ref` can't be used from dispose().
    _store = ref.read(storeProvider);
    _sound = ref.read(soundProvider);
    _speech = ref.read(speechProvider);
    _child = _store.activeChild!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _read(0));
  }

  @override
  void dispose() {
    _pages.dispose();
    _log();
    super.dispose();
  }

  void _read(int i) {
    if (s.pages.isEmpty) return;
    _speech.say(i == 0 ? '${s.title}. ${s.pages[0].text}' : s.pages[i].text);
  }

  /// Records this reading: finished at "The end", or a partial visit when the
  /// child leaves part-way (a quick peek isn't recorded).
  void _log({bool finished = false}) {
    if (_logged) return;
    final secs = _watch.elapsed.inSeconds;
    if (!finished && (secs < 5 || _furthest == 0)) return;
    _logged = true;
    _store.logSession(SensorySession(
      id: newId('sess'),
      childId: _child.id,
      mode: 'story',
      start: _started,
      durationSeconds: secs,
      sound: s.id,
      routineTitle: s.title,
      stepsDone: finished ? s.pages.length : _furthest + 1,
      stepsTotal: s.pages.length,
    ));
  }

  void _go(int i) {
    if (i >= s.pages.length) {
      if (!_ended) _sound.playSfx('done');
      _log(finished: true);
      setState(() => _ended = true);
      _speech.say('The end.');
      return;
    }
    final calm = _child.sensory.lowMotion;
    _pages.animateToPage(i, duration: Duration(milliseconds: calm ? 450 : 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final calm = _child.sensory.lowMotion;
    final last = _page == s.pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(children: [
                        const HomeButton(),
                        const Spacer(),
                        Container(
                          key: const ValueKey('story_progress'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: SC.slate2, borderRadius: BorderRadius.circular(20)),
                          child: Text('${_page + 1} / ${s.pages.length}',
                              style: const TextStyle(fontSize: 16, color: SC.mint, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        const MuteButton(),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(s.title,
                            key: const ValueKey('story_title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const ValueKey('story_pages'),
                        controller: _pages,
                        itemCount: s.pages.length,
                        onPageChanged: (i) {
                          setState(() {
                            _page = i;
                            if (i > _furthest) _furthest = i;
                          });
                          _read(i);
                        },
                        itemBuilder: (context, i) => LayoutBuilder(builder: (context, c) {
                          final page = s.pages[i];
                          final pic = (c.maxHeight * 0.45).clamp(96.0, 240.0);
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: c.maxHeight),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  StepPicture(iconKey: page.icon, photoPath: page.photo, size: pic),
                                  const SizedBox(height: 20),
                                  Text(page.text,
                                      key: const ValueKey('story_text'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 26, height: 1.35)),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    key: const ValueKey('story_read_again'),
                                    onPressed: () => _speech.say(page.text),
                                    icon: const Icon(Icons.record_voice_over_rounded),
                                    label: const Text('Read it again', style: TextStyle(fontSize: 17)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(children: [
                        ChunkyIconButton(
                          key: const ValueKey('story_back'),
                          icon: Icons.arrow_back_rounded,
                          label: 'Back',
                          color: _page == 0 ? SC.slate3 : SC.text,
                          onTap: () {
                            if (_page > 0) _go(_page - 1);
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: kTouch,
                            child: FilledButton.icon(
                              key: const ValueKey('story_next'),
                              onPressed: () => _go(_page + 1),
                              icon: Icon(last ? Icons.check_rounded : Icons.arrow_forward_rounded),
                              label: Text(last ? 'The end' : 'Next', style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            if (_ended)
              Positioned.fill(
                child: Container(
                  key: const ValueKey('story_end'),
                  color: SC.slate.withValues(alpha: 0.95),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Sammy(size: 170, mood: SammyMood.celebrating, animate: !calm),
                        const SizedBox(height: 12),
                        const Text('The end', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: SC.sand)),
                        const SizedBox(height: 6),
                        Text(s.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          alignment: WrapAlignment.center,
                          children: [
                            SizedBox(
                              height: kTouch,
                              child: FilledButton.icon(
                                key: const ValueKey('story_more'),
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.auto_stories_rounded),
                                label: const Text('More stories'),
                              ),
                            ),
                            SizedBox(
                              height: kTouch,
                              child: OutlinedButton.icon(
                                key: const ValueKey('story_again'),
                                onPressed: () {
                                  // A new reading, recorded on its own.
                                  _logged = false;
                                  _furthest = 0;
                                  _started = DateTime.now();
                                  _watch.reset();
                                  setState(() {
                                    _ended = false;
                                    _page = 0;
                                  });
                                  _pages.jumpToPage(0);
                                  _read(0);
                                },
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('Read again', style: TextStyle(fontSize: 18)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
