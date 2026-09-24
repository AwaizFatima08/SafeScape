// One-tap "Export to OT" PDF (PDD Step 5, metric 4). Worded as a usage
// summary, never an assessment (L15).

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/content.dart';
import '../models/models.dart';
import 'stats.dart';

String _d(DateTime d) =>
    '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';

String _mins(num seconds) {
  final m = seconds / 60;
  return m < 1 && seconds > 0 ? '<1 min' : '${m.round()} min';
}

Future<Uint8List> buildReport({
  required ChildProfile child,
  required List<SensorySession> sessions,
  int days = 30,
  DateTime? now,
  pw.Font? regular,
  pw.Font? bold,
}) async {
  regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Andika-Regular.ttf'));
  bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Andika-Bold.ttf'));
  final st = computeStats(sessions, days: days, now: now);
  final week = computeStats(sessions, days: 7, now: now);
  const ink = PdfColor.fromInt(0xFF2B2D3A);
  const accent = PdfColor.fromInt(0xFF6F5FD0);
  const soft = PdfColor.fromInt(0xFFEEEAFB);

  final doc = pw.Document(
    title: 'SafeScape usage summary - ${child.alias}',
    author: 'Sensory SafeScape',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  pw.Widget h(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
  );

  pw.Widget tile(String label, String value) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: soft, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: ink)),
        ],
      ),
    ),
  );

  pw.Widget table(List<String> head, List<List<String>> rows) => rows.isEmpty
      ? pw.Text('No activity recorded in this period.', style: const pw.TextStyle(fontSize: 10))
      : pw.TableHelper.fromTextArray(
          headers: head,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink),
          cellStyle: const pw.TextStyle(fontSize: 10, color: ink),
          headerDecoration: const pw.BoxDecoration(color: soft),
          border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFD6D2E8), width: 0.5),
          cellAlignment: pw.Alignment.centerLeft,
        );

  final maxDay = week.daily.fold<double>(1, (m, d) => d.minutes > m ? d.minutes : m);
  final rate = st.stepCompletionRate;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (ctx) => pw.Text(
        'Sensory SafeScape - usage summary, not a clinical assessment. Page ${ctx.pageNumber} of ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      build: (ctx) => [
        pw.Text('Sensory SafeScape', style: pw.TextStyle(fontSize: 11, color: accent)),
        pw.Text('Usage summary for ${child.alias}',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.Text(
          'Age group ${child.ageGroup} - ${_d(st.from)} to ${_d(st.to)} ($days days) - generated ${_d(st.to)}',
          style: const pw.TextStyle(fontSize: 10, color: ink),
        ),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          tile('Self-regulation time\n(Flow Canvas + Sounds)', _mins(st.calmSeconds)),
          tile('Calming sessions', '${st.calmSessions}'),
          tile('Routine steps completed', rate == null ? '-' : '${(rate * 100).round()}%'),
          tile('Routines finished / started', '${st.routinesFinished} / ${st.routineRuns}'),
        ]),
        h('Last 7 days: calm minutes per day'),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final d in week.daily)
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Text(d.minutes.round().toString(), style: const pw.TextStyle(fontSize: 8)),
                  pw.Container(
                    height: 2 + 70 * d.minutes / maxDay,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 6),
                    decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(3)),
                  ),
                  pw.Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.day.weekday - 1],
                      style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
          ],
        ),
        h('Top calming modes'),
        table(['Mode', 'Sessions', 'Total time'], [
          for (final m in st.topModes.take(8)) [m.label, '${m.count}', _mins(m.seconds)],
        ]),
        h('Sensory preferences (average undisturbed session)'),
        table(['Palette / sound', 'Sessions', 'Average length'], [
          for (final p in st.palettes) ['Canvas: ${p.label}', '${p.count}', '${p.avgMinutes.toStringAsFixed(1)} min'],
          for (final s in st.sounds) ['Sound: ${s.label}', '${s.count}', '${s.avgMinutes.toStringAsFixed(1)} min'],
        ]),
        if (st.touchRhythms.isNotEmpty) ...[
          h('Touch rhythm on the Flow Canvas'),
          pw.Text(
            st.touchRhythms.entries.map((e) => '${rhythmNames[e.key] ?? e.key}: ${e.value} sessions').join('   '),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
        h('Visual routines'),
        table(['Routine', 'Runs', 'Finished', 'Steps done'], [
          for (final r in st.routines) [r.title, '${r.runs}', '${r.finished}', '${r.stepsDone} of ${r.stepsTotal}'],
        ]),
        h('Current sensory settings'),
        pw.Text(
          [
            'Low motion: ${child.sensory.lowMotion ? 'on' : 'off'}',
            'Soft lighting: ${child.sensory.softLighting ? 'on' : 'off'}',
            'Audio cut-off: ${child.sensory.effectiveCutoffHz} Hz',
            'Motion speed: ${(child.sensory.motionSpeed * 100).round()}%',
            'Particle density: ${(child.sensory.particleDensity * 100).round()}%',
            'Favourite palette: ${paletteNames[child.sensory.palette]}',
          ].join('   '),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Times are recorded while each activity is open on screen. SafeScape records durations and choices only - '
          'no audio, video, photos or location. This summary supports conversation with a therapist; it is not a '
          'diagnosis or clinical assessment.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ),
  );
  return doc.save();
}
