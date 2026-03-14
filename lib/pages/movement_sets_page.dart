import 'package:flutter/material.dart';
import '../models/workout.dart';

/// The final level of the pyramid: viewing the specific sets and reps for a single movement.
class MovementSetsPage extends StatelessWidget {
  final Workout workout;
  final String exerciseName;

  const MovementSetsPage({
    super.key,
    required this.workout,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    // Filter the workout's sets to only include this specific exercise.
    // This is the core "logic" of this specific screen.
    final exerciseSets = workout.sets.where((s) => s.exercise == exerciseName).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(exerciseName),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: exerciseSets.isEmpty
          ? Center(
              child: Text(
                'No sets found for $exerciseName',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exerciseSets.length,
              itemBuilder: (context, index) {
                final setItem = exerciseSets[index];
                final hasReps = setItem.reps.isNotEmpty;
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Set header
                      Row(
                        children: [
                          Text(
                            'Set ${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${setItem.totalReps} reps',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Key metrics in a grid
                      _metricRow(context, 'Mean MCV', '${setItem.meanMCV.toStringAsFixed(2)} m/s'),
                      _metricRow(context, 'Best MCV', '${setItem.bestMCV.toStringAsFixed(2)} m/s (Rep ${setItem.bestRepNumber})'),
                      _metricRow(context, 'Velocity Loss', '${setItem.velocityLossPercent.toStringAsFixed(1)}%'),
                      _metricRow(context, 'Fatigue Index', setItem.fatigueIndex.toStringAsFixed(1)),
                      _metricRow(context, 'Total TUT', '${setItem.totalTUT.toStringAsFixed(1)}s'),
                      if (setItem.loadLbs != null)
                        _metricRow(context, 'Load', '${setItem.loadLbs!.toStringAsFixed(1)} lbs'),
                      if (setItem.estimated1RMLbs != null)
                        _metricRow(context, 'Est. 1RM', '${setItem.estimated1RMLbs!.toStringAsFixed(1)} lbs'),

                      // Rep-by-rep detail (if within 10 days)
                      if (hasReps) ...[
                        const SizedBox(height: 16),
                        Divider(height: 1, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Text(
                          'Rep Detail',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...setItem.reps.map((rep) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  'Rep ${rep.repNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'MCV: ${rep.meanConcentricVelocity.toStringAsFixed(2)}  •  '
                                  'Peak: ${rep.peakConcentricVelocity.toStringAsFixed(2)}  •  '
                                  'TUT: ${rep.timeUnderTension.toStringAsFixed(1)}s',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          'Detailed rep data has expired (10-day retention)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _metricRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
