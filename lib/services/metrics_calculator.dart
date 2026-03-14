import 'dart:math';
import '../models/rep_record.dart';
import '../models/set_summary.dart';

/// Velocity training zones based on MCV.
enum VelocityZone {
  maxStrength,    // < 0.5 m/s
  strength,       // 0.5–0.75 m/s
  speedStrength,  // 0.75–1.0 m/s
  power,          // 1.0–1.3 m/s
  speed,          // > 1.3 m/s
}

/// Pure utility class for computing derived metrics from rep data.
class MetricsCalculator {
  MetricsCalculator._(); // Prevent instantiation

  // ─── Unit Conversions ───
  static const double kgPerLb = 0.453592;
  static const double lbsPerKg = 2.20462;

  static double kgToLbs(double kg) => kg * lbsPerKg;
  static double lbsToKg(double lbs) => lbs * kgPerLb;

  /// Velocity Loss %: how much MCV drops from first to last rep.
  static double velocityLoss(List<RepRecord> reps) {
    if (reps.length < 2) return 0.0;
    final first = reps.first.meanConcentricVelocity;
    final last = reps.last.meanConcentricVelocity;
    if (first == 0) return 0.0;
    return ((first - last) / first) * 100.0;
  }

  /// Standard deviation of MCV across reps (rep-to-rep variability).
  static double repVariability(List<RepRecord> reps) {
    if (reps.length < 2) return 0.0;
    final mcvs = reps.map((r) => r.meanConcentricVelocity).toList();
    final mean = mcvs.reduce((a, b) => a + b) / mcvs.length;
    final variance = mcvs.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / mcvs.length;
    return sqrt(variance);
  }

  /// Fatigue Index: composite 0–100 score.
  /// Higher = more fatigue. Combines Vloss (50%), PCV drop (25%), variability (25%).
  static double fatigueIndex(List<RepRecord> reps) {
    if (reps.length < 2) return 0.0;

    final vloss = velocityLoss(reps).clamp(0.0, 50.0) * 2.0;

    final pcvFirst = reps.first.peakConcentricVelocity;
    final pcvLast = reps.last.peakConcentricVelocity;
    final pcvDrop = pcvFirst > 0
        ? (((pcvFirst - pcvLast) / pcvFirst) * 100.0).clamp(0.0, 50.0) * 2.0
        : 0.0;

    final sd = repVariability(reps);
    final variabilityScore = (sd / 0.2 * 100.0).clamp(0.0, 100.0);

    return (vloss * 0.50 + pcvDrop * 0.25 + variabilityScore * 0.25).clamp(0.0, 100.0);
  }

  /// Determine velocity training zone from MCV.
  static VelocityZone velocityZone(double mcv) {
    if (mcv < 0.5) return VelocityZone.maxStrength;
    if (mcv < 0.75) return VelocityZone.strength;
    if (mcv < 1.0) return VelocityZone.speedStrength;
    if (mcv < 1.3) return VelocityZone.power;
    return VelocityZone.speed;
  }

  /// Human-readable zone label.
  static String zoneLabel(VelocityZone zone) {
    switch (zone) {
      case VelocityZone.maxStrength: return 'Max Strength';
      case VelocityZone.strength: return 'Strength';
      case VelocityZone.speedStrength: return 'Speed-Strength';
      case VelocityZone.power: return 'Power';
      case VelocityZone.speed: return 'Speed';
    }
  }

  /// Zone color as hex int (for Color constructor).
  static int zoneColorValue(VelocityZone zone) {
    switch (zone) {
      case VelocityZone.maxStrength: return 0xFFE53935; // Red
      case VelocityZone.strength: return 0xFFFB8C00;    // Orange
      case VelocityZone.speedStrength: return 0xFFFDD835; // Yellow
      case VelocityZone.power: return 0xFF43A047;        // Green
      case VelocityZone.speed: return 0xFF1E88E5;        // Blue
    }
  }

