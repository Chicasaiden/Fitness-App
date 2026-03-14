import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/workout.dart';
import '../models/set_summary.dart';
import '../models/rep_record.dart';
import 'metrics_calculator.dart';

/// Generates a professional PDF workout report with velocity charts.
class PdfExportService {
  PdfExportService._();

  /// Generate a full workout report PDF.
  static pw.Document generateReport(List<Workout> workouts) {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(),
      title: 'VBT Workout Report',
      author: 'Fitness App',
    );

    // Sort newest first
    final sorted = List<Workout>.from(workouts)
      ..sort((a, b) => b.date.compareTo(a.date));

    // ── COVER / SUMMARY PAGE ────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (_) => _buildPageHeader(),
        footer: (ctx) => _buildPageFooter(ctx),
        build: (ctx) => [
          _buildCoverSection(sorted),
          pw.SizedBox(height: 20),
          _buildOverallStatsTable(sorted),
        ],
      ),
    );

    // ── PER-WORKOUT PAGES ───────────────────────────────────────────
    for (final workout in sorted) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(40),
          header: (_) => _buildPageHeader(),
          footer: (ctx) => _buildPageFooter(ctx),
          build: (ctx) => _buildWorkoutPage(workout),
        ),
      );
    }

    return pdf;
  }

  // ── PAGE HEADER / FOOTER ──────────────────────────────────────────

  static pw.Widget _buildPageHeader() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('VBT Workout Report',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
          pw.Text('Velocity Based Training',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated ${_formatDate(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  // ── COVER SECTION ─────────────────────────────────────────────────

  static pw.Widget _buildCoverSection(List<Workout> workouts) {
    final totalWorkouts = workouts.length;
    final avgMCV = workouts.isNotEmpty
        ? workouts.fold(0.0, (sum, w) => sum + w.meanConcentricVelocity) / workouts.length
        : 0.0;
    final peakMCV = workouts.isNotEmpty
        ? workouts.fold(0.0, (best, w) => w.peakConcentricVelocity > best ? w.peakConcentricVelocity : best)
        : 0.0;
    final totalSets = workouts.fold(0, (sum, w) => sum + w.sets.length);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Training Summary',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          workouts.isNotEmpty
              ? '${_formatDate(workouts.last.date)} — ${_formatDate(workouts.first.date)}'
              : 'No workouts recorded',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            _summaryStatBox('Total Workouts', '$totalWorkouts'),
            pw.SizedBox(width: 12),
            _summaryStatBox('Total Sets', '$totalSets'),
            pw.SizedBox(width: 12),
            _summaryStatBox('Avg MCV', '${avgMCV.toStringAsFixed(3)} m/s'),
            pw.SizedBox(width: 12),
            _summaryStatBox('Best PCV', '${peakMCV.toStringAsFixed(3)} m/s'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summaryStatBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            pw.Text(value,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  // ── OVERALL STATS TABLE ───────────────────────────────────────────

  static pw.Widget _buildOverallStatsTable(List<Workout> workouts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Workout History',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1A2E)),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          headers: ['Date', 'Duration', 'Exercise(s)', 'Sets', 'Mean MCV', 'Peak MCV', 'Vloss %'],
          data: workouts.map((w) {
            final exercises = w.sets.map((s) => s.exercise).toSet().join(', ');
            final avgVloss = w.sets.isNotEmpty
                ? w.sets.fold(0.0, (sum, s) => sum + s.velocityLossPercent) / w.sets.length
                : 0.0;
            return [
              _formatDate(w.date),
              _formatDuration(w.duration),
              exercises.isEmpty ? '—' : exercises,
              '${w.sets.length}',
              w.meanConcentricVelocity.toStringAsFixed(3),
              w.peakConcentricVelocity.toStringAsFixed(3),
              '${avgVloss.toStringAsFixed(1)}%',
            ];
          }).toList(),
        ),
      ],
    );
  }

  // ── PER-WORKOUT PAGE ──────────────────────────────────────────────

  static List<pw.Widget> _buildWorkoutPage(Workout workout) {
    final exercises = workout.sets.map((s) => s.exercise).toSet().join(', ');
    final widgets = <pw.Widget>[];

    // Workout header
    widgets.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Workout — ${_formatDate(workout.date)}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${_formatDuration(workout.duration)} • $exercises',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 12),
          // Session summary row
          pw.Row(
            children: [
              _summaryStatBox('Mean MCV', '${workout.meanConcentricVelocity.toStringAsFixed(3)} m/s'),
              pw.SizedBox(width: 8),
              _summaryStatBox('Peak MCV', '${workout.peakConcentricVelocity.toStringAsFixed(3)} m/s'),
              pw.SizedBox(width: 8),
              _summaryStatBox('Total TUT', '${workout.timeUnderTension.toStringAsFixed(1)} s'),
              pw.SizedBox(width: 8),
              _summaryStatBox('Avg ROM', '${(workout.rangeOfMotion * 100).toStringAsFixed(1)} cm'),
            ],
          ),
        ],
      ),
    );

    // Per-set sections
    for (int i = 0; i < workout.sets.length; i++) {
      final set = workout.sets[i];
      widgets.add(pw.SizedBox(height: 20));
      widgets.add(_buildSetSection(i + 1, set));
    }

    return widgets;
  }

  // ── SET SECTION ───────────────────────────────────────────────────

  static pw.Widget _buildSetSection(int setNumber, SetSummary set) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Set header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Set $setNumber — ${set.exercise}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                '${set.totalReps} reps${set.loadLbs != null ? " • ${set.loadLbs!.toStringAsFixed(1)} lbs" : ""}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Velocity bar chart
          pw.Text('Rep Velocities (MCV)',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _buildVelocityBarChart(set.reps),
          pw.SizedBox(height: 10),

          // Velocity curve (line chart)
          pw.Text('Velocity Curve',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _buildVelocityCurve(set.reps),
          pw.SizedBox(height: 10),

          // Stats row
          pw.Row(
            children: [
              _miniStat('Best MCV', '${set.bestMCV.toStringAsFixed(3)} m/s'),
              _miniStat('Worst MCV', '${set.worstMCV.toStringAsFixed(3)} m/s'),
              _miniStat('V-Loss', '${set.velocityLossPercent.toStringAsFixed(1)}%'),
              _miniStat('Fatigue', '${set.fatigueIndex.toStringAsFixed(0)}/100'),
              if (set.estimated1RMLbs != null)
                _miniStat('Est 1RM', '${set.estimated1RMLbs!.toStringAsFixed(1)} lbs'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniStat(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // ── VELOCITY BAR CHART ────────────────────────────────────────────

  static pw.Widget _buildVelocityBarChart(List<RepRecord> reps) {
    if (reps.isEmpty) {
      return pw.Text('No rep data', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500));
    }

    final maxMCV = reps.map((r) => r.meanConcentricVelocity).reduce(max);
    final chartHeight = 60.0;

    return pw.SizedBox(
      height: chartHeight + 16,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: reps.map((rep) {
          final ratio = maxMCV > 0 ? rep.meanConcentricVelocity / maxMCV : 0.0;
          final barHeight = chartHeight * ratio;
          final zone = MetricsCalculator.velocityZone(rep.meanConcentricVelocity);
          final color = _zoneColor(zone);

          return pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 1),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(rep.meanConcentricVelocity.toStringAsFixed(2),
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    height: barHeight.clamp(2.0, chartHeight),
                    decoration: pw.BoxDecoration(
                      color: color,
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2)),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('R${rep.repNumber}',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── VELOCITY CURVE (LINE CHART) ───────────────────────────────────

  static pw.Widget _buildVelocityCurve(List<RepRecord> reps) {
    if (reps.length < 2) {
      return pw.Text('Not enough reps for curve', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500));
    }

    return pw.SizedBox(
      height: 80,
      child: pw.CustomPaint(
        size: const PdfPoint(500, 80),
        painter: (PdfGraphics canvas, PdfPoint size) {
          final w = size.x;
          final h = size.y;
          final padding = 4.0;
          final chartW = w - padding * 2;
          final chartH = h - padding * 2;

          // Extract MCV and PCV values
          final mcvs = reps.map((r) => r.meanConcentricVelocity).toList();
          final pcvs = reps.map((r) => r.peakConcentricVelocity).toList();
          final allVals = [...mcvs, ...pcvs];
          final minV = allVals.reduce(min) * 0.9;
          final maxV = allVals.reduce(max) * 1.05;
          final range = maxV - minV;

          double xForIdx(int i) => padding + (i / (reps.length - 1)) * chartW;
          double yForVal(double v) => h - padding - ((v - minV) / range) * chartH;

          // Draw grid lines
          canvas
            ..setStrokeColor(PdfColors.grey200)
            ..setLineWidth(0.3);
          for (int i = 0; i <= 4; i++) {
            final y = padding + (i / 4) * chartH;
            canvas
              ..drawLine(padding, y, w - padding, y)
              ..strokePath();
          }

          // Draw PCV line (lighter, dashed feel)
          canvas
            ..setStrokeColor(PdfColors.blue200)
            ..setLineWidth(1.0);
          for (int i = 0; i < pcvs.length - 1; i++) {
            canvas
              ..drawLine(xForIdx(i), yForVal(pcvs[i]), xForIdx(i + 1), yForVal(pcvs[i + 1]))
              ..strokePath();
          }

          // Draw MCV line (bold primary line)
          canvas
            ..setStrokeColor(const PdfColor.fromInt(0xFF1A1A2E))
            ..setLineWidth(1.5);
          for (int i = 0; i < mcvs.length - 1; i++) {
            canvas
              ..drawLine(xForIdx(i), yForVal(mcvs[i]), xForIdx(i + 1), yForVal(mcvs[i + 1]))
              ..strokePath();
          }

          // Draw dots on MCV
          for (int i = 0; i < mcvs.length; i++) {
            final zone = MetricsCalculator.velocityZone(mcvs[i]);
            canvas
              ..setColor(_zonePdfColor(zone))
              ..drawEllipse(xForIdx(i), yForVal(mcvs[i]), 3, 3)
              ..fillPath();
          }
        },
      ),
    );
  }

  // ── ZONE COLORS ───────────────────────────────────────────────────

  static PdfColor _zoneColor(VelocityZone zone) {
    switch (zone) {
      case VelocityZone.maxStrength:
        return PdfColors.red;
      case VelocityZone.strength:
        return PdfColors.orange;
      case VelocityZone.speedStrength:
        return PdfColors.amber;
      case VelocityZone.power:
        return PdfColors.green;
      case VelocityZone.speed:
        return PdfColors.blue;
    }
  }

  static PdfColor _zonePdfColor(VelocityZone zone) => _zoneColor(zone);

  // ── HELPERS ───────────────────────────────────────────────────────

  static String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }
}
