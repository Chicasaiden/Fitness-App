import 'package:flutter/material.dart';
import '../repositories/workout_repository.dart';
import '../models/workout.dart';
import 'workout_movements_page.dart';
/// Displays a list of past workouts, each showing the date and summary metrics.
/// Tapping a workout shows its detailed set summaries.
///
/// This reuses the same data source (WorkoutRepository) as the metrics dashboard,
/// but presents it in a simpler, history-focused format.
class ViewOldWorkoutPage extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final String userId;

  const ViewOldWorkoutPage({
    super.key,
    required this.workoutRepository,
    required this.userId,
  });

  @override
  State<ViewOldWorkoutPage> createState() => _ViewOldWorkoutPageState();
}

class _ViewOldWorkoutPageState extends State<ViewOldWorkoutPage> {
  late Future<List<Workout>> _workoutsFuture;

  @override
  void initState() {
    super.initState();
    _workoutsFuture =
        widget.workoutRepository.getWorkoutsByUserId(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<List<Workout>>(
          future: _workoutsFuture,
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Error state
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load workouts',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            final workouts = snapshot.data ?? [];

            // Empty state
            if (workouts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No Workouts Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete a workout to see it here',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            // Workout list
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: workouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return _WorkoutCard(
                  workout: workout,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutMovementsPage(workout: workout),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

}

/// A single workout card in the list.
class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const _WorkoutCard({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // Date icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${workout.date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _monthAbbrev(workout.date.month),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Workout info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_dayName(workout.date.weekday)} at ${workout.formattedTime}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _WorkoutCard._getExercisesList(workout),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${workout.sets.length} sets  •  ${(workout.duration / 60).toStringAsFixed(0)} min',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  String _dayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _monthAbbrev(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  static String _getExercisesList(Workout workout) {
    final Set<String> exercises = {};
    for (final set in workout.sets) {
      if (set.exercise != 'Unspecified') {
        exercises.add(set.exercise);
      }
    }
    if (exercises.isEmpty) return 'Mixed Workout';
    return exercises.join(', ');
  }
}