  // ─── Power & 1RM (require load input) ───
  // All internal calculations use kg; display converts to lbs.

  /// Estimated mean power in watts. loadKg is in kg.
  static double estimatedMeanPower(double loadKg, double avgAccel, double mcv) {
    final force = loadKg * (avgAccel.abs() + 9.81);
    return force * mcv;
  }

  /// Estimated peak power in watts. loadKg is in kg.
  static double estimatedPeakPower(double loadKg, double peakAccel, double pcv) {
    final force = loadKg * (peakAccel.abs() + 9.81);
    return force * pcv;
  }

  /// Impulse in N·s (Force × time). loadKg is in kg.
  static double impulse(double loadKg, double avgAccel, double tut) {
    final force = loadKg * (avgAccel.abs() + 9.81);
    return force * tut;
  }

  /// Estimated %1RM from the SET's mean MCV using population-based load-velocity profile.
  /// Based on linear model from Gonzalez-Badillo et al.
  /// MCV ≈ 1.8 − 0.018 × %1RM → %1RM ≈ (1.8 − MCV) / 0.018
  static double estimated1RMPercent(double setMeanMCV) {
    final percent = ((1.8 - setMeanMCV) / 0.018).clamp(30.0, 100.0);
    return percent;
  }

  /// Estimated 1RM weight in lbs from load (lbs) and the set's mean MCV.
  /// Uses the full set data (mean MCV across all reps) for accuracy.
  static double estimated1RMLbs(double loadLbs, double setMeanMCV) {
    final percent = estimated1RMPercent(setMeanMCV);
    if (percent <= 0) return 0;
    return loadLbs / (percent / 100.0);
  }

  // ─── Personalized Load-Velocity Profile (Linear Regression) ───

  /// Exercise-specific Minimal Velocity Thresholds (m/s).
  /// Based on González-Badillo & Sánchez-Medina (2010) and subsequent research.
  /// The MVT is the average concentric velocity at a true 1RM repetition.
  static const Map<String, double> exerciseMVTs = {
    'back squat':      0.30,
    'squat':           0.30,
    'front squat':     0.30,
    'box squat':       0.25,
    'deadlift':        0.25,
    'romanian deadlift': 0.25,
    'bench press':     0.15,
    'overhead press':  0.17,
    'row':             0.20,
    'pull-up':         0.20,
    'chin-up':         0.20,
    'unspecified':     0.30,
  };

  /// Returns the exercise-specific MVT for a given exercise name.
  /// Defaults to 0.30 m/s if the exercise is not in the table.
  static double mvtForExercise(String exercise) {
    final key = exercise.toLowerCase().trim();
    for (final entry in exerciseMVTs.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return 0.30; // general default
  }

  /// Calculates a personalized Daily 1RM using the Line of Best Fit (Linear Regression).
  ///
  /// Takes a list of [points] where X = Load (in lbs or kg) and Y = Velocity (MCV).
  /// [mvt] is the Minimal Velocity Threshold — the velocity at which the athlete can
  /// no longer complete a rep. Pass [exercise] to auto-look up the correct MVT from
  /// the research-backed [exerciseMVTs] table.
  /// 
  /// Returns the estimated 1RM load, or null if there is not enough variance in the data.
  static double? calculateDaily1RM({
    required List<Point<double>> points,
    String? exercise,
    double? mvt,
  }) {
    // Use exercise-specific MVT from literature if not explicitly overridden
    final double targetMVT = mvt ?? mvtForExercise(exercise ?? 'unspecified');
    if (points.length < 2) return null; // Need at least 2 points for a line

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    final int n = points.length;

    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
      sumXY += p.x * p.y;
      sumX2 += p.x * p.x;
    }

    final double meanX = sumX / n;
    final double meanY = sumY / n;

    // Calculate slope (m)
    // Formula: m = (n*Σxy - Σx*Σy) / (n*Σx^2 - (Σx)^2)
    final double denominator = (n * sumX2) - (sumX * sumX);
    
    // If the denominator is 0, it means all loads were exactly the same (vertical line).
    if (denominator == 0) return null;

    final double m = ((n * sumXY) - (sumX * sumY)) / denominator;

    // A valid LVP should have a negative slope (velocity decreases as load increases)
    if (m >= 0) return null; 

    // Calculate Y-intercept (b)
    // Formula: b = y_mean - m*x_mean
    final double b = meanY - (m * meanX);

    // Calculate 1RM (x) for target velocity (y = MVT)
    // y = mx + b  =>  x = (y - b) / m
    final double predicted1RM = (targetMVT - b) / m;

    return predicted1RM > 0 ? predicted1RM : null;
  }

