import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../services/auth_service.dart';
import '../services/pdf_export_service.dart';
import '../services/theme_service.dart';
import '../repositories/workout_repository.dart';
import 'privacy_policy_page.dart';

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

  Future<void> _exportPDF() async {
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

      final pdf = PdfExportService.generateReport(workouts);

      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) => pdf.save(),
          name: 'VBT_Workout_Report',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              // ── USER PROFILE ─────────────────────────
              _buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Profile', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      currentUser?.displayName ?? 'No user logged in',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    if (currentUser?.email != null && currentUser!.email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(currentUser.email, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 14)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── WEEKLY GOAL ──────────────────────────
              _buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Goal', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
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
                                  color: _thisWeekCount >= _weeklyGoal ? Colors.green.shade400 : (isDark ? Colors.white : Colors.black87),
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
                                  color: _thisWeekCount >= _weeklyGoal ? Colors.green.shade400 : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Target:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                  const SizedBox(width: 6),
                                  _goalButton(context, 1), _goalButton(context, 2), _goalButton(context, 3),
                                  _goalButton(context, 4), _goalButton(context, 5), _goalButton(context, 6),
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
                context,
                child: Column(
                  children: [
                    // Units Toggle
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.straighten, color: isDark ? colorScheme.primary : Colors.grey.shade600),
                      title: const Text('Units', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _useMetric ? 'Metric (kg, cm)' : 'Imperial (lbs, in)',
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 13),
                      ),
                      trailing: Switch(
                        value: _useMetric,
                        onChanged: _toggleUnits,
                        activeThumbColor: Colors.blue,
                      ),
                    ),
                    Divider(height: 1, color: theme.dividerColor),

                    // Dark Mode Toggle
                    ListenableBuilder(
                      listenable: ThemeService.instance,
                      builder: (context, _) {
                        final isDark = ThemeService.instance.isDark;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                            color: isDark ? Colors.indigo.shade300 : Colors.amber.shade600,
                          ),
                          title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            isDark ? 'Dark theme active' : 'Light theme active',
                            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 13),
                          ),
                          trailing: Switch(
                            value: isDark,
                            onChanged: (_) => ThemeService.instance.toggle(),
                           activeThumbColor: Colors.indigo,
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: theme.dividerColor),

                    // Export as PDF
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.picture_as_pdf, color: Colors.red.shade400),
                      title: const Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Generate workout report with velocity curves', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 13)),
                      trailing: _isExporting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      onTap: _isExporting ? null : _exportPDF,
                    ),
                    Divider(height: 1, color: theme.dividerColor),

                    // Change Display Name
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit, color: isDark ? colorScheme.primary : Colors.grey.shade600),
                      title: const Text('Change Display Name', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Update how your name appears', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 13)),
                      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      onTap: () => _showChangeNameDialog(),
                    ),
                    Divider(height: 1, color: theme.dividerColor),

                    // Privacy Policy & Terms
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.shield_outlined, color: Colors.blue.shade600),
                      title: const Text('Privacy Policy & Terms', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('View how your data is used', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 13)),
                      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      )),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── LOGOUT ───────────────────────────────
              _buildCard(
                context,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: Colors.red.shade600),
                  title: Text('Logout', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  onTap: () async {
                    await widget.authService.signOut();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── DELETE ACCOUNT ───────────────────────
              _buildCard(
                context,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever, color: Colors.red.shade800),
                  title: Text('Delete Account',
                      style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Permanently delete your account and all data',
                      style: TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  onTap: () => _showDeleteAccountDialog(),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Change Display Name Dialog ──

  Future<void> _showChangeNameDialog() async {
    final currentName = widget.authService.currentUser?.displayName ?? '';
    final nameController = TextEditingController(text: currentName);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Change Display Name', style: TextStyle(fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'New Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          if (newName.isEmpty || newName == currentName) {
                            Navigator.pop(ctx);
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            await widget.authService.updateDisplayName(newName);
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update name: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? colorScheme.primary : Colors.black87,
                    foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Delete Account Dialog ───────

  Future<void> _showDeleteAccountDialog() async {
    final isGoogle = widget.authService.currentFirebaseUser
            ?.providerData
            .any((p) => p.providerId == 'google.com') ??
        false;
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 8),
                const Text('Delete Account', style: TextStyle(fontSize: 17)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently deletes your account and ALL workout data. '
                  'This cannot be undone.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                if (!isGoogle) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Enter your password to confirm',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    'You will be asked to sign in with Google to confirm.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        try {
                          await widget.authService.deleteAccount(
                            password: isGoogle ? null : passwordController.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setDialogState(() => isDeleting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Delete Forever'),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget _goalButton(BuildContext context, int n) {
    final isSelected = _weeklyGoal == n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: GestureDetector(
        onTap: () => _saveWeeklyGoal(n),
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
          ),
          child: Center(
            child: Text('$n', style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? theme.colorScheme.onPrimary : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
      ..color = color.withValues(alpha: 0.2)
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
