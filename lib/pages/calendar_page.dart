import 'package:flutter/material.dart';
import '../repositories/workout_repository.dart';
import '../repositories/workout_plan_repository.dart';
import '../repositories/firestore_workout_plan_repository.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import 'plan_workout_page.dart';

/// Calendar page showing a monthly view with workout indicators.
///
/// Features:
/// - Weekly streak counter
/// - Monthly calendar grid with swipe navigation
/// - Color-coded dots on workout days (intensity-based)
/// - Today highlighted
/// - Tap workout day → summary bottom sheet
/// - Tap rest day → "Rest day" with days since last workout
/// - Weekly comparison strip
/// - Plan Workout button
class CalendarPage extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final String userId;
  final WorkoutPlanRepository? planRepository;

  const CalendarPage({
    super.key,
    required this.workoutRepository,
    required this.userId,
    this.planRepository,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  final DateTime _today = DateTime.now();
  List<Workout> _allWorkouts = [];
  bool _isLoading = true;

  /// Date keys (YYYYMMDD) with saved plans.
  final Set<String> _plannedDateKeys = {};
  final Map<String, WorkoutPlan> _planCache = {};

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_today.year, _today.month, 1);
    _loadWorkouts();
    _loadPlans();
  }

  Future<void> _loadWorkouts() async {
    final workouts =
        await widget.workoutRepository.getWorkoutsByUserId(widget.userId);
    setState(() {
      _allWorkouts = workouts;
      _isLoading = false;
    });
  }

  Future<void> _loadPlans() async {
    final repo = widget.planRepository ?? FirestoreWorkoutPlanRepository();
    final plans = await repo.getAllPlans(widget.userId);
    if (!mounted) return;
    final keys = <String>{};
    final cache = <String, WorkoutPlan>{};
    for (final p in plans) {
      final key = '${p.date.year}${p.date.month.toString().padLeft(2,'0')}${p.date.day.toString().padLeft(2,'0')}';
      keys.add(key);
      cache[key] = p;
    }
    setState(() {
      _plannedDateKeys.clear();
      _plannedDateKeys.addAll(keys);
      _planCache
        ..clear()
        ..addAll(cache);
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';

  /// Get workouts for a specific date.
  List<Workout> _workoutsOnDate(DateTime date) {
    return _allWorkouts.where((w) =>
      w.date.year == date.year &&
      w.date.month == date.month &&
      w.date.day == date.day
    ).toList();
  }

  /// Count consecutive weeks with at least one workout (weekly streak).
  int _weeklyStreak() {
    if (_allWorkouts.isEmpty) return 0;

    // Start from the current week and go backwards
    DateTime weekStart = _today.subtract(Duration(days: _today.weekday - 1));
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    int streak = 0;

    // Check if current week has a workout (if not, start from last week)
    bool currentWeekHasWorkout = _allWorkouts.any((w) =>
      w.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
      w.date.isBefore(weekStart.add(const Duration(days: 7)))
    );

    if (!currentWeekHasWorkout) {
      // Start checking from last week
      weekStart = weekStart.subtract(const Duration(days: 7));
    }

    // Count consecutive weeks going backwards
    for (int i = 0; i < 52; i++) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final hasWorkout = _allWorkouts.any((w) =>
        w.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        w.date.isBefore(weekEnd)
      );

      if (hasWorkout) {
        streak++;
        weekStart = weekStart.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Count workouts this week vs last week.
  Map<String, int> _weeklyComparison() {
    final weekStart = _today.subtract(Duration(days: _today.weekday - 1));
    final thisWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final thisWeek = _allWorkouts.where((w) =>
      w.date.isAfter(thisWeekStart.subtract(const Duration(days: 1))) &&
      w.date.isBefore(thisWeekStart.add(const Duration(days: 7)))
    ).length;

    final lastWeek = _allWorkouts.where((w) =>
      w.date.isAfter(lastWeekStart.subtract(const Duration(days: 1))) &&
      w.date.isBefore(lastWeekStart.add(const Duration(days: 7)))
    ).length;

    return {'thisWeek': thisWeek, 'lastWeek': lastWeek};
  }

  /// Get workout intensity (0.0 to 1.0) based on set count and duration.
  /// Used for color-coding the dots.
  double _workoutIntensity(List<Workout> workouts) {
    if (workouts.isEmpty) return 0;
    // Combine metrics: more sets and longer duration = higher intensity
    double totalSets = 0;
    double totalDuration = 0;
    for (final w in workouts) {
      totalSets += w.sets.length;
      totalDuration += w.duration;
    }
    // Normalize: assume max ~10 sets and ~90 min (5400s) as "max intensity"
    final setsScore = (totalSets / 10).clamp(0.0, 1.0);
    final durationScore = (totalDuration / 5400).clamp(0.0, 1.0);
    return ((setsScore + durationScore) / 2).clamp(0.0, 1.0);
  }

  void _navigateMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + delta,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final streak = _weeklyStreak();
    final comparison = _weeklyComparison();
    final monthWorkouts = _allWorkouts.where((w) =>
      w.date.year == _currentMonth.year &&
      w.date.month == _currentMonth.month
    ).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Big Date Header ───────────────────────────────
                _buildDateHeader(streak, monthWorkouts),

                const SizedBox(height: 16),

                // ── Calendar Grid ────────────────────────────────
                _buildCalendar(),

                const SizedBox(height: 16),

                // ── Weekly Comparison Strip ──────────────────────
                _buildWeeklyStrip(comparison),

                const SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildDateHeader(int streak, int monthWorkouts) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big month name
        Text(
          months[_today.month - 1],
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '${_dayName(_today.weekday)}, ${_today.day}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 14),

        // Stats row: streak + month count + plan button
        Row(
          children: [
            // Weekly streak
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: streak > 0
                    ? Colors.orange.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    '🔥',
                    style: TextStyle(fontSize: streak > 0 ? 16 : 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    streak > 0
                        ? '$streak-week streak'
                        : 'No streak',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: streak > 0
                          ? Colors.orange.shade800
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Workouts this month
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$monthWorkouts this month',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            const Spacer(),
            // Small plan workout button (for today)
            GestureDetector(
              onTap: () async {
                final workouts = await widget.workoutRepository.getWorkoutsByUserId(widget.userId);
                if (!mounted) return;
                final repo = widget.planRepository ?? FirestoreWorkoutPlanRepository();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PlanWorkoutPage(
                    planRepository: repo,
                    userId: widget.userId,
                    date: DateTime.now(),
                    pastWorkouts: workouts,
                  ),
                )).then((_) => _loadPlans());
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Calendar Grid ───────────────────────────────────────────────────

  Widget _buildCalendar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month navigation
          _buildMonthNav(),
          const SizedBox(height: 12),
          // Day headers
          _buildDayHeaders(),
          const SizedBox(height: 8),
          // Day cells
          _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildMonthNav() {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _navigateMonth(-1),
          icon: Icon(Icons.chevron_left, color: Colors.grey.shade700),
        ),
        Text(
          '${months[_currentMonth.month - 1]} ${_currentMonth.year}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        IconButton(
          onPressed: () => _navigateMonth(1),
          icon: Icon(Icons.chevron_right, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildDayHeaders() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: days.map((d) => Expanded(
        child: Center(
          child: Text(
            d,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildDayGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    // Monday = 1, we want 0-indexed offset
    final startWeekday = (firstDay.weekday - 1) % 7;

    final cells = <Widget>[];

    // Empty cells before the first day
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final workouts = _workoutsOnDate(date);
      final isToday = date.year == _today.year &&
          date.month == _today.month &&
          date.day == _today.day;
      final isFuture = date.isAfter(_today);

      cells.add(
        GestureDetector(
          onTap: isFuture
              ? () => _showPlanWorkout(date)
              : () => _onDayTapped(date, workouts),
          child: _DayCell(
            day: day,
            isToday: isToday,
            isFuture: isFuture,
            hasWorkout: workouts.isNotEmpty,
            hasPlan: _plannedDateKeys.contains(_dateKey(date)),
            intensity: _workoutIntensity(workouts),
          ),
        ),
      );
    }

    // Build rows of 7
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      final rowCells = <Widget>[];
      for (int j = i; j < i + 7 && j < cells.length; j++) {
        rowCells.add(Expanded(child: cells[j]));
      }
      // Pad remaining cells in the last row
      while (rowCells.length < 7) {
        rowCells.add(const Expanded(child: SizedBox()));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: rowCells),
        ),
      );
    }

    return Column(children: rows);
  }

  // ── Day Tap Handler ─────────────────────────────────────────────────

  void _onDayTapped(DateTime date, List<Workout> workouts) {
    if (workouts.isNotEmpty) {
      _showWorkoutSummary(date, workouts);
    } else {
      _showRestDay(date);
    }
  }

  /// Show plan workout sheet when tapping a future date.
  void _showPlanWorkout(DateTime date) {
    final key = _dateKey(date);
    final existingPlan = _planCache[key];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHandle(),
            const SizedBox(height: 16),
            Icon(Icons.event, size: 40, color: Colors.blue.shade300),
            const SizedBox(height: 12),
            Text(
              '${_dayName(date.weekday)}, ${_monthAbbrev(date.month)} ${date.day}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              existingPlan != null
                  ? '${existingPlan.movements.length} exercise${existingPlan.movements.length != 1 ? 's' : ''} planned'
                  : 'No workout planned yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            // Show planned movements if a plan exists
            if (existingPlan != null && existingPlan.movements.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...existingPlan.movements.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 8, height: 8,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: BoxDecoration(color: Colors.blue.shade400, shape: BoxShape.circle)),
                    Expanded(child: Text(m.exercise,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    Text('${m.targetSets}×${m.targetReps}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final workouts = await widget.workoutRepository.getWorkoutsByUserId(widget.userId);
                  if (!mounted) return;
                  final repo = widget.planRepository ?? FirestoreWorkoutPlanRepository();
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PlanWorkoutPage(
                      planRepository: repo,
                      userId: widget.userId,
                      date: date,
                      pastWorkouts: workouts,
                      initialPlan: existingPlan,
                    ),
                  )).then((_) => _loadPlans());
                },
                icon: Icon(existingPlan != null ? Icons.edit : Icons.add, size: 20),
                label: Text(
                  existingPlan != null ? 'Edit Plan' : 'Plan Workout',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Show workout summary for a specific day.
  void _showWorkoutSummary(DateTime date, List<Workout> workouts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dayName(date.weekday)}, ${_monthAbbrev(date.month)} ${date.day}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${workouts.length} workout${workouts.length > 1 ? 's' : ''}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.fitness_center,
                          color: Colors.green.shade700, size: 22),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    final w = workouts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workout at ${w.formattedTime}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _metricRow('Duration', '${(w.duration / 60).toStringAsFixed(1)} min'),
                          _metricRow('Sets', '${w.sets.length}'),
                          _metricRow('Mean MCV', '${w.meanConcentricVelocity.toStringAsFixed(2)} m/s'),
                          _metricRow('Peak MCV', '${w.peakConcentricVelocity.toStringAsFixed(2)} m/s'),
                          _metricRow('TUT', '${w.timeUnderTension.toStringAsFixed(1)}s'),
                          if (w.notes != null && w.notes!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              w.notes!,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if (w.sets.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Sets',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...w.sets.asMap().entries.map((entry) {
                              final i = entry.key;
                              final s = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        'Set ${i + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${s.totalReps} reps  •  MCV: ${s.meanMCV.toStringAsFixed(2)}  •  '
                                        'Fatigue: ${s.fatigueIndex.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show rest day info when tapping a day with no workouts.
  void _showRestDay(DateTime date) {
    // Find the most recent workout before this date
    final prior = _allWorkouts
        .where((w) => w.date.isBefore(date.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final daysSince = prior.isNotEmpty
        ? date.difference(DateTime(
            prior.first.date.year, prior.first.date.month, prior.first.date.day))
            .inDays
        : -1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHandle(),
            const SizedBox(height: 16),
            Icon(Icons.bedtime_outlined, size: 40, color: Colors.blue.shade200),
            const SizedBox(height: 12),
            Text(
              '${_dayName(date.weekday)}, ${_monthAbbrev(date.month)} ${date.day}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rest Day',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              daysSince >= 0
                  ? '$daysSince day${daysSince == 1 ? '' : 's'} since last workout'
                  : 'No workouts recorded yet',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Weekly Comparison Strip ─────────────────────────────────────────

  Widget _buildWeeklyStrip(Map<String, int> comparison) {
    final thisWeek = comparison['thisWeek'] ?? 0;
    final lastWeek = comparison['lastWeek'] ?? 0;
    final diff = thisWeek - lastWeek;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // This week
          Expanded(
            child: Column(
              children: [
                Text(
                  '$thisWeek',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'This week',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // Comparison indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: diff > 0
                  ? Colors.green.shade50
                  : diff < 0
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              diff > 0
                  ? '↑ +$diff'
                  : diff < 0
                      ? '↓ $diff'
                      : '= same',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: diff > 0
                    ? Colors.green.shade700
                    : diff < 0
                        ? Colors.red.shade700
                        : Colors.grey.shade600,
              ),
            ),
          ),
          // Last week
          Expanded(
            child: Column(
              children: [
                Text(
                  '$lastWeek',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Last week',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Widget _buildSheetHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _dayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  String _monthAbbrev(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

// ── Day Cell Widget ─────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isFuture;
  final bool hasWorkout;
  final bool hasPlan;
  final double intensity; // 0.0 to 1.0

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.hasWorkout,
    required this.hasPlan,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    // Intensity maps to color: light green (easy) → dark green (heavy)
    final dotColor = Color.lerp(
      Colors.green.shade200,
      Colors.green.shade800,
      intensity,
    )!;

    return Container(
      height: 44,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isToday
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday
                  ? Theme.of(context).colorScheme.onPrimary
                  : isFuture
                      ? Colors.grey.shade300
                      : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Green workout dot
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasWorkout
                      ? (isToday ? Colors.white : dotColor)
                      : Colors.transparent,
                ),
              ),
              // Blue plan pencil dot (only when no workout yet or future)
              if (hasPlan) ...[
                const SizedBox(width: 3),
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday ? Colors.blue.shade200 : Colors.blue.shade400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
