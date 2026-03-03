import 'rep_record.dart';

/// Computed summary for a completed set.
class SetSummary {
  final List<RepRecord> reps;
  final int totalReps;
  final double setDuration; // seconds
  final double totalTUT; // sum of all rep TUTs
  final double meanMCV; // m/s
  final double meanPCV; // m/s
  final double bestMCV; // m/s
  final double worstMCV; // m/s
  final int bestRepNumber;
  final int worstRepNumber;
  final double velocityLossPercent;
  final double repVariabilitySD; // std dev of MCV
  final double fatigueIndex; // 0–100
  final double meanROM; // meters
  final double meanAvgZAccel; // m/s²
  final double meanPeakZAccel; // m/s²

  // Optional power/1RM fields (computed if load is provided)
  final double? loadLbs;
  final double? estimatedMeanPower; // watts
  final double? estimatedPeakPower; // watts
  final double? estimated1RMLbs; // estimated 1RM as weight in lbs
  final double? impulse; // N·s
  final String? suggestedNextLoad;

  final String exercise;
  final DateTime timestamp;

  SetSummary({
    required this.reps,
    required this.totalReps,
    required this.setDuration,
    required this.totalTUT,
    required this.meanMCV,
    required this.meanPCV,
    required this.bestMCV,
    required this.worstMCV,
    required this.bestRepNumber,
    required this.worstRepNumber,
    required this.velocityLossPercent,
    required this.repVariabilitySD,
    required this.fatigueIndex,
    required this.meanROM,
    required this.meanAvgZAccel,
    required this.meanPeakZAccel,
    required this.timestamp,
    this.exercise = 'Unspecified',
    this.loadLbs,
    this.estimatedMeanPower,
    this.estimatedPeakPower,
    this.estimated1RMLbs,
    this.impulse,
    this.suggestedNextLoad,
  });

  Map<String, dynamic> toJson() => {
    'reps': reps.map((r) => r.toJson()).toList(),
    'totalReps': totalReps,
    'setDuration': setDuration,
    'totalTUT': totalTUT,
    'meanMCV': meanMCV,
    'meanPCV': meanPCV,
    'bestMCV': bestMCV,
    'worstMCV': worstMCV,
    'bestRepNumber': bestRepNumber,
    'worstRepNumber': worstRepNumber,
    'velocityLossPercent': velocityLossPercent,
    'repVariabilitySD': repVariabilitySD,
    'fatigueIndex': fatigueIndex,
    'meanROM': meanROM,
    'meanAvgZAccel': meanAvgZAccel,
    'meanPeakZAccel': meanPeakZAccel,
    'exercise': exercise,
    'timestamp': timestamp.toIso8601String(),
    'loadLbs': loadLbs,
    'estimatedMeanPower': estimatedMeanPower,
    'estimatedPeakPower': estimatedPeakPower,
    'estimated1RMLbs': estimated1RMLbs,
    'impulse': impulse,
    'suggestedNextLoad': suggestedNextLoad,
  };

  factory SetSummary.fromJson(Map<String, dynamic> json) => SetSummary(
    reps: (json['reps'] as List)
        .map((r) => RepRecord.fromJson(Map<String, dynamic>.from(r)))
        .toList(),
    totalReps: json['totalReps'] as int,
    setDuration: (json['setDuration'] as num).toDouble(),
    totalTUT: (json['totalTUT'] as num).toDouble(),
    meanMCV: (json['meanMCV'] as num).toDouble(),
    meanPCV: (json['meanPCV'] as num).toDouble(),
    bestMCV: (json['bestMCV'] as num).toDouble(),
    worstMCV: (json['worstMCV'] as num).toDouble(),
    bestRepNumber: json['bestRepNumber'] as int,
    worstRepNumber: json['worstRepNumber'] as int,
    velocityLossPercent: (json['velocityLossPercent'] as num).toDouble(),
    repVariabilitySD: (json['repVariabilitySD'] as num).toDouble(),
    fatigueIndex: (json['fatigueIndex'] as num).toDouble(),
    meanROM: (json['meanROM'] as num).toDouble(),
    meanAvgZAccel: (json['meanAvgZAccel'] as num).toDouble(),
    meanPeakZAccel: (json['meanPeakZAccel'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    exercise: json['exercise'] as String? ?? 'Unspecified',
    loadLbs: (json['loadLbs'] as num?)?.toDouble(),
    estimatedMeanPower: (json['estimatedMeanPower'] as num?)?.toDouble(),
    estimatedPeakPower: (json['estimatedPeakPower'] as num?)?.toDouble(),
    estimated1RMLbs: (json['estimated1RMLbs'] as num?)?.toDouble(),
    impulse: (json['impulse'] as num?)?.toDouble(),
    suggestedNextLoad: json['suggestedNextLoad'] as String?,
  );
}
