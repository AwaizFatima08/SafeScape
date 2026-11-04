// Learn with Sammy chapters and built-in Picture Stories (v1.2, docs/v1.2-scope.md).
// The wording lives in assets/content/*.json so the app, the owner's review
// document (scripts/content_review.py) and the tests share one source.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

String _s(Object? v, [String fallback = '']) => v is String ? v : fallback;
int _i(Object? v, int fallback) => v is num ? v.toInt() : fallback;
List<Map<String, dynamic>> _maps(Object? v) => [
  for (final e in (v is List ? v : const []))
    if (e is Map) e.cast<String, dynamic>(),
];

/// One picture card: a sentence read aloud and its pictogram.
class LessonCard {
  final String text;
  final String icon;
  const LessonCard(this.text, this.icon);

  factory LessonCard.fromJson(Map<String, dynamic> j) => LessonCard(_s(j['text']), _s(j['icon'], 'star'));
}

class PracticeOption {
  final String label;
  final String icon;
  const PracticeOption(this.label, this.icon);
}

class CountStep {
  final int count;
  final String label;
  final String icon;
  const CountStep(this.count, this.label, this.icon);
}

enum PracticeType { choose, breathe, squeeze, count }

/// The errorless practice step at the end of a chapter (scope V2).
class Practice {
  final PracticeType type;
  final String prompt;
  final String reply;
  final List<PracticeOption> options; // choose
  final int repeats; // breathe: breaths, squeeze: times
  final List<CountStep> steps; // count

  const Practice({
    required this.type,
    required this.prompt,
    required this.reply,
    this.options = const [],
    this.repeats = 3,
    this.steps = const [],
  });

  factory Practice.fromJson(Map<String, dynamic> j) {
    final type = PracticeType.values.firstWhere((t) => t.name == j['type'], orElse: () => PracticeType.breathe);
    return Practice(
      type: type,
      prompt: _s(j['prompt']),
      reply: _s(j['reply'], 'Well done.'),
      options: [for (final o in _maps(j['options'])) PracticeOption(_s(o['label']), _s(o['icon'], 'star'))],
      repeats: _i(j['breaths'] ?? j['times'], 3).clamp(1, 10),
      steps: [
        for (final st in _maps(j['steps'])) CountStep(_i(st['count'], 3).clamp(1, 10), _s(st['label']), _s(st['icon'], 'star')),
      ],
    );
  }
}

class Chapter {
  final String id;
  final String title;
  final String icon;
  final String color; // palette name: lavender | mint | sand | blue
  final String summary;
  final List<LessonCard> cards;
  final Practice practice;

  const Chapter({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.cards,
    required this.practice,
  });

  /// Cards plus the practice step: what "steps total" means for a lesson.
  int get stepCount => cards.length + 1;

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
    id: _s(j['id']),
    title: _s(j['title'], 'Chapter'),
    icon: _s(j['icon'], 'star'),
    color: _s(j['color'], 'lavender'),
    summary: _s(j['summary']),
    cards: [for (final c in _maps(j['cards'])) LessonCard.fromJson(c)],
    practice: Practice.fromJson((j['practice'] as Map?)?.cast<String, dynamic>() ?? const {}),
  );
}

/// A built-in Picture Story page.
class StoryTemplatePage {
  final String text;
  final String icon;
  const StoryTemplatePage(this.text, this.icon);
}

class StoryTemplate {
  final String id;
  final String title;
  final String icon;
  final List<StoryTemplatePage> pages;
  const StoryTemplate({required this.id, required this.title, required this.icon, required this.pages});

  factory StoryTemplate.fromJson(Map<String, dynamic> j) => StoryTemplate(
    id: _s(j['id']),
    title: _s(j['title'], 'Story'),
    icon: _s(j['icon'], 'story'),
    pages: [for (final p in _maps(j['pages'])) StoryTemplatePage(_s(p['text']), _s(p['icon'], 'star'))],
  );
}

class LearningContent {
  final List<Chapter> chapters;
  final List<StoryTemplate> stories;
  const LearningContent({this.chapters = const [], this.stories = const []});

  static const empty = LearningContent();

  Chapter? chapter(String id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  StoryTemplate? story(String id) {
    for (final s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Parses both files; malformed entries are skipped rather than crashing.
  factory LearningContent.parse(String lessonsJson, String storiesJson) {
    Map<String, dynamic> obj(String src) {
      try {
        final v = jsonDecode(src);
        return v is Map ? v.cast<String, dynamic>() : const {};
      } catch (_) {
        return const {};
      }
    }

    return LearningContent(
      chapters: [
        for (final c in _maps(obj(lessonsJson)['chapters']))
          if (_s(c['id']).isNotEmpty) Chapter.fromJson(c),
      ].where((c) => c.cards.isNotEmpty).toList(),
      stories: [
        for (final s in _maps(obj(storiesJson)['stories']))
          if (_s(s['id']).isNotEmpty) StoryTemplate.fromJson(s),
      ].where((s) => s.pages.isNotEmpty).toList(),
    );
  }

  static Future<LearningContent> load() async {
    try {
      return LearningContent.parse(
        await rootBundle.loadString('assets/content/lessons.json'),
        await rootBundle.loadString('assets/content/stories.json'),
      );
    } catch (_) {
      return empty;
    }
  }
}
