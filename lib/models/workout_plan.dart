import 'planned_movement.dart';

/// A daily workout plan for a specific user and date.
class WorkoutPlan {
  /// Unique ID in the format "{userId}_{YYYYMMDD}".
  final String id;
  final String userId;

  /// The calendar date this plan is for (time component is ignored).
  final DateTime date;

  final List<PlannedMovement> movements;
  final String? notes;

  const WorkoutPlan({
    required this.id,
    required this.userId,
    required this.date,
    this.movements = const [],
    this.notes,
  });

  /// Creates the document ID for a user+date combination.
  static String idFor(String userId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${userId}_$y$m$d';
  }

  /// Returns true if this plan has at least one movement.
  bool get hasMovements => movements.isNotEmpty;

  WorkoutPlan copyWith({
    List<PlannedMovement>? movements,
    String? notes,
  }) {
    return WorkoutPlan(
      id: id,
      userId: userId,
      date: date,
      movements: movements ?? this.movements,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'date': date.toIso8601String(),
    'movements': movements.map((m) => m.toJson()).toList(),
    'notes': notes,
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
    id: json['id'] as String,
    userId: json['userId'] as String,
    date: DateTime.parse(json['date'] as String),
    movements: (json['movements'] as List?)
        ?.map((m) => PlannedMovement.fromJson(Map<String, dynamic>.from(m)))
        .toList() ?? [],
    notes: json['notes'] as String?,
  );
}
