import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'data_dashboard.dart';
import 'view_old_workout_page.dart';
import 'plan_workout_page.dart';
import 'calendar_page.dart';
import 'news_page.dart';
import 'settings_page.dart';
import 'metrics_dashboard_page.dart';
import 'progress_chart_page.dart';
import '../services/ble_service.dart';
import '../services/set_tracker.dart';
import '../services/auth_service.dart';
import '../repositories/workout_repository.dart';
import '../repositories/firestore_workout_plan_repository.dart';
import '../ble_metrics.dart';
import '../models/workout.dart';

class HomePage extends StatefulWidget {
  final BleService bleService;
  final AuthService authService;
  final WorkoutRepository workoutRepository;
  final String connectedDeviceName;

  const HomePage({
    super.key,
    BleService? bleService,
    required this.authService,
    required this.workoutRepository,
    this.connectedDeviceName = '',
  })  : bleService = bleService ?? const _DummyBleService();

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;
  String _connectedDevice = '';
  bool _insightsExpanded = false;
  late final SetTracker _setTracker;
  late final FirestoreWorkoutPlanRepository _planRepository;

  @override
  void initState() {
    super.initState();
    _connectedDevice = widget.connectedDeviceName.isNotEmpty
        ? widget.connectedDeviceName
        : widget.bleService.connectedDeviceName;
    _setTracker = SetTracker(widget.bleService);
    _planRepository = FirestoreWorkoutPlanRepository();
  }

  void _syncConnectionStatus([String? returnedName]) {
    setState(() {
      if (returnedName != null && returnedName.isNotEmpty) {
        _connectedDevice = returnedName;
      } else {
        _connectedDevice = widget.bleService.connectedDeviceName;
      }
    });
  }

