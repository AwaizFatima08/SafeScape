// "Calm & Focus Horizon" (PDD Step 5) and the one-tap OT PDF export.

import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../services/report.dart';
import '../../services/stats.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});
  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  int _days = 7;
  bool _exporting = false;

  Future<void> _export() async {
    final store = ref.read(storeProvider);
    final child = store.activeChild!;
    setState(() => _exporting = true);
    try {
      final bytes = await buildReport(child: child, sessions: store.sessionsFor(child.id), days: 30);
      final dir = await getTemporaryDirectory();
      final safe = child.alias.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final d = DateTime.now();
      final f = File(
        '${dir.path}/SafeScape_${safe}_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.pdf',
      );
      await f.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(f.path, mimeType: 'application/pdf')],
          subject: 'SafeScape usage summary - ${child.alias}',
          text: 'SafeScape usage summary for ${child.alias} (last 30 days).',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not create the PDF. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final child = store.activeChild!;
    final st = computeStats(store.sessionsFor(child.id), days: _days);
    final rate = st.stepCompletionRate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            const SectionTitle('Calm & Focus Horizon'),
            SegmentedButton<int>(
              key: const ValueKey('range'),
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                key: const ValueKey('stat_calm'),
                value: '${st.calmMinutes} min',
                label: 'Total self-regulation time',
                color: SC.lavender,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                key: const ValueKey('stat_routines'),
                value: rate == null ? '–' : '${(rate * 100).round()}%',
                label: 'Routine steps completed',
                color: SC.mint,
              ),
            ),
          ],
        ),
        if (st.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing recorded yet in this period. Time spent on the Calming Canvas and Soothing Sounds, '
              'and routine steps, will appear here.',
              style: TextStyle(color: SC.textDim, fontSize: 16),
            ),
          ),
        const SectionTitle('Calm minutes per day'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            child: SizedBox(height: 200, child: _DailyChart(stats: st)),
          ),
        ),
        const SectionTitle('Top calming modes'),
        Card(
          child: Column(
            children: [
              if (st.topModes.isEmpty)
                const ListTile(
                  title: Text('No sessions yet', style: TextStyle(color: SC.textDim)),
                ),
              for (final (i, m) in st.topModes.take(5).indexed)
                ListTile(
                  leading: CircleAvatar(backgroundColor: SC.slate3, child: Text('${i + 1}')),
                  title: Text(m.label),
                  trailing: Text(
                    '${(m.seconds / 60).round()} min · ${m.count}×',
                    style: const TextStyle(color: SC.textDim),
                  ),
                ),
            ],
          ),
        ),
        if (st.palettes.isNotEmpty || st.sounds.isNotEmpty) ...[
          const SectionTitle('Sensory preferences'),
          const Text(
            'Average length of an undisturbed session. Longer usually means more soothing.',
            style: TextStyle(color: SC.textDim),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final p in st.palettes)
                  ListTile(
                    leading: const Icon(Icons.palette_rounded, color: SC.lavender),
                    title: Text('Canvas: ${p.label}'),
                    trailing: Text('${p.avgMinutes.toStringAsFixed(1)} min avg'),
                  ),
                for (final s in st.sounds)
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded, color: SC.blue),
                    title: Text('Sound: ${s.label}'),
                    trailing: Text('${s.avgMinutes.toStringAsFixed(1)} min avg'),
                  ),
                if (st.touchRhythms.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.touch_app_rounded, color: SC.sand),
                    title: const Text('Touch rhythm on the canvas'),
                    subtitle: Text(st.touchRhythms.entries.map((e) => '${rhythmNames[e.key]}: ${e.value}').join(' · ')),
                  ),
              ],
            ),
          ),
        ],
        if (st.routines.isNotEmpty) ...[
          const SectionTitle('Routines'),
          Card(
            child: Column(
              children: [
                for (final r in st.routines)
                  ListTile(
                    title: Text(r.title),
                    subtitle: Text('${r.stepsDone} of ${r.stepsTotal} steps done'),
                    trailing: Text('${r.finished}/${r.runs} finished'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 60,
          child: FilledButton.icon(
            key: const ValueKey('export_pdf'),
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3))
                : const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export summary for therapist (PDF)'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The PDF covers the last 30 days and opens your share menu (email, WhatsApp, Drive…). '
          'It is a usage summary, not a clinical assessment.',
          style: TextStyle(color: SC.textDim),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatTile({super.key, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        Text(label, style: const TextStyle(color: SC.text)),
      ],
    ),
  );
}

class _DailyChart extends StatelessWidget {
  final ChildStats stats;
  const _DailyChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final days = stats.daily;
    final maxY = days.fold<double>(5, (m, d) => d.minutes > m ? d.minutes : m) * 1.2;
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final every = days.length > 10 ? 5 : 1;
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: SC.slate3, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => SC.slate3,
            getTooltipItem: (g, _, r, _) => BarTooltipItem('${r.toY.round()} min', const TextStyle(color: SC.text)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text('${v.round()}', style: const TextStyle(color: SC.textDim, fontSize: 12)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= days.length || (days.length - 1 - i) % every != 0) return const SizedBox.shrink();
                final d = days[i].day;
                return Text(
                  days.length > 10 ? '${d.day}/${d.month}' : names[d.weekday - 1],
                  style: const TextStyle(color: SC.textDim, fontSize: 12),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].minutes,
                  width: days.length > 10 ? 6 : 22,
                  color: SC.lavender,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