  /// Suggest next-set load in lbs based on target velocity zone.
  static String suggestedNextLoad({
    required double currentMCV,
    required double loadLbs,
    required VelocityZone targetZone,
  }) {
    final targetMCV = _zoneMidpoint(targetZone);
    if (currentMCV <= 0 || loadLbs <= 0) return 'Insufficient data';

    final percentShift = (currentMCV - targetMCV) / 0.018;
    final suggestedLbs = loadLbs + (percentShift * loadLbs / 100.0);

    if ((suggestedLbs - loadLbs).abs() < 2.5) {
      return 'Keep at ${loadLbs.toStringAsFixed(1)} lbs';
    } else if (suggestedLbs > loadLbs) {
      return 'Increase to ${suggestedLbs.toStringAsFixed(1)} lbs';
    } else {
      return 'Decrease to ${suggestedLbs.toStringAsFixed(1)} lbs';
    }
  }

  static double _zoneMidpoint(VelocityZone zone) {
    switch (zone) {
      case VelocityZone.maxStrength: return 0.35;
      case VelocityZone.strength: return 0.625;
      case VelocityZone.speedStrength: return 0.875;
      case VelocityZone.power: return 1.15;
      case VelocityZone.speed: return 1.5;
    }
  }

  // ─── Set Summary Builder ───