  Widget _buildHomePage() {
    final currentUser = widget.authService.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final userName = currentUser?.displayName ?? 'User';
    final userId = currentUser?.id ?? '';

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting Section
          Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $userName!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Container(
            color: isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── QUICK STATS STRIP ──────────────────────────
                FutureBuilder<List<Workout>>(
                  future: widget.workoutRepository.getWorkoutsByUserId(userId),
                  builder: (context, snapshot) {
                    final workouts = snapshot.data ?? [];
                    return _buildQuickStats(context, workouts);
                  },
                ),

                const SizedBox(height: 10),

                // ── CONNECTION SECTION ─────────────────────────
                _buildSectionBubble(
                  context: context,
                  title: 'Connection',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DataDashboard(bleService: widget.bleService),
                            ),
                          );
                          if (mounted) _syncConnectionStatus(result as String?);
                        },
                        icon: const Icon(Icons.bluetooth, size: 22),
                        label: const Text('Connect to Device'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _connectedDevice.isEmpty ? (isDark ? Colors.red.shade900.withValues(alpha: 0.2) : Colors.red.shade50) : (isDark ? Colors.green.shade900.withValues(alpha: 0.2) : Colors.green.shade50),
                          border: Border.all(
                            color: _connectedDevice.isEmpty ? (isDark ? Colors.red.shade900 : Colors.red.shade200) : (isDark ? Colors.green.shade900 : Colors.green.shade200),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: _connectedDevice.isEmpty ? Colors.red.shade400 : Colors.green.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _connectedDevice.isEmpty ? 'No Device Connected' : _connectedDevice,
                                style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── TRAINING SECTION ──────────────────────────
                _buildSectionBubble(
                  context: context,
                  title: 'Training',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MetricsDashboardPage(
                              bleService: widget.bleService,
                              setTracker: _setTracker,
                              workoutRepository: widget.workoutRepository,
                              userId: userId,
                              planRepository: _planRepository,
                            ),
                          ));
                        },
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: const Text('Start Training'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ViewOldWorkoutPage(
                                    workoutRepository: widget.workoutRepository,
                                    userId: userId,
                                  ),
                                ));
                              },
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text('View Old'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final workouts = await widget.workoutRepository.getWorkoutsByUserId(userId);
                                if (!mounted) return;
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PlanWorkoutPage(
                                    planRepository: _planRepository,
                                    userId: userId,
                                    date: DateTime.now(),
                                    pastWorkouts: workouts,
                                  ),
                                ));
                              },
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('Plan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ProgressChartPage(
                                    workoutRepository: widget.workoutRepository,
                                    userId: userId,
                                  ),
                                ));
                              },
                              icon: const Icon(Icons.show_chart, size: 18),
                              label: const Text('Progress'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── INSIGHTS SECTION ──────────────────────────
                FutureBuilder<List<Workout>>(
                  future: widget.workoutRepository.getWorkoutsByUserId(userId),
                  builder: (context, snapshot) {
                    final workouts = snapshot.data ?? [];
                    return _buildInsightsSection(context, workouts);
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Stats Strip ─────────────────────────────────────────────

  Widget _buildQuickStats(BuildContext context, List<Workout> workouts) {
    final totalWorkouts = workouts.length;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final thisWeek = workouts.where((w) =>
      w.date.isAfter(thisWeekStart.subtract(const Duration(days: 1)))
    ).length;

    double avgMCV = 0;
    if (workouts.isNotEmpty) {
      final totalMCV = workouts.fold(0.0, (sum, w) => sum + w.meanConcentricVelocity);
      avgMCV = totalMCV / workouts.length;
    }

    return Row(
      children: [
        _statCard(context, 'Total', '$totalWorkouts', Icons.fitness_center),
        const SizedBox(width: 10),
        _statCard(context, 'This Week', '$thisWeek', Icons.calendar_today),
        const SizedBox(width: 10),
        _statCard(context, 'Avg MCV', avgMCV > 0 ? avgMCV.toStringAsFixed(2) : '--', Icons.speed),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Insights Section ──────────────────────────────────────────────

  Widget _buildInsightsSection(BuildContext context, List<Workout> workouts) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (workouts.isEmpty) {
      return _buildSectionBubble(
        context: context,
        title: '💡 Insights',
        child: Text(
          'Complete your first workout to see personalized insights!',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    final insights = _generateInsights(workouts);
    if (insights.isEmpty) {
      return const SizedBox.shrink(); // No insights generated yet
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collapsible Header
          InkWell(
            onTap: () {
              setState(() {
                _insightsExpanded = !_insightsExpanded;
              });
            },
            borderRadius: _insightsExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '💡 Insights (${insights.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Icon(
                    _insightsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          // Content Box
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 4),
              child: _insightsExpanded
                  ? Column(
                      children: insights.map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildInsightCard(context, i),
                      )).toList(),
                    )
                  : _buildInsightCard(context, insights.first), // Compact mode just shows the top insight
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, _Insight insight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: insight.color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: insight.color.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.message,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Insight> _generateInsights(List<Workout> workouts) {
    final insights = <_Insight>[];
    final now = DateTime.now();
    final sorted = List<Workout>.from(workouts)..sort((a, b) => b.date.compareTo(a.date));

    // 1. Velocity Trend — compare last 2 weeks vs prior 2 weeks
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final fourWeeksAgo = now.subtract(const Duration(days: 28));
    final recentWorkouts = sorted.where((w) => w.date.isAfter(twoWeeksAgo)).toList();
    final olderWorkouts = sorted.where((w) => w.date.isAfter(fourWeeksAgo) && w.date.isBefore(twoWeeksAgo)).toList();

    if (recentWorkouts.isNotEmpty && olderWorkouts.isNotEmpty) {
      final recentAvg = recentWorkouts.fold(0.0, (sum, w) => sum + w.meanConcentricVelocity) / recentWorkouts.length;
      final olderAvg = olderWorkouts.fold(0.0, (sum, w) => sum + w.meanConcentricVelocity) / olderWorkouts.length;
      if (olderAvg > 0) {
        final change = (recentAvg - olderAvg) / olderAvg * 100;
        insights.add(change > 0
          ? _Insight(emoji: '📈', title: 'Velocity Trending Up', message: 'Average MCV up ${change.toStringAsFixed(1)}% vs 2 weeks ago. Keep pushing!', color: Colors.green)
          : _Insight(emoji: '📉', title: 'Velocity Dip', message: 'Average MCV down ${change.abs().toStringAsFixed(1)}% vs 2 weeks ago. Consider deloading.', color: Colors.orange)
        );
      }
    }

    // 2. Weekly streak
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    int streak = 0;
    for (int i = 0; i < 52; i++) {
      final wEnd = weekStart.add(const Duration(days: 7));
      if (workouts.any((w) => w.date.isAfter(weekStart.subtract(const Duration(days: 1))) && w.date.isBefore(wEnd))) {
        streak++;
        weekStart = weekStart.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }
    if (streak >= 2) {
      insights.add(_Insight(emoji: '🔥', title: '$streak-Week Streak!', message: "You've trained every week for $streak weeks straight!", color: Colors.orange));
    }

    // 3. Fatigue pattern
    final multiSet = recentWorkouts.where((w) => w.sets.length >= 3).toList();
    if (multiSet.isNotEmpty) {
      double totalDrop = 0;
      int count = 0;
      for (final w in multiSet) {
        if (w.sets.first.meanMCV > 0) {
          totalDrop += (w.sets.first.meanMCV - w.sets.last.meanMCV) / w.sets.first.meanMCV * 100;
          count++;
        }
      }
      if (count > 0) {
        final avgDrop = totalDrop / count;
        insights.add(avgDrop > 15
          ? _Insight(emoji: '⚡', title: 'Fatigue Alert', message: 'Velocity drops ${avgDrop.toStringAsFixed(0)}% by your last set. Consider fewer sets or longer rest.', color: Colors.red)
          : _Insight(emoji: '💪', title: 'Strong Endurance', message: 'Only ${avgDrop.toStringAsFixed(0)}% velocity loss across sets. Great stamina!', color: Colors.blue)
        );
      }
    }

    // 4. Days since last workout
    if (sorted.isNotEmpty) {
      final daysSince = now.difference(sorted.first.date).inDays;
      if (daysSince >= 5) {
        insights.add(_Insight(emoji: '📅', title: 'Time to Train', message: "It's been $daysSince days since your last session. Ready to get back?", color: Colors.purple));
      }
    }

    // 5. Progressive overload suggestion — best 1RM across all sets, suggest +2.5 lbs
    if (sorted.isNotEmpty) {
      final exerciseBest = <String, double>{};
      for (final w in sorted.take(10)) {
        for (final s in w.sets) {
          final rm = s.estimated1RMLbs;
          if (rm != null && rm > 0) {
            final key = s.exercise;
            if (!exerciseBest.containsKey(key) || rm > exerciseBest[key]!) {
              exerciseBest[key] = rm;
            }
          }
        }
      }
      if (exerciseBest.isNotEmpty) {
        final topEntry = exerciseBest.entries.reduce((a, b) => a.value > b.value ? a : b);
        final suggested = ((topEntry.value * 0.825 / 2.5).round() * 2.5) + 2.5;
        insights.add(_Insight(
          emoji: '🎯',
          title: 'Try Progressive Overload',
          message: 'Based on your ${topEntry.key} 1RM, try ${suggested.toStringAsFixed(1)} lbs next session for a strength gains bump.',
          color: Colors.indigo,
        ));
      }
    }

    return insights.take(4).toList();
  }

  // ── Section Bubble ────────────────────────────────────────────────

  Widget _buildSectionBubble({required BuildContext context, required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHomePage(),
      CalendarPage(
        workoutRepository: widget.workoutRepository,
        userId: widget.authService.currentUser?.id ?? '',
        planRepository: _planRepository,
      ),
      const NewsPage(),
      SettingsPage(
        authService: widget.authService,
        workoutRepository: widget.workoutRepository,
        userId: widget.authService.currentUser?.id ?? '',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentPageIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() => _currentPageIndex = index);
        },
        indicatorColor: Colors.blue.shade100.withValues(alpha: 0.6),
        selectedIndex: _currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(selectedIcon: Icon(Icons.home), icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(selectedIcon: Icon(Icons.calendar_month), icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          NavigationDestination(selectedIcon: Icon(Icons.newspaper), icon: Icon(Icons.newspaper_outlined), label: 'News'),
          NavigationDestination(selectedIcon: Icon(Icons.settings), icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

// ── Insight Data Class ──────────────────────────────────────────────

class _Insight {
  final String emoji;
  final String title;
  final String message;
  final Color color;
  const _Insight({required this.emoji, required this.title, required this.message, required this.color});
}

// ── Dummy BLE Service ───────────────────────────────────────────────

class _DummyBleService implements BleService {
  const _DummyBleService();
  @override Stream<List<int>> get dataStream => Stream.empty();
  @override Stream<List<ScanResult>> get scanResults => Stream.empty();
  @override Stream<BleMetrics> metricsStream() => Stream.empty();
  @override Future<void> connectToDevice(BluetoothDevice device) async {}
  @override String get connectedDeviceName => '';
  @override void dispose() {}
  @override void reset() {}
  @override Future<void> startScan() async {}
  @override void stopScan() {}
}
