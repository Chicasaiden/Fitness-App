import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../repositories/workout_repository.dart';

/// Page showing per-exercise progress over time.
///
/// Displays two line charts:
/// - Estimated 1RM (lbs) over sessions
/// - Mean Concentric Velocity (m/s) over sessions
///
/// User can switch exercises via a top tab/chip row.
class ProgressChartPage extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final String userId;

  const ProgressChartPage({
    super.key,
    required this.workoutRepository,
    required this.userId,
  });

  @override
  State<ProgressChartPage> createState() => _ProgressChartPageState();
}

class _ProgressChartPageState extends State<ProgressChartPage> {
  List<Workout> _workouts = [];
  bool _isLoading = true;
  String _selectedExercise = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final workouts = await widget.workoutRepository.getWorkoutsByUserId(widget.userId);
    // Sort oldest first for chart x-axis
    workouts.sort((a, b) => a.date.compareTo(b.date));
    setState(() {
      _workouts = workouts;
      _isLoading = false;
      _selectedExercise = _exercisesWithData.isNotEmpty ? _exercisesWithData.first : '';
    });
  }

  /// All unique exercises that appear in at least one set where 1RM was estimated.
  List<String> get _exercisesWithData {
    final seen = <String>{};
    final result = <String>[];
    for (final w in _workouts) {
      for (final s in w.sets) {
        final ex = s.exercise;
        if (ex.isEmpty || ex == 'Unspecified') continue;
        if (s.estimated1RMLbs == null && s.meanMCV == 0) continue;
        if (seen.add(ex)) result.add(ex);
      }
    }
    return result;
  }

  /// Data points for 1RM over time for [exercise].
  /// X = session index, Y = best 1RM that session.
  List<FlSpot> _oneRMSpots(String exercise) {
    final spots = <FlSpot>[];
    int idx = 0;
    for (final w in _workouts) {
      double? best;
      for (final s in w.sets) {
        if (s.exercise != exercise) continue;
        final rm = s.estimated1RMLbs;
        if (rm != null && (best == null || rm > best)) best = rm;
      }
      if (best != null) {
        spots.add(FlSpot(idx.toDouble(), best));
        idx++;
      }
    }
    return spots;
  }

  /// Data points for mean MCV over time for [exercise].
  List<FlSpot> _mcvSpots(String exercise) {
    final spots = <FlSpot>[];
    int idx = 0;
    for (final w in _workouts) {
      final sets = w.sets.where((s) => s.exercise == exercise && s.meanMCV > 0).toList();
      if (sets.isEmpty) continue;
      final avgMCV = sets.fold(0.0, (sum, s) => sum + s.meanMCV) / sets.length;
      spots.add(FlSpot(idx.toDouble(), avgMCV));
      idx++;
    }
    return spots;
  }

  /// Session dates for this exercise (used as x-axis labels).
  List<DateTime> _sessionDates(String exercise) {
    final dates = <DateTime>[];
    for (final w in _workouts) {
      if (w.sets.any((s) => s.exercise == exercise)) {
        dates.add(w.date);
      }
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Progress'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exercisesWithData.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No data yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Complete workouts with load entered\nto see your progress charts here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercises = _exercisesWithData;
    final rmSpots = _oneRMSpots(_selectedExercise);
    final mcvSpots = _mcvSpots(_selectedExercise);
    final dates = _sessionDates(_selectedExercise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exercise chip selector
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: exercises.map((ex) {
                final isSelected = ex == _selectedExercise;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedExercise = ex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                      ),
                      child: Text(ex, style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimary : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1RM Chart
                if (rmSpots.length >= 2) ...[
                  _chartCard(
                    title: 'Estimated 1RM',
                    subtitle: 'Best per session (lbs)',
                    spots: rmSpots,
                    dates: dates,
                    color: const Color(0xFF1565C0),
                    yLabel: 'lbs',
                    accentColor: const Color(0xFF42A5F5),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  _insufficientDataCard('Estimated 1RM', 'Need 2+ sessions with load to show 1RM trend'),
                  const SizedBox(height: 16),
                ],

                // MCV Chart
                if (mcvSpots.length >= 2) ...[
                  _chartCard(
                    title: 'Mean Concentric Velocity',
                    subtitle: 'Session average (m/s)',
                    spots: mcvSpots,
                    dates: dates,
                    color: const Color(0xFF2E7D32),
                    yLabel: 'm/s',
                    accentColor: const Color(0xFF66BB6A),
                  ),
                ] else ...[
                  _insufficientDataCard('Mean Concentric Velocity', 'Need 2+ sessions to show velocity trend'),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required List<FlSpot> spots,
    required List<DateTime> dates,
    required Color color,
    required Color accentColor,
    required String yLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final yRange = maxY - minY;
    final yPad = yRange < 1 ? 0.5 : yRange * 0.15;
    final displayMin = (minY - yPad).clamp(0, double.infinity);
    final displayMax = maxY + yPad;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
                ],
              ),
              const Spacer(),
              // Latest value badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${spots.last.y.toStringAsFixed(yLabel == 'm/s' ? 3 : 1)} $yLabel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: displayMin.toDouble(),
                maxY: displayMax.toDouble(),
                gridData: FlGridData(
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, m) => Text(
                        yLabel == 'm/s' ? v.toStringAsFixed(2) : v.toStringAsFixed(0),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: spots.length <= 6 ? 1 : (spots.length / 4).ceil().toDouble(),
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                        final d = dates[idx];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: color,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                        radius: spots.length > 12 ? 2 : 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: color,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accentColor.withValues(alpha: 0.25), accentColor.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(yLabel == 'm/s' ? 3 : 1)} $yLabel',
                        TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insufficientDataCard(String title, String reason) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.show_chart, size: 36, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(reason, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
