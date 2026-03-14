import 'package:flutter/material.dart';
import '../models/planned_movement.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../repositories/workout_plan_repository.dart';
import '../services/metrics_calculator.dart';

/// Page for creating or editing a daily workout plan.
///
/// If [initialPlan] is provided, the page starts pre-filled for editing.
/// The [date] determines which day is being planned.
class PlanWorkoutPage extends StatefulWidget {
  final WorkoutPlanRepository planRepository;
  final String userId;
  final DateTime date;
  final WorkoutPlan? initialPlan;

  /// Past workouts used to auto-suggest loads via VBT 1RM data.
  final List<Workout> pastWorkouts;

  const PlanWorkoutPage({
    super.key,
    required this.planRepository,
    required this.userId,
    required this.date,
    this.initialPlan,
    this.pastWorkouts = const [],
  });

  @override
  State<PlanWorkoutPage> createState() => _PlanWorkoutPageState();
}

class _PlanWorkoutPageState extends State<PlanWorkoutPage> {
  late List<PlannedMovement> _movements;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  static const List<String> _exercises = [
    'Squat', 'Front Squat', 'Bench Press', 'Incline Bench',
    'Overhead Press', 'Deadlift', 'Romanian Deadlift',
    'Barbell Row', 'Hip Thrust', 'Power Clean',
    'Push Press', 'Lunges', 'Custom',
  ];

  static const List<String> _zones = ['Strength', 'Hypertrophy', 'Power'];

  static const Map<String, Color> _zoneColors = {
    'Strength':    Color(0xFF1565C0),  // deep blue
    'Hypertrophy': Color(0xFF2E7D32),  // deep green
    'Power':       Color(0xFFE65100),  // deep orange
  };

