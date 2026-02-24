import 'set_summary.dart';

class Workout {
  final String id;
  final String userId;
  final DateTime date;
  final double duration; // seconds
  final double meanConcentricVelocity; // m/s (session average)
  final double peakConcentricVelocity; // m/s (session best)
  final double timeUnderTension; // seconds (session total)
  final double rangeOfMotion; // meters (session average)
  final double averageZAcceleration; // m/s²
  final double peakZAcceleration; // m/s²
  final List<SetSummary> sets; // per-set data
  final String? notes;

  Workout({
    required this.id,
    required this.userId,
    required this.date,
    required this.duration,
    required this.meanConcentricVelocity,
    required this.peakConcentricVelocity,
    required this.timeUnderTension,
    required this.rangeOfMotion,
    required this.averageZAcceleration,
    required this.peakZAcceleration,
    this.sets = const [],
    this.notes,
  });

  /// Convert Workout to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'duration': duration,
      'meanConcentricVelocity': meanConcentricVelocity,
      'peakConcentricVelocity': peakConcentricVelocity,
      'timeUnderTension': timeUnderTension,
      'rangeOfMotion': rangeOfMotion,
      'averageZAcceleration': averageZAcceleration,
      'peakZAcceleration': peakZAcceleration,
      'sets': sets.map((s) => s.toJson()).toList(),
      'notes': notes,
    };
  }

  /// Create Workout from JSON
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      userId: json['userId'] as String,
      date: DateTime.parse(json['date'] as String),
      duration: (json['duration'] as num).toDouble(),
      meanConcentricVelocity: (json['meanConcentricVelocity'] as num?)?.toDouble() ?? 0.0,
      peakConcentricVelocity: (json['peakConcentricVelocity'] as num?)?.toDouble() ?? 0.0,
      timeUnderTension: (json['timeUnderTension'] as num?)?.toDouble() ?? 0.0,
      rangeOfMotion: (json['rangeOfMotion'] as num?)?.toDouble() ?? 0.0,
      averageZAcceleration: (json['averageZAcceleration'] as num?)?.toDouble() ?? 0.0,
      peakZAcceleration: (json['peakZAcceleration'] as num?)?.toDouble() ?? 0.0,
      sets: (json['sets'] as List?)
          ?.map((s) => SetSummary.fromJson(Map<String, dynamic>.from(s)))
          .toList() ?? [],
      notes: json['notes'] as String?,
    );
  }

  /// Get a formatted date string for display
  String get formattedDate {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Get a formatted time string for display
  String get formattedTime {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Get formatted summary for list display
  String get summaryMetrics {
    return 'MCV: ${meanConcentricVelocity.toStringAsFixed(2)} m/s | Peak: ${peakConcentricVelocity.toStringAsFixed(2)} m/s';
  }
}
