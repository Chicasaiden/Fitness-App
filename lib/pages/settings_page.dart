import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../repositories/workout_repository.dart';

/// Settings page with user profile, weekly goal, units preference, and data export.
class SettingsPage extends StatefulWidget {
  final AuthService authService;
  final WorkoutRepository? workoutRepository;
  final String? userId;

  const SettingsPage({
    super.key,
    required this.authService,
    this.workoutRepository,
    this.userId,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _weeklyGoal = 3;
  bool _useMetric = false; // false = imperial (lbs), true = metric (kg)
  int _thisWeekCount = 0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadThisWeekCount();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _weeklyGoal = prefs.getInt('weeklyGoal') ?? 3;
      _useMetric = prefs.getBool('useMetric') ?? false;
    });
  }

  Future<void> _saveWeeklyGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('weeklyGoal', goal);
    setState(() => _weeklyGoal = goal);
  }

  Future<void> _toggleUnits(bool metric) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useMetric', metric);
    setState(() => _useMetric = metric);
  }

  Future<void> _loadThisWeekCount() async {
    if (widget.workoutRepository == null || widget.userId == null) return;
    final workouts = await widget.workoutRepository!.getWorkoutsByUserId(widget.userId!);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    setState(() {
      _thisWeekCount = workouts.where((w) =>
        w.date.isAfter(thisWeekStart.subtract(const Duration(days: 1)))
      ).length;
    });
  }

  Future<void> _exportDataCSV() async {
    if (widget.workoutRepository == null || widget.userId == null) return;
    setState(() => _isExporting = true);

    try {
      final workouts = await widget.workoutRepository!.getWorkoutsByUserId(widget.userId!);
      if (workouts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No workout data to export.')),
          );
        }
        return;
      }

      // Build CSV content
      final buffer = StringBuffer();
      buffer.writeln('Date,Duration (s),Mean MCV (m/s),Peak MCV (m/s),TUT (s),ROM (m),Sets,Exercise,Notes');
      for (final w in workouts) {
        final exercises = w.sets.map((s) => s.exercise).toSet().join('; ');
        buffer.writeln(
          '${w.date.toIso8601String().split("T")[0]},'
          '${w.duration.toStringAsFixed(1)},'
          '${w.meanConcentricVelocity.toStringAsFixed(3)},'
          '${w.peakConcentricVelocity.toStringAsFixed(3)},'
          '${w.timeUnderTension.toStringAsFixed(1)},'
          '${w.rangeOfMotion.toStringAsFixed(3)},'
          '${w.sets.length},'
          '$exercises,'
          '${w.notes ?? ""}'
        );
      }

      // Show in a dialog since we can't easily write to file on all platforms
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.table_chart, color: Colors.green.shade600),
                const SizedBox(width: 10),
                const Text('Export Data', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: SingleChildScrollView(
                child: SelectableText(
                  buffer.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              // ── USER PROFILE ─────────────────────────
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Profile', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      currentUser?.displayName ?? 'No user logged in',
                      style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    if (currentUser?.email != null && currentUser!.email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(currentUser.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── WEEKLY GOAL ──────────────────────────
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Goal', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Progress ring
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CustomPaint(
                            painter: _GoalRingPainter(
                              progress: _weeklyGoal > 0 ? (_thisWeekCount / _weeklyGoal).clamp(0, 1) : 0,
                              color: _thisWeekCount >= _weeklyGoal ? Colors.green : Colors.blue,
                            ),
                            child: Center(
                              child: Text(
                                '$_thisWeekCount/$_weeklyGoal',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _thisWeekCount >= _weeklyGoal ? Colors.green.shade700 : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _thisWeekCount >= _weeklyGoal ? 'Goal reached! 🎉' : '${_weeklyGoal - _thisWeekCount} more this week',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _thisWeekCount >= _weeklyGoal ? Colors.green.shade700 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Target:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  const SizedBox(width: 6),
                                  _goalButton(1), _goalButton(2), _goalButton(3),
                                  _goalButton(4), _goalButton(5), _goalButton(6),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── PREFERENCES ──────────────────────────
              _buildCard(
                child: Column(
                  children: [
                    // Units Toggle
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.straighten, color: Colors.grey.shade600),
                      title: const Text('Units', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _useMetric ? 'Metric (kg, cm)' : 'Imperial (lbs, in)',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                      trailing: Switch(
                        value: _useMetric,
                        onChanged: _toggleUnits,
                        activeThumbColor: Colors.blue,
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),

                    // Export Data
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.download, color: Colors.grey.shade600),
                      title: const Text('Export Data', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Export workout history as CSV', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      trailing: _isExporting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      onTap: _isExporting ? null : _exportDataCSV,
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),

                    // Edit Profile
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit, color: Colors.grey.shade600),
                      title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Update your account information', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      onTap: () {},
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),

                    // Notifications
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.notifications, color: Colors.grey.shade600),
                      title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Manage notification settings', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── LOGOUT ───────────────────────────────
              _buildCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: Colors.red.shade600),
                  title: Text('Logout', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  onTap: () async {
                    await widget.authService.signOut();
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalButton(int n) {
    final isSelected = _weeklyGoal == n;
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: GestureDetector(
        onTap: () => _saveWeeklyGoal(n),
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isSelected ? Colors.black87 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: isSelected ? Colors.black87 : Colors.grey.shade300),
          ),
          child: Center(
            child: Text('$n', style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

/// Custom painter for the goal progress ring.
class _GoalRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;

  _GoalRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = color
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // Start from top
        2 * pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter old) =>
      old.progress != progress || old.color != color;
}