  @override
  void initState() {
    super.initState();
    _movements = List.from(widget.initialPlan?.movements ?? []);
    _notesController.text = widget.initialPlan?.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _dateLabel {
    final d = widget.date;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = days[d.weekday - 1];
    return '$weekday, ${months[d.month]} ${d.day}, ${d.year}';
  }

  bool get _isToday {
    final today = DateTime.now();
    return widget.date.year == today.year &&
        widget.date.month == today.month &&
        widget.date.day == today.day;
  }

  Future<void> _save() async {
    if (_movements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise to save.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final plan = WorkoutPlan(
        id: WorkoutPlan.idFor(widget.userId, widget.date),
        userId: widget.userId,
        date: widget.date,
        movements: _movements,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      await widget.planRepository.savePlan(plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isToday ? 'Today\'s plan saved! 💪' : 'Plan saved!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context, plan);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddExerciseSheet() {
    String selectedExercise = _exercises.first;
    String selectedZone = 'Strength';
    int targetSets = 3;
    int targetReps = 5;
    bool repeatWeekly = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final suggested = MetricsCalculator.suggestPlanLoad(
              exercise: selectedExercise,
              pastWorkouts: widget.pastWorkouts,
              goalZone: selectedZone,
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sheet handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Add Exercise',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(ctx).colorScheme.onSurface)),
                  const SizedBox(height: 20),

                  // Exercise picker
                  Text('Exercise', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.black54)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedExercise,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _exercises.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setSheetState(() => selectedExercise = v!),
                  ),
                  const SizedBox(height: 16),

                  // Goal Zone
                  Text('Goal Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.black54)),
                  const SizedBox(height: 6),
                  Row(
                    children: _zones.map((zone) {
                      final isSelected = selectedZone == zone;
                      final color = _zoneColors[zone]!;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setSheetState(() => selectedZone = zone),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                  color: isSelected ? color.withValues(alpha: isDark ? 0.3 : 0.12) : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? color : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                                    width: isSelected ? 2 : 1,
                                  ),
                              ),
                              child: Text(
                                zone,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                    color: isSelected ? color : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Sets × Reps
                  Row(
                    children: [
                      Expanded(child: _stepperField('Sets', targetSets, 1, 10,
                          (v) => setSheetState(() => targetSets = v), isDark, ctx)),
                      const SizedBox(width: 12),
                      Expanded(child: _stepperField('Reps', targetReps, 1, 25,
                          (v) => setSheetState(() => targetReps = v), isDark, ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Auto-suggested load from VBT history
                  if (suggested != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'VBT suggests ${suggested.toStringAsFixed(1)} lbs for $selectedZone',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (suggested != null) const SizedBox(height: 16),

                  // Repeat Weekly toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.repeat, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Repeat Weekly',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(ctx).colorScheme.onSurface)),
                              Text('Auto-fill this ${_dayName(widget.date.weekday)} every week',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        Switch(
                          value: repeatWeekly,
                          onChanged: (v) => setSheetState(() => repeatWeekly = v),
                          activeThumbColor: Colors.blue.shade600,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final movement = PlannedMovement(
                          exercise: selectedExercise,
                          targetSets: targetSets,
                          targetReps: targetReps,
                          goalZone: selectedZone,
                          suggestedLoadLbs: suggested,
                          repeatWeekly: repeatWeekly,
                        );
                        setState(() => _movements.add(movement));
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Add to Plan'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _stepperField(String label, int value, int min, int max, ValueChanged<int> onChanged, bool isDark, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.black54)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: value > min ? () => onChanged(value - 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(ctx).colorScheme.onSurface),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: value < max ? () => onChanged(value + 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isToday ? 'Today\'s Plan' : 'Plan Workout'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date header
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  _dateLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isToday ? Colors.blue.shade700 : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (_isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Movement list
          Expanded(
            child: _movements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.playlist_add, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No exercises planned yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text('Tap + to add your first movement',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _movements.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _movements.removeAt(oldIndex);
                      _movements.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (ctx, i) {
                    final m = _movements[i];
                    final zoneColor = _zoneColors[m.goalZone] ?? Colors.grey;
                    return _MovementCard(
                      key: ValueKey('$i-${m.exercise}'),
                      movement: m,
                      zoneColor: zoneColor,
                      onDelete: () => setState(() => _movements.removeAt(i)),
                      onLoadOverride: (lbs) {
                        setState(() {
                          _movements[i] = m.copyWith(overrideLoadLbs: lbs);
                        });
                      },
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExerciseSheet,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── Movement Card ───────────────────────────────────────────────────────────

class _MovementCard extends StatelessWidget {
  final PlannedMovement movement;
  final Color zoneColor;
  final VoidCallback onDelete;
  final ValueChanged<double?> onLoadOverride;

  const _MovementCard({
    super.key,
    required this.movement,
    required this.zoneColor,
    required this.onDelete,
    required this.onLoadOverride,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLbs = movement.effectiveLoadLbs;
    final hasOverride = movement.overrideLoadLbs != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: zoneColor, width: 4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(movement.exercise,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  // Zone chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: zoneColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(movement.goalZone,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: zoneColor)),
                  ),
                  const SizedBox(width: 8),
                  // Repeat weekly indicator
                  if (movement.repeatWeekly)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: 'Repeats weekly',
                        child: Icon(Icons.repeat, size: 14, color: Colors.grey.shade500),
                      ),
                    ),
                  // Drag handle (provided by ReorderableListView)
                  Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Sets × Reps
                  _infoChip(Icons.format_list_numbered,
                      '${movement.targetSets} × ${movement.targetReps}'),
                  const SizedBox(width: 8),
                  // Suggested load
                  if (effectiveLbs != null)
                    _infoChip(
                      hasOverride ? Icons.edit : Icons.lightbulb_outline,
                      '${effectiveLbs.toStringAsFixed(1)} lbs',
                      color: hasOverride ? Colors.blue.shade700 : Colors.amber.shade800,
                    ),
                  const Spacer(),
                  // Delete
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }
}
