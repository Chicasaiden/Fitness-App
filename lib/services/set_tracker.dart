import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ble_metrics.dart';
import '../models/rep_record.dart';
import '../models/set_summary.dart';
import '../services/metrics_calculator.dart';
import 'ble_service.dart';

/// Accumulates per-rep data during a live workout and emits set summaries.
class SetTracker {
  final BleService _bleService;
  StreamSubscription<BleMetrics>? _metricsSub;

  // Current set state
  final List<RepRecord> _currentReps = [];
  int _lastRepNumber = 0;
  double? _loadLbs;
  String _currentExercise = 'Unspecified';
  bool _setCompleteHandled = false;
  bool _isSetActive = true; // false after set ends, until new set starts

  // Preserve last rep for display even after set completion
  RepRecord? _lastCompletedRep;

  // Velocity samples for the CURRENT set only
  final List<VelocitySample> _currentVelocitySamples = [];

  // Completed sets + their velocity samples
  final List<SetSummary> _completedSets = [];
  final List<List<VelocitySample>> _completedSetVelocitySamples = [];
  // Keep reps for completed sets (for clickable bar charts)
  final List<List<RepRecord>> _completedSetReps = [];

  // Streams
  final StreamController<RepRecord> _repController = StreamController.broadcast();
  final StreamController<SetSummary> _setController = StreamController.broadcast();
  final StreamController<VelocitySample> _velocityController = StreamController.broadcast();

  SetTracker(this._bleService);

  /// Current reps in the active set (read-only).
  List<RepRecord> get currentReps => List.unmodifiable(_currentReps);

  /// All completed sets this session.
  List<SetSummary> get completedSets => List.unmodifiable(_completedSets);

  /// Velocity samples for the current set.
  List<VelocitySample> get currentVelocitySamples => List.unmodifiable(_currentVelocitySamples);

  /// Whether a set is currently active (collecting reps).
  bool get isSetActive => _isSetActive;

  /// Last completed rep (persists across set boundaries).
  RepRecord? get lastCompletedRep => _lastCompletedRep;

  /// Get velocity samples for a completed set by index.
  List<VelocitySample> getVelocitySamplesForSet(int index) {
    if (index < 0 || index >= _completedSetVelocitySamples.length) return [];
    return List.unmodifiable(_completedSetVelocitySamples[index]);
  }

  /// Get reps for a completed set by index (for bar charts).
  List<RepRecord> getRepsForSet(int index) {
    if (index < 0 || index >= _completedSetReps.length) return [];
    return List.unmodifiable(_completedSetReps[index]);
  }

  /// Stream of individual rep completions.
  Stream<RepRecord> get repStream => _repController.stream;

  /// Stream of completed set summaries.
  Stream<SetSummary> get setStream => _setController.stream;

  /// Stream of real-time velocity samples.
  Stream<VelocitySample> get velocityStream => _velocityController.stream;

  /// Set the load (lbs) for power/1RM calculations.
  void setLoad(double? lbs) {
    _loadLbs = lbs;
  }

  /// Set the exercise for the current set.
  void setExercise(String exercise) {
    _currentExercise = exercise;
  }

  /// Start tracking. Subscribes to BLE metrics.
  void start() {
    _metricsSub?.cancel();
    _metricsSub = _bleService.metricsStream().listen(_onMetrics);
    _isSetActive = true;
    debugPrint('[SetTracker] Started tracking');
  }

  /// Stop tracking and finalize any in-progress set.
  void stop() {
    _metricsSub?.cancel();
    _metricsSub = null;
    if (_currentReps.isNotEmpty) {
      _finalizeSet();
    }
    debugPrint('[SetTracker] Stopped tracking');
  }

  /// Manually end the current set (triggered by "New Set" button).
  /// Saves current data and prepares for a new set.
  void endCurrentSet() {
    if (_currentReps.isNotEmpty) {
      _finalizeSet();
    }
    // Prepare for new set
    _isSetActive = true;
    _setCompleteHandled = false;
    debugPrint('[SetTracker] Manual set end — ready for new set');
  }

  void _onMetrics(BleMetrics metrics) {
    // Track real-time velocity samples (only during active set)
    if (metrics.currentVelocity != null && _isSetActive) {
      final sample = VelocitySample(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        velocity: metrics.currentVelocity!,
      );
      _currentVelocitySamples.add(sample);
      _velocityController.add(sample);
    }

    // Only process if this is a genuine new rep
    if (metrics.repNumber > 0 && metrics.repNumber != _lastRepNumber) {
      _lastRepNumber = metrics.repNumber;
      _setCompleteHandled = false;
      _isSetActive = true; // receiving reps means set is active

      final rep = RepRecord.fromMetrics(metrics);
      _currentReps.add(rep);
      _lastCompletedRep = rep;
      _repController.add(rep);
      debugPrint('[SetTracker] Rep ${rep.repNumber}: MCV=${rep.meanConcentricVelocity.toStringAsFixed(3)} m/s');
    }

    // Check for set completion (only once per set)
    if (metrics.isSetComplete && _currentReps.isNotEmpty && !_setCompleteHandled) {
      _setCompleteHandled = true;
      _finalizeSet();
    }
  }

  void _finalizeSet() {
    final loadKg = _loadLbs != null ? _loadLbs! * 0.453592 : null;
    final summary = MetricsCalculator.buildSetSummary(
      _currentReps,
      loadKg: loadKg,
      loadLbs: _loadLbs,
      exercise: _currentExercise,
    );
    _completedSets.add(summary);
    _completedSetVelocitySamples.add(List.from(_currentVelocitySamples));
    _completedSetReps.add(List.from(_currentReps));
    _setController.add(summary);

    _isSetActive = false; // set is done — velocity curve freezes
    debugPrint('[SetTracker] Set complete: ${summary.totalReps} reps, '
        'MCV=${summary.meanMCV.toStringAsFixed(3)} m/s, '
        'Vloss=${summary.velocityLossPercent.toStringAsFixed(1)}%');

    // Clear current set data for next set
    _currentReps.clear();
    _currentVelocitySamples.clear();
  }

  /// Reset all state (new workout session).
  void reset() {
    _metricsSub?.cancel();
    _metricsSub = null;
    _currentReps.clear();
    _completedSets.clear();
    _completedSetVelocitySamples.clear();
    _completedSetReps.clear();
    _currentVelocitySamples.clear();
    _lastRepNumber = 0;
    _loadLbs = null;
    _currentExercise = 'Unspecified';
    _lastCompletedRep = null;
    _setCompleteHandled = false;
    _isSetActive = true;
  }

  void dispose() {
    _metricsSub?.cancel();
    _repController.close();
    _setController.close();
    _velocityController.close();
  }
}

/// A single velocity measurement with timestamp for plotting.
class VelocitySample {
  final int timestampMs;
  final double velocity; // m/s

  VelocitySample({required this.timestampMs, required this.velocity});
}
