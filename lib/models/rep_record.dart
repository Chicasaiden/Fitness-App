import '../ble_metrics.dart';

/// A single rep's data snapshot, timestamped when received from the Arduino.
class RepRecord {
  final int repNumber;
  final double meanConcentricVelocity; // m/s
  final double peakConcentricVelocity; // m/s
  final double timeUnderTension; // seconds
  final double rangeOfMotion; // meters
  final double averageZAcceleration; // m/s²
  final double peakZAcceleration; // m/s²
  final DateTime timestamp;

  RepRecord({
    required this.repNumber,
    required this.meanConcentricVelocity,
    required this.peakConcentricVelocity,
    required this.timeUnderTension,
    required this.rangeOfMotion,
    required this.averageZAcceleration,
    required this.peakZAcceleration,
    required this.timestamp,
  });

  /// Create from a BleMetrics snapshot.
  factory RepRecord.fromMetrics(BleMetrics metrics) {
    return RepRecord(
      repNumber: metrics.repNumber,
      meanConcentricVelocity: metrics.meanConcentricVelocity,
      peakConcentricVelocity: metrics.peakConcentricVelocity,
      timeUnderTension: metrics.timeUnderTension,
      rangeOfMotion: metrics.rangeOfMotion,
      averageZAcceleration: metrics.averageZAcceleration,
      peakZAcceleration: metrics.peakZAcceleration,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'repNumber': repNumber,
    'meanConcentricVelocity': meanConcentricVelocity,
    'peakConcentricVelocity': peakConcentricVelocity,
    'timeUnderTension': timeUnderTension,
    'rangeOfMotion': rangeOfMotion,
    'averageZAcceleration': averageZAcceleration,
    'peakZAcceleration': peakZAcceleration,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RepRecord.fromJson(Map<String, dynamic> json) => RepRecord(
    repNumber: json['repNumber'] as int,
    meanConcentricVelocity: (json['meanConcentricVelocity'] as num).toDouble(),
    peakConcentricVelocity: (json['peakConcentricVelocity'] as num).toDouble(),
    timeUnderTension: (json['timeUnderTension'] as num).toDouble(),
    rangeOfMotion: (json['rangeOfMotion'] as num).toDouble(),
    averageZAcceleration: (json['averageZAcceleration'] as num).toDouble(),
    peakZAcceleration: (json['peakZAcceleration'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