  /// Build a complete SetSummary from a list of reps.
  /// [loadKg] is used for physics (force/power/impulse).
  /// [loadLbs] is used for display (1RM in lbs, suggestions in lbs).
  static SetSummary buildSetSummary(List<RepRecord> reps, {double? loadKg, double? loadLbs, String exercise = 'Unspecified'}) {
    if (reps.isEmpty) {
      return SetSummary(
        reps: [],
        totalReps: 0,
        setDuration: 0,
        totalTUT: 0,
        meanMCV: 0,
        meanPCV: 0,
        bestMCV: 0,
        worstMCV: 0,
        bestRepNumber: 0,
        worstRepNumber: 0,
        velocityLossPercent: 0,
        repVariabilitySD: 0,
        fatigueIndex: 0,
        meanROM: 0,
        meanAvgZAccel: 0,
        meanPeakZAccel: 0,
        timestamp: DateTime.now(),
        exercise: exercise,
      );
    }

    final mcvs = reps.map((r) => r.meanConcentricVelocity).toList();
    final pcvs = reps.map((r) => r.peakConcentricVelocity).toList();

    final bestIdx = mcvs.indexOf(mcvs.reduce(max));
    final worstIdx = mcvs.indexOf(mcvs.reduce(min));

    final setDuration = reps.last.timestamp.difference(reps.first.timestamp).inMilliseconds / 1000.0;
    final totalTUT = reps.map((r) => r.timeUnderTension).reduce((a, b) => a + b);
    final meanMCV = mcvs.reduce((a, b) => a + b) / mcvs.length;
    final meanPCV = pcvs.reduce((a, b) => a + b) / pcvs.length;
    final meanROM = reps.map((r) => r.rangeOfMotion).reduce((a, b) => a + b) / reps.length;
    final meanAvgZAccel = reps.map((r) => r.averageZAcceleration).reduce((a, b) => a + b) / reps.length;
    final meanPeakZAccel = reps.map((r) => r.peakZAcceleration).reduce((a, b) => a + b) / reps.length;

    // Power / 1RM estimates if load provided
    double? estMeanPower;
    double? estPeakPower;
    double? est1RMLbsVal;
    double? imp;
    String? suggestion;

    if (loadKg != null && loadKg > 0 && loadLbs != null && loadLbs > 0) {
      estMeanPower = estimatedMeanPower(loadKg, meanAvgZAccel, meanMCV);
      estPeakPower = estimatedPeakPower(loadKg, meanPeakZAccel, meanPCV);
      // 1RM uses the SET's mean MCV (not a single rep) for accuracy
      est1RMLbsVal = estimated1RMLbs(loadLbs, meanMCV);
      imp = impulse(loadKg, meanAvgZAccel, totalTUT);
      suggestion = suggestedNextLoad(
        currentMCV: meanMCV,
        loadLbs: loadLbs,
        targetZone: velocityZone(meanMCV),
      );
    }

    return SetSummary(
      reps: List.unmodifiable(reps),
      totalReps: reps.length,
      setDuration: setDuration,
      totalTUT: totalTUT,
      meanMCV: meanMCV,
      meanPCV: meanPCV,
      bestMCV: mcvs.reduce(max),
      worstMCV: mcvs.reduce(min),
      bestRepNumber: reps[bestIdx].repNumber,
      worstRepNumber: reps[worstIdx].repNumber,
      velocityLossPercent: velocityLoss(reps),
      repVariabilitySD: repVariability(reps),
      fatigueIndex: MetricsCalculator.fatigueIndex(reps),
      meanROM: meanROM,
      meanAvgZAccel: meanAvgZAccel,
      meanPeakZAccel: meanPeakZAccel,
      timestamp: DateTime.now(),
      exercise: exercise,
      loadLbs: loadLbs,
      estimatedMeanPower: estMeanPower,
      estimatedPeakPower: estPeakPower,
      estimated1RMLbs: est1RMLbsVal,
      impulse: imp,
      suggestedNextLoad: suggestion,
    );
  }

  // ─── Plan Load Suggestion ───────────────────────────────────────────────

  /// Zone-appropriate %1RM intensity targets for workout planning.
  static const Map<String, double> _goalZoneIntensity = {
    'Strength':     0.825, // 82.5% 1RM  (heavy, 3-6 reps)
    'Hypertrophy':  0.700, // 70%   1RM  (moderate, 8-12 reps)
    'Power':        0.600, // 60%   1RM  (fast, explosive)
  };

  /// Suggests a training load (lbs) for a planned movement by:
  /// 1. Scanning [pastWorkouts] for the best estimated 1RM for [exercise]
  /// 2. Applying the [goalZone]-appropriate intensity %
  /// 3. Rounding to the nearest 2.5 lbs
  ///
  /// Returns null if no historical 1RM data exists for that exercise.
  static double? suggestPlanLoad({
    required String exercise,
    required List<dynamic> pastWorkouts, // List<Workout>
    String goalZone = 'Strength',
  }) {
    final exKey = exercise.toLowerCase().trim();
    double best1RM = 0.0;

    // Look through recent workouts for the best 1RM for this exercise
    for (final w in pastWorkouts.take(5)) {
      for (final set in (w.sets as List)) {
        final setExercise = (set.exercise as String? ?? '').toLowerCase().trim();
        if (setExercise != exKey) continue;
        final rm = set.estimated1RMLbs as double?;
        if (rm != null && rm > best1RM) best1RM = rm;
      }
    }

    if (best1RM <= 0) return null;

    final intensity = _goalZoneIntensity[goalZone] ?? 0.825;
    final rawLoad = best1RM * intensity;

    // Round to nearest 2.5 lbs
    return (rawLoad / 2.5).round() * 2.5;
  }
}

