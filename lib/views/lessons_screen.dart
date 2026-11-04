// Learn with Sammy (v1.2, docs/v1.2-scope.md V1–V3): eight Calm Skills
// chapters of picture cards, read aloud, each ending with an errorless
// practice. Every chapter is open; the suggested next one glows and finished
// ones get a star.

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
import 'practice.dart';

class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild;
    if (child == null) return const SizedBox.shrink();
    final chapters = ref.watch(learningProvider).chapters;
    final next = chapters.where((c) => !child.lessonsDone.contains(c.id)).firstOrNull;
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
                      child: Text('Learn with Sammy',
                          maxLines: 2, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.15)),
                    ),
                    MuteButton(),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '${child.lessonsDone.where((id) => chapters.any((c) => c.id == id)).length} of ${chapters.length} chapters finished',
                    key: const ValueKey('lessons_count'),
                    style: const TextStyle(fontSize: 16, color: SC.textDim),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 600 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: c.maxWidth < 400 ? 0.72 : 0.85,
                      ),
                      itemCount: chapters.length,
                      itemBuilder: (context, i) => _ChapterCard(
                        chapter: chapters[i],
                        number: i + 1,
                        done: child.lessonsDone.contains(chapters[i].id),
                        suggested: chapters[i] == next,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LessonPlayerScreen(chapterId: chapters[i].id)),
                        ),
                      ),
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

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final int number;
  final bool done;
  final bool suggested;
  final VoidCallback onTap;
  const _ChapterCard({required this.chapter, required this.number, required this.done, required this.suggested, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = SC.palette(chapter.color);
    return Semantics(
      button: true,
      label: 'Chapter $number. ${chapter.title}. ${chapter.summary}${done ? ' Finished.' : ''}',
      excludeSemantics: true,
      child: Material(
        color: SC.slate2,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          key: ValueKey('chapter_${chapter.id}'),
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(
                color: suggested ? color : (done ? SC.mint.withValues(alpha: 0.6) : SC.slate3),
                width: suggested ? 4 : 2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.14), SC.slate2],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('$number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const Spacer(),
                  if (done) const Icon(Icons.star_rounded, color: SC.sand, size: 30, semanticLabel: 'Finished'),
                  if (suggested && !done)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Next', style: TextStyle(color: SC.slate, fontWeight: FontWeight.bold)),
                    ),
                ]),
                Expanded(child: Center(child: StepPicture(iconKey: chapter.icon, size: 72))),
                Text(chapter.title,
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

/// Plays one chapter: its picture cards, then the practice, then a short
/// celebration. Back/Next are always available; swiping works too.
class LessonPlayerScreen extends ConsumerStatefulWidget {
  final String chapterId;
  const LessonPlayerScreen({super.key, required this.chapterId});

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  late final AppStore _store;
  late final SoundService _sound;
  late final Speech _speech;
  late final Chapter? _chapter;
  late final ChildProfile _child;
  final _pages = PageController();
  final _watch = Stopwatch()..start();
  DateTime _started = DateTime.now();
  int _page = 0;
  int _furthest = 0;
  bool _logged = false; // this reading is already recorded
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    // Read once here: `ref` can't be used from dispose().
    _store = ref.read(storeProvider);
    _sound = ref.read(soundProvider);
    _speech = ref.read(speechProvider);
    _chapter = ref.read(learningProvider).chapter(widget.chapterId);
    _child = _store.activeChild!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _readPage(0));
  }

  @override
  void dispose() {
    _pages.dispose();
    _logSession();
    super.dispose();
  }

  void _say(String text) => _speech.say(text);

  void _readPage(int i) {
    final c = _chapter;
    if (c == null) return;
    if (i < c.cards.length) {
      _say(i == 0 ? '${c.title}. ${c.cards[0].text}' : c.cards[i].text);
    } else {
      _say(c.practice.prompt);
    }
  }

  /// Records this reading: finished when the child reached the end, or a
  /// partial visit when they leave part-way (a quick peek isn't recorded).
  void _logSession({bool finished = false}) {
    final c = _chapter;
    if (c == null || _logged) return;
    final secs = _watch.elapsed.inSeconds;
    if (!finished && (secs < 5 || _furthest == 0)) return;
    _logged = true;
    _store.logSession(SensorySession(
      id: newId('sess'),
      childId: _child.id,
      mode: 'lesson',
      start: _started,
      durationSeconds: secs,
      sound: c.id,
      routineTitle: c.title,
      stepsDone: finished ? c.stepCount : (_furthest + 1).clamp(0, c.stepCount - 1),
      stepsTotal: c.stepCount,
    ));
  }

  void _go(int i) {
    final c = _chapter!;
    if (i > c.cards.length) {
      _finish();
      return;
    }
    final calm = _child.sensory.lowMotion;
    _pages.animateToPage(i, duration: Duration(milliseconds: calm ? 450 : 300), curve: Curves.easeInOut);
  }

  void _finish() {
    final c = _chapter!;
    if (!_logged) {
      _logSession(finished: true);
      _store.completeLesson(_child, c.id);
      _sound.playSfx('done');
    }
    _say('You finished ${c.title}. Well done!');
    setState(() => _celebrate = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = _chapter;
    if (c == null) return const Scaffold(body: Center(child: Text('This chapter is not available.')));
    final total = c.stepCount;
    final calm = _child.sensory.lowMotion;
    final onPractice = _page == c.cards.length;
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
                          key: const ValueKey('lesson_progress'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: SC.slate2, borderRadius: BorderRadius.circular(20)),
                          child: Text('${_page + 1} / $total',
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
                        child: Text(c.title,
                            key: const ValueKey('lesson_title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_page + 1) / total,
                          minHeight: 10,
                          backgroundColor: SC.slate3,
                          color: SC.palette(c.color),
                          semanticsLabel: 'Page ${_page + 1} of $total',
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const ValueKey('lesson_pages'),
                        controller: _pages,
                        itemCount: c.cards.length + 1,
                        onPageChanged: (i) {
                          setState(() {
                            _page = i;
                            if (i > _furthest) _furthest = i;
                          });
                          _readPage(i);
                        },
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: i < c.cards.length
                              ? _CardView(card: c.cards[i], onRead: () => _say(c.cards[i].text))
                              : PracticeView(
                                  practice: c.practice,
                                  calm: calm,
                                  haptics: _child.sensory.hapticFeedback,
                                  say: _say,
                                  onDone: () => _sound.playSfx('step'),
                                ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(children: [
                        ChunkyIconButton(
                          key: const ValueKey('lesson_back'),
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
                              key: const ValueKey('lesson_next'),
                              onPressed: () => _go(_page + 1),
                              icon: Icon(onPractice ? Icons.check_rounded : Icons.arrow_forward_rounded),
                              label: Text(onPractice ? 'Finish' : 'Next', style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            if (_celebrate)
              _LessonDone(
                title: c.title,
                calm: calm,
                onMore: () => Navigator.of(context).pop(),
                onAgain: () {
                  // A new reading, recorded on its own.
                  _logged = false;
                  _furthest = 0;
                  _started = DateTime.now();
                  _watch.reset();
                  setState(() {
                    _celebrate = false;
                    _page = 0;
                  });
                  _pages.jumpToPage(0);
                  _readPage(0);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  final LessonCard card;
  final VoidCallback onRead;
  const _CardView({required this.card, required this.onRead});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final pic = (c.maxHeight * 0.42).clamp(96.0, 220.0);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StepPicture(iconKey: card.icon, size: pic),
              const SizedBox(height: 20),
              Text(card.text,
                  key: const ValueKey('lesson_card_text'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3)),
              const SizedBox(height: 12),
              TextButton.icon(
                key: const ValueKey('lesson_read_again'),
                onPressed: onRead,
                icon: const Icon(Icons.record_voice_over_rounded),
                label: const Text('Read it again', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _LessonDone extends StatelessWidget {
  final String title;
  final bool calm;
  final VoidCallback onMore;
  final VoidCallback onAgain;
  const _LessonDone({required this.title, required this.calm, required this.onMore, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        key: const ValueKey('lesson_done'),
        color: SC.slate.withValues(alpha: 0.95),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Sammy(size: 180, mood: SammyMood.celebrating, animate: !calm),
              const SizedBox(height: 8),
              const Icon(Icons.star_rounded, color: SC.sand, size: 56),
              Text('You finished\n$title!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: SC.sand, height: 1.2)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    height: kTouch,
                    child: FilledButton.icon(
                      key: const ValueKey('lesson_more'),
                      onPressed: onMore,
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('More chapters'),
                    ),
                  ),
                  SizedBox(
                    height: kTouch,
                    child: OutlinedButton.icon(
                      key: const ValueKey('lesson_again'),
                      onPressed: onAgain,
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
    );
  }
}
