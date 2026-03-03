import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'data_dashboard.dart';
import 'view_old_workout_page.dart';
import 'plan_workout_page.dart';
import 'calendar_page.dart';
import 'news_page.dart';
import 'settings_page.dart';
import 'metrics_dashboard_page.dart';
import '../services/ble_service.dart';
import '../services/set_tracker.dart';
import '../services/auth_service.dart';
import '../repositories/workout_repository.dart';
import '../ble_metrics.dart';
import '../models/workout.dart';

class HomePage extends StatefulWidget {
  final BleService bleService;
  final AuthService authService;
  final WorkoutRepository workoutRepository;
  final String connectedDeviceName;

  const HomePage({
    Key? key,
    BleService? bleService,
    required this.authService,
    required this.workoutRepository,
    this.connectedDeviceName = '',
  })  : bleService = bleService ?? const _DummyBleService(),
        super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;
  String _connectedDevice = '';
  late final SetTracker _setTracker;

  @override
  void initState() {
    super.initState();
    _connectedDevice = widget.connectedDeviceName.isNotEmpty
        ? widget.connectedDeviceName
        : widget.bleService.connectedDeviceName;
    _setTracker = SetTracker(widget.bleService);
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
    final userName = currentUser?.displayName ?? 'User';
    final userId = currentUser?.id ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi $userName,',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── QUICK STATS STRIP ──────────────────────────
                FutureBuilder<List<Workout>>(
                  future: widget.workoutRepository.getWorkoutsByUserId(userId),
                  builder: (context, snapshot) {
                    final workouts = snapshot.data ?? [];
                    return _buildQuickStats(workouts);
                  },
                ),

                const SizedBox(height: 10),

                // ── CONNECTION SECTION ─────────────────────────
                _buildSectionBubble(
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
                          backgroundColor: Colors.black87,
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
                          color: _connectedDevice.isEmpty ? Colors.red.shade50 : Colors.green.shade50,
                          border: Border.all(
                            color: _connectedDevice.isEmpty ? Colors.red.shade200 : Colors.green.shade200,
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
                                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13),
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
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const PlanWorkoutPage(),
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
                    return _buildInsightsSection(workouts);
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

  Widget _buildQuickStats(List<Workout> workouts) {
    final totalWorkouts = workouts.length;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final thisWeek = workouts.where((w) =>
      w.date.isAfter(thisWeekStart.subtract(const Duration(days: 1)))
    ).length;

    double bestMCV = 0;
    for (final w in workouts) {
      if (w.peakConcentricVelocity > bestMCV) bestMCV = w.peakConcentricVelocity;
    }

    return Row(
      children: [
        _statCard('Total', '$totalWorkouts', Icons.fitness_center),
        const SizedBox(width: 10),
        _statCard('This Week', '$thisWeek', Icons.calendar_today),
        const SizedBox(width: 10),
        _statCard('Best MCV', bestMCV > 0 ? bestMCV.toStringAsFixed(2) : '--', Icons.speed),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Insights Section ──────────────────────────────────────────────

  Widget _buildInsightsSection(List<Workout> workouts) {
    if (workouts.isEmpty) {
      return _buildSectionBubble(
        title: '💡 Insights',
        child: Text(
          'Complete your first workout to see personalized insights!',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    final insights = _generateInsights(workouts);

    return _buildSectionBubble(
      title: '💡 Insights',
      child: Column(
        children: insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: insight.color.withValues(alpha: 0.2)),
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        insight.message,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
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

    return insights.take(4).toList();
  }

  // ── Section Bubble ────────────────────────────────────────────────

  Widget _buildSectionBubble({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
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
