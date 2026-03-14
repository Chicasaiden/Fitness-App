import 'package:flutter/material.dart';
import '../models/workout.dart';
import 'movement_sets_page.dart';

/// The middle level of the pyramid: showing uniquely performed movements in a single workout.
class WorkoutMovementsPage extends StatelessWidget {
  final Workout workout;

  const WorkoutMovementsPage({
    super.key,
    required this.workout,
  });

  @override
  Widget build(BuildContext context) {
    final movements = _getUniqueExercises(workout);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movements'),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workout Header Summary
          Container(
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).cardColor,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${workout.formattedDate} at ${workout.formattedTime}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Duration: ${(workout.duration / 60).toStringAsFixed(1)} min  •  ${workout.sets.length} total sets',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          
          Expanded(
            child: movements.isEmpty
                ? Center(
                    child: Text(
                      'No movements logged.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: movements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exerciseName = movements[index];
                      // Calculate some quick stats for the card
                      final setsForExercise = workout.sets.where((s) => s.exercise == exerciseName).toList();
                      
                      return _MovementCard(
                        exerciseName: exerciseName,
                        numberOfSets: setsForExercise.length,
                        onTap: () {
                          // The "Pyramid Push" to the final level
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MovementSetsPage(
                                workout: workout,
                                exerciseName: exerciseName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Logical helper method: extracts unique exercise names from the workout sets
  List<String> _getUniqueExercises(Workout workout) {
    final Set<String> exercises = {};
    for (final set in workout.sets) {
      if (set.exercise != 'Unspecified') {
        exercises.add(set.exercise);
      }
    }
    final list = exercises.toList();
    if (list.isEmpty && workout.sets.isNotEmpty) return ['Mixed Workout'];
    return list;
  }
}

class _MovementCard extends StatelessWidget {
  final String exerciseName;
  final int numberOfSets;
  final VoidCallback onTap;

  const _MovementCard({
    required this.exerciseName,
    required this.numberOfSets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fitness_center,
                color: Colors.blue.shade400,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exerciseName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$numberOfSets sets completed',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
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
}
