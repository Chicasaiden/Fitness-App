/// A single planned exercise entry within a daily WorkoutPlan.
class PlannedMovement {
  final String exercise;
  final int targetSets;
  final int targetReps;

  /// The training goal zone for this movement.
  /// One of: 'Strength', 'Power', 'Hypertrophy'
  final String goalZone;

  /// Auto-suggested load computed from the user's VBT 1RM history.
  final double? suggestedLoadLbs;

  /// User override — if set, this takes priority over [suggestedLoadLbs].
  final double? overrideLoadLbs;

  /// If true, this movement is automatically carried forward to the same
  /// weekday in the following week when no plan exists for that day.
  final bool repeatWeekly;

  const PlannedMovement({
    required this.exercise,
    this.targetSets = 3,
    this.targetReps = 5,
    this.goalZone = 'Strength',
    this.suggestedLoadLbs,
    this.overrideLoadLbs,
    this.repeatWeekly = false,
  });

  /// The load to actually use (override takes priority over suggestion).
  double? get effectiveLoadLbs => overrideLoadLbs ?? suggestedLoadLbs;

  PlannedMovement copyWith({
    String? exercise,
    int? targetSets,
    int? targetReps,
    String? goalZone,
    double? suggestedLoadLbs,
    double? overrideLoadLbs,
    bool? repeatWeekly,
  }) {
    return PlannedMovement(
      exercise: exercise ?? this.exercise,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      goalZone: goalZone ?? this.goalZone,
      suggestedLoadLbs: suggestedLoadLbs ?? this.suggestedLoadLbs,
      overrideLoadLbs: overrideLoadLbs ?? this.overrideLoadLbs,
      repeatWeekly: repeatWeekly ?? this.repeatWeekly,
    );
  }

  Map<String, dynamic> toJson() => {
    'exercise': exercise,
    'targetSets': targetSets,
    'targetReps': targetReps,
    'goalZone': goalZone,
    'suggestedLoadLbs': suggestedLoadLbs,
    'overrideLoadLbs': overrideLoadLbs,
    'repeatWeekly': repeatWeekly,
  };

  factory PlannedMovement.fromJson(Map<String, dynamic> json) =>
      PlannedMovement(
        exercise: json['exercise'] as String,
        targetSets: (json['targetSets'] as num?)?.toInt() ?? 3,
        targetReps: (json['targetReps'] as num?)?.toInt() ?? 5,
        goalZone: json['goalZone'] as String? ?? 'Strength',
        suggestedLoadLbs: (json['suggestedLoadLbs'] as num?)?.toDouble(),
        overrideLoadLbs: (json['overrideLoadLbs'] as num?)?.toDouble(),
        repeatWeekly: json['repeatWeekly'] as bool? ?? false,
      );
}
