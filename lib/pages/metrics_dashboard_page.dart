import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import '../services/set_tracker.dart';
import '../services/metrics_calculator.dart';
import '../models/rep_record.dart';
import '../models/set_summary.dart';
import '../ble_metrics.dart';
import '../repositories/workout_repository.dart';
import '../models/workout.dart';

class MetricsDashboardPage extends StatefulWidget {
  final BleService bleService;
  final SetTracker setTracker;
  final WorkoutRepository workoutRepository;
  final String userId;

  const MetricsDashboardPage({
    super.key,
    required this.bleService,
    required this.setTracker,
    required this.workoutRepository,
    required this.userId,
  });

  @override
  State<MetricsDashboardPage> createState() => _MetricsDashboardPageState();
}

class _MetricsDashboardPageState extends State<MetricsDashboardPage> {
  StreamSubscription<RepRecord>? _repSub;
  StreamSubscription<SetSummary>? _setSub;
  StreamSubscription<VelocitySample>? _velocitySub;
  StreamSubscription<BleMetrics>? _metricsSub;

  // Live state
  BleMetrics? _latestMetrics;

  // Rep selection: which rep is displayed in the detail card
  // null = show latest rep automatically
  int? _selectedRepIndex;

  // Historical set viewing: null = live / current set, otherwise index into completedSets
  int? _viewingSetIndex;

  // Velocity data for live display
  final List<VelocitySample> _liveVelocityData = [];

  // Load input (lbs)
  final TextEditingController _loadController = TextEditingController();
  double? _loadLbs;

  // Exercise selection
  String _selectedExercise = 'Squat';
  static const List<String> _exercises = [
    'Squat', 'Front Squat', 'Bench Press', 'Incline Bench',
    'Overhead Press', 'Deadlift', 'Romanian Deadlift',
    'Barbell Row', 'Hip Thrust', 'Power Clean',
    'Push Press', 'Lunges', 'Custom',
  ];

  // Rep velocity flash feedback
  Color? _repFlashColor;
  bool _showRepFlash = false;

  // Past workouts
  List<Workout> _pastWorkouts = [];

  // Exercise filter for trends
  String _trendExerciseFilter = 'All';

  @override
  void initState() {
    super.initState();
    widget.setTracker.start();
    _setupListeners();
    _loadPastWorkouts();
  }

  void _setupListeners() {
    _repSub = widget.setTracker.repStream.listen((rep) {
      setState(() {
        // Flash the velocity number green or red
        final reps = widget.setTracker.currentReps;
        if (reps.length >= 2) {
          final avgSoFar = reps.take(reps.length - 1)
              .map((r) => r.meanConcentricVelocity)
              .reduce((a, b) => a + b) / (reps.length - 1);
          _repFlashColor = rep.meanConcentricVelocity >= avgSoFar
              ? Colors.green
              : Colors.red;
        } else {
          _repFlashColor = Colors.green; // First rep is always "good"
        }
        _showRepFlash = true;
      });
      // Clear flash after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showRepFlash = false);
      });
    });

    _setSub = widget.setTracker.setStream.listen((_) {
      setState(() {
        // Set completed — stay on current view
      });
    });

    _velocitySub = widget.setTracker.velocityStream.listen((sample) {
      setState(() {
        _liveVelocityData.add(sample);
        if (_liveVelocityData.length > 500) {
          _liveVelocityData.removeAt(0);
        }
      });
    });

    _metricsSub = widget.bleService.metricsStream().listen((m) {
      setState(() {
        _latestMetrics = m;
      });
    });
  }

  Future<void> _loadPastWorkouts() async {
    final workouts = await widget.workoutRepository.getWorkoutsByUserId(widget.userId);
    setState(() {
      _pastWorkouts = workouts;
    });
  }

  void _onLoadChanged(String value) {
    final lbs = double.tryParse(value);
    setState(() { _loadLbs = lbs; });
    widget.setTracker.setLoad(lbs);
  }

  void _onEndSetPressed() {
  void _onEndSetPressed() {
    widget.setTracker.endCurrentSet();
    setState(() {
      _selectedRepIndex = null;
      _viewingSetIndex = null;
      _liveVelocityData.clear();
      _latestMetrics = null;
    });
    
    // Optional tactile feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Set Ended', style: TextStyle(fontWeight: FontWeight.w600)),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  }

  void _onFinishWorkout() async {
    // End any active set
    widget.setTracker.endCurrentSet();

    final sets = widget.setTracker.completedSets;
    if (sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sets completed to save.')),
      );
      Navigator.pop(context);
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Calculate session aggregates
      final durationSeconds = sets.fold<double>(0, (sum, s) => sum + s.setDuration);
      final totalTUT = sets.fold<double>(0, (sum, s) => sum + s.totalTUT);
      final avgROM = sets.fold<double>(0, (sum, s) => sum + s.meanROM) / sets.length;
      final avgZAccel = sets.fold<double>(0, (sum, s) => sum + s.meanAvgZAccel) / sets.length;
      final peakZAccel = sets.fold<double>(0.0, (maxA, s) => s.meanPeakZAccel > maxA ? s.meanPeakZAccel : maxA);
      
      final mcvs = sets.expand((s) => s.reps.map((r) => r.meanConcentricVelocity)).toList();
      final overallMeanMCV = mcvs.isNotEmpty ? mcvs.reduce((a, b) => a + b) / mcvs.length : 0.0;
      
      final pcvs = sets.expand((s) => s.reps.map((r) => r.peakConcentricVelocity)).toList();
      final overallPeakPCV = pcvs.isNotEmpty ? pcvs.reduce((a, b) => a > b ? a : b) : 0.0;

      // Create new workout
      final workout = Workout(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: widget.userId,
        date: DateTime.now(),
        duration: durationSeconds,
        meanConcentricVelocity: overallMeanMCV,
        peakConcentricVelocity: overallPeakPCV,
        timeUnderTension: totalTUT,
        rangeOfMotion: avgROM,
        averageZAcceleration: avgZAccel,
        peakZAcceleration: peakZAccel,
        sets: sets,
      );

      // Save to repo
      await widget.workoutRepository.addWorkout(workout);

      if (mounted) {
        Navigator.pop(context); // pop loading
        Navigator.pop(context); // pop training screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved successfully! 🏋️‍♂️')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving workout: $e')),
        );
      }
    }
  }

  void _onRepBarTapped(int index) {
    setState(() {
      _selectedRepIndex = index;
    });
  }

  void _onSessionHistoryTapped(int setIndex) {
    setState(() {
      _viewingSetIndex = setIndex;
      _selectedRepIndex = null; // reset rep selection when switching sets
    });
  }

  void _onBackToLive() {
    setState(() {
      _viewingSetIndex = null;
      _selectedRepIndex = null;
    });
  }

  /// Get the reps to display in the bar chart (current set or historical).
  List<RepRecord> get _displayReps {
    if (_viewingSetIndex != null) {
      return widget.setTracker.getRepsForSet(_viewingSetIndex!);
    }
    // Show current reps, or if set just ended and no new reps yet,
    // show the last completed set's reps
    final current = widget.setTracker.currentReps;
    if (current.isNotEmpty) return current;
    // Set just ended — show last completed set's reps
    final sets = widget.setTracker.completedSets;
    if (sets.isNotEmpty) {
      return widget.setTracker.getRepsForSet(sets.length - 1);
    }
    return [];
  }

  /// Get the velocity samples to display in the curve.
  List<VelocitySample> get _displayVelocitySamples {
    if (_viewingSetIndex != null) {
      return widget.setTracker.getVelocitySamplesForSet(_viewingSetIndex!);
    }
    // Live: show current samples, or last completed set's samples if set just ended
    if (widget.setTracker.isSetActive || _liveVelocityData.isNotEmpty) {
      return _liveVelocityData;
    }
    final sets = widget.setTracker.completedSets;
    if (sets.isNotEmpty) {
      return widget.setTracker.getVelocitySamplesForSet(sets.length - 1);
    }
    return [];
  }

  /// Get the set summary to display.
  SetSummary? get _displaySetSummary {
    if (_viewingSetIndex != null) {
      final sets = widget.setTracker.completedSets;
      if (_viewingSetIndex! < sets.length) return sets[_viewingSetIndex!];
    }
    // If current set is empty and we have completed sets, show the last one
    final sets = widget.setTracker.completedSets;
    if (widget.setTracker.currentReps.isEmpty && sets.isNotEmpty) {
      return sets.last;
    }
    return null;
  }

  /// Get the selected rep for the detail card.
  RepRecord? get _displayRep {
    final reps = _displayReps;
    if (_selectedRepIndex != null && _selectedRepIndex! < reps.length) {
      return reps[_selectedRepIndex!];
    }
    // Auto: show latest rep
    if (reps.isNotEmpty) return reps.last;
    return widget.setTracker.lastCompletedRep;
  }

  @override
  void dispose() {
    _repSub?.cancel();
    _setSub?.cancel();
    _velocitySub?.cancel();
    _metricsSub?.cancel();
    _loadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _displaySetSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Exercise Dropdown
            _buildExerciseRow(),
            const SizedBox(height: 12),
            // Load Input + New Set button
            _buildLoadAndNewSetRow(),
            const SizedBox(height: 16),

            // Viewing historical set banner
            if (_viewingSetIndex != null) ...[
              _buildHistoricalBanner(),
              const SizedBox(height: 16),
            ],

            // Current Velocity & Training Zone
            _buildCurrentVelocityCard(),
            const SizedBox(height: 16),

            // Current Set (bar chart — clickable reps) — ABOVE latest rep
            _buildSetBarChart(),
            const SizedBox(height: 16),

            // Selected Rep Detail
            _buildRepDetailCard(),
            const SizedBox(height: 16),

            // Velocity Curve (per-set, freezes when set ends)
            _buildVelocityCurveCard(),
            const SizedBox(height: 16),

            // Set Summary
            if (summary != null) ...[
              _buildSetSummaryCard(summary),
              const SizedBox(height: 16),
            ],

            // Power, Strength & Fatigue Estimates
            if (summary != null) ...[
              _buildPowerEstimatesCard(summary),
              const SizedBox(height: 16),
            ],

            // Session History (clickable)
            if (widget.setTracker.completedSets.isNotEmpty) ...[
              _buildSessionHistoryCard(),
              const SizedBox(height: 16),
            ],

            // Workout Trends
            if (_pastWorkouts.isNotEmpty) ...[
              _buildTrendsCard(),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onFinishWorkout,
                icon: const Icon(Icons.check_circle, size: 22),
                label: const Text('Finish Workout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Exercise Dropdown Row ───
  Widget _buildExerciseRow() {
    return _buildCard(
      child: Row(
        children: [
          Icon(Icons.sports_gymnastics, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          const Text('Exercise:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedExercise,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _exercises.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) {
                // Auto-end the current set BEFORE changing the exercise
                // so previous reps don't get mislabeled.
                widget.setTracker.endCurrentSet();
                setState(() {
                  _selectedExercise = v!;
                  _selectedRepIndex = null;
                  _viewingSetIndex = null;
                  _liveVelocityData.clear();
                  _latestMetrics = null;
                });
                widget.setTracker.setExercise(v!);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Load Input + New Set Button ───
  Widget _buildLoadAndNewSetRow() {
    return _buildCard(
      child: Row(
        children: [
          Icon(Icons.fitness_center, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          const Text('Load:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _loadController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                // Auto-end current set on load change
                widget.setTracker.endCurrentSet();
                _onLoadChanged(val);
                setState(() {
                  _selectedRepIndex = null;
                  _viewingSetIndex = null;
                  _liveVelocityData.clear();
                  _latestMetrics = null;
                });
              },
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'lbs',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: widget.setTracker.isSetActive ? _onEndSetPressed : null,
            icon: const Icon(Icons.stop_circle_outlined, size: 16),
            label: const Text('End Set'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Historical Set Banner ───
  Widget _buildHistoricalBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: Colors.blue.shade600, size: 18),
          const SizedBox(width: 8),
          Text('Viewing Set ${_viewingSetIndex! + 1}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
          const Spacer(),
          GestureDetector(
            onTap: _onBackToLive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Back to Live', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Current Velocity & Zone ───
  Widget _buildCurrentVelocityCard() {
    final vz = _latestMetrics?.currentVelocity;
    final mcv = _latestMetrics?.meanConcentricVelocity ?? 0.0;
    final zone = MetricsCalculator.velocityZone(mcv);
    final zoneColor = Color(MetricsCalculator.zoneColorValue(zone));

    // If viewing historical, show set's mean MCV zone
    final displayMCV = _viewingSetIndex != null ? (_displaySetSummary?.meanMCV ?? 0.0) : mcv;
    final displayZone = MetricsCalculator.velocityZone(displayMCV);
    final displayZoneColor = Color(MetricsCalculator.zoneColorValue(displayZone));

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_viewingSetIndex != null ? 'Set Velocity Zone' : 'Current Velocity',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: displayZoneColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: displayZoneColor.withOpacity(0.4)),
                ),
                child: Text(MetricsCalculator.zoneLabel(displayZone),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: displayZoneColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _viewingSetIndex != null
                    ? displayMCV.toStringAsFixed(3)
                    : (vz != null ? vz.toStringAsFixed(3) : '--'),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _showRepFlash && _viewingSetIndex == null
                      ? (_repFlashColor ?? Colors.black87)
                      : Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Text('m/s', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 8),
          _buildZoneBar(),
        ],
      ),
    );
  }

  Widget _buildZoneBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                _zoneSegment(VelocityZone.maxStrength),
                _zoneSegment(VelocityZone.strength),
                _zoneSegment(VelocityZone.speedStrength),
                _zoneSegment(VelocityZone.power),
                _zoneSegment(VelocityZone.speed),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['0', '0.5', '0.75', '1.0', '1.3', '1.8+']
              .map((t) => Text(t, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)))
              .toList(),
        ),
      ],
    );
  }

  Widget _zoneSegment(VelocityZone zone) {
    return Expanded(child: Container(color: Color(MetricsCalculator.zoneColorValue(zone))));
  }

  // ─── Set Bar Chart (clickable reps) ───
  Widget _buildSetBarChart() {
    final reps = _displayReps;
    final isLive = _viewingSetIndex == null && widget.setTracker.isSetActive;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_viewingSetIndex != null ? 'Set ${_viewingSetIndex! + 1}' : 'Current Set',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
              if (isLive) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
              ],
              const Spacer(),
              Text(reps.isEmpty ? 'No reps' : '${reps.length} reps',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          if (reps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No reps yet — start lifting!',
                    style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
              ),
            )
          else
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: reps.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final maxMCV = reps.map((r) => r.meanConcentricVelocity).reduce((a, b) => a > b ? a : b);
                  final ratio = maxMCV > 0 ? r.meanConcentricVelocity / maxMCV : 0.0;
                  final zone = MetricsCalculator.velocityZone(r.meanConcentricVelocity);
                  final isSelected = _selectedRepIndex == idx;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onRepBarTapped(idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(r.meanConcentricVelocity.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected ? Colors.black : Colors.grey.shade700,
                                )),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 50 * ratio,
                              decoration: BoxDecoration(
                                color: Color(MetricsCalculator.zoneColorValue(zone)),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                border: isSelected
                                    ? Border.all(color: Colors.black87, width: 2)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('R${r.repNumber}',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400,
                                  color: isSelected ? Colors.black : Colors.grey.shade500,
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87)),
      ],
    );
  }

  // ─── Rep Detail Card (shows selected or latest rep) ───
  Widget _buildRepDetailCard() {
    final rep = _displayRep;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _selectedRepIndex != null ? 'Rep Detail' : 'Latest Rep',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
              const Spacer(),
              if (rep != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                  child: Text('Rep #${rep.repNumber}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),

            ],
          ),
          const SizedBox(height: 12),
          if (rep == null)
            Text('Waiting for first rep...', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
          else
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _metricMini('MCV', rep.meanConcentricVelocity.toStringAsFixed(3), 'm/s'),
                _metricMini('PCV', rep.peakConcentricVelocity.toStringAsFixed(3), 'm/s'),
                _metricMini('TUT', rep.timeUnderTension.toStringAsFixed(2), 's'),
                _metricMini('ROM', (rep.rangeOfMotion * 100).toStringAsFixed(1), 'cm'),
                _metricMini('Avg Accel', rep.averageZAcceleration.toStringAsFixed(2), 'm/s²'),
                _metricMini('Peak Accel', rep.peakZAcceleration.toStringAsFixed(2), 'm/s²'),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Velocity Curve (per-set, freezes when set ends) ───
  Widget _buildVelocityCurveCard() {
    final samples = _displayVelocitySamples;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Velocity Curve', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
              const Spacer(),
              if (!widget.setTracker.isSetActive && _viewingSetIndex == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Text('Frozen', style: TextStyle(fontSize: 9, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: samples.length > 2
                ? CustomPaint(size: Size.infinite, painter: _VelocityCurvePainter(samples))
                : Center(
                    child: Text('Waiting for velocity data...',
                        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13)),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── PR Detection ───
  Map<String, bool> _detectPRs(SetSummary s) {
    final prs = <String, bool>{'mcv': false, 'pcv': false, 'rom': false};
    // Collect all set MCVs from past workouts
    double bestMCV = 0, bestPCV = 0, bestROM = 0;
    for (final w in _pastWorkouts) {
      for (final set in w.sets) {
        if (set.bestMCV > bestMCV) bestMCV = set.bestMCV;
        if (set.meanPCV > bestPCV) bestPCV = set.meanPCV;
        if (set.meanROM > bestROM) bestROM = set.meanROM;
      }
    }
    // Also check completed sets from current session
    for (final set in widget.setTracker.completedSets) {
      if (set != s) {
        if (set.bestMCV > bestMCV) bestMCV = set.bestMCV;
        if (set.meanPCV > bestPCV) bestPCV = set.meanPCV;
        if (set.meanROM > bestROM) bestROM = set.meanROM;
      }
    }
    prs['mcv'] = s.bestMCV > bestMCV && bestMCV > 0;
    prs['pcv'] = s.meanPCV > bestPCV && bestPCV > 0;
    prs['rom'] = s.meanROM > bestROM && bestROM > 0;
    return prs;
  }

  // ─── Trend Arrows ───
  /// Returns a map of metric name → % change vs average of last 5 workouts.
  Map<String, double> _computeTrends(SetSummary s) {
    final trends = <String, double>{};
    if (_pastWorkouts.isEmpty) return trends;
    final recent = _pastWorkouts.take(5).toList();
    final avgMCV = recent.map((w) => w.meanConcentricVelocity).reduce((a, b) => a + b) / recent.length;
    final avgPCV = recent.map((w) => w.peakConcentricVelocity).reduce((a, b) => a + b) / recent.length;
    if (avgMCV > 0) trends['MCV'] = (s.meanMCV - avgMCV) / avgMCV * 100;
    if (avgPCV > 0) trends['PCV'] = (s.meanPCV - avgPCV) / avgPCV * 100;
    return trends;
  }

  Widget _prBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: const Text('🏆 PR!', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  Widget _trendArrow(double change) {
    final isUp = change >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10, color: isUp ? Colors.green : Colors.red),
        Text('${change.abs().toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isUp ? Colors.green : Colors.red)),
      ],
    );
  }

  /// Enhanced metric mini with optional PR badge, trend arrow, and subtitle
  Widget _metricMiniEnhanced(String title, String value, String unit, {bool isPR = false, double? trend, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isPR ? Colors.amber.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPR ? Colors.amber.shade300 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
              if (isPR) _prBadge(),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
          ],
          if (trend != null) _trendArrow(trend),
        ],
      ),
    );
  }

  // ─── Set Summary ───
  Widget _buildSetSummaryCard(SetSummary s) {
    final prs = _detectPRs(s);
    final trends = _computeTrends(s);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Set Summary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
              if (prs.values.any((v) => v)) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('🏆 New PR!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${s.totalReps} reps',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1, // Adjusted from 1.4 to prevent overflow
            children: [
              _metricMiniEnhanced('Mean MCV', s.meanMCV.toStringAsFixed(3), 'm/s', trend: trends['MCV']),
              _metricMiniEnhanced('Mean PCV', s.meanPCV.toStringAsFixed(3), 'm/s', isPR: prs['pcv']!, trend: trends['PCV']),
              _metricMini('Total TUT', s.totalTUT.toStringAsFixed(1), 's'),
              _metricMiniEnhanced('Best MCV', s.bestMCV.toStringAsFixed(3), 'm/s (R${s.bestRepNumber})', isPR: prs['mcv']!),
              _metricMini('Worst MCV', s.worstMCV.toStringAsFixed(3), 'm/s (R${s.worstRepNumber})'),
              _metricMini('Set Duration', s.setDuration.toStringAsFixed(1), 's'),
              _metricMiniEnhanced('Mean ROM', (s.meanROM * 100).toStringAsFixed(1), 'cm', isPR: prs['rom']!),
              _metricMini('Mean Accel', s.meanAvgZAccel.toStringAsFixed(2), 'm/s²'),
              _metricMini('Peak Accel', s.meanPeakZAccel.toStringAsFixed(2), 'm/s²'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Power, Strength & Fatigue ───
  Widget _buildPowerEstimatesCard(SetSummary s) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Power & Strength Estimates', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 12),
          // V-Loss and Fatigue (always shown)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.8, // Adjusted from 2.2 to accommodate subtitle
            children: [
              _metricMiniEnhanced('V-Loss', s.velocityLossPercent.toStringAsFixed(1), '%', 
                                  subtitle: s.reps.length >= 2 ? '${s.reps.first.meanConcentricVelocity.toStringAsFixed(2)} → ${s.reps.last.meanConcentricVelocity.toStringAsFixed(2)} m/s' : null),
              _metricMini('Fatigue', s.fatigueIndex.toStringAsFixed(0), '/100'),
            ],
          ),
          // Power / 1RM estimates (only if load was entered)
          if (s.loadLbs != null && s.estimated1RMLbs != null) ...[
            const SizedBox(height: 8),
            Text('Based on ${s.loadLbs!.toStringAsFixed(1)} lbs • Set mean MCV',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1, // Adjusted from 1.4
              children: [
                _metricMini('Est. 1RM', s.estimated1RMLbs!.toStringAsFixed(1), 'lbs'),
                _metricMini('Mean Power', s.estimatedMeanPower?.toStringAsFixed(0) ?? '--', 'W'),
                _metricMini('Peak Power', s.estimatedPeakPower?.toStringAsFixed(0) ?? '--', 'W'),
                _metricMini('Impulse', s.impulse?.toStringAsFixed(1) ?? '--', 'N·s'),
              ],
            ),
          ],
          if (s.suggestedNextLoad != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Next set: ${s.suggestedNextLoad}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Session History (clickable sets) ───
  Widget _buildSessionHistoryCard() {
    final sets = widget.setTracker.completedSets;
    
    // Group sets by exercise while retaining their absolute index for selection
    final groupedSets = <String, List<MapEntry<int, SetSummary>>>{};
    for (int i = 0; i < sets.length; i++) {
      final s = sets[i];
      final ex = s.exercise == 'Unspecified' ? 'Mixed Workout' : s.exercise;
      if (!groupedSets.containsKey(ex)) {
        groupedSets[ex] = [];
      }
      groupedSets[ex]!.add(MapEntry(i, s));
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session History (${sets.length} sets)',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 12),
          ...groupedSets.entries.expand((group) {
            final exerciseName = group.key;
            final entries = group.value;

            return [
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
                child: Text(
                  exerciseName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
              ),
              ...entries.asMap().entries.map((relativeEntry) {
                final relativeIdx = relativeEntry.key;
                final absoluteIdx = relativeEntry.value.key;
                final s = relativeEntry.value.value;
                final isViewing = _viewingSetIndex == absoluteIdx;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _onSessionHistoryTapped(absoluteIdx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isViewing ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isViewing ? Colors.blue.shade400 : Colors.grey.shade200, width: isViewing ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isViewing ? Colors.blue.shade600 : Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text('${relativeIdx + 1}', // Show set 1, 2, 3 per exercise
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${s.totalReps} reps • MCV: ${s.meanMCV.toStringAsFixed(2)} m/s',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(
                                  'V-Loss: ${s.velocityLossPercent.toStringAsFixed(1)}% • Fatigue: ${s.fatigueIndex.toStringAsFixed(0)}/100'
                                  '${s.estimated1RMLbs != null ? ' • 1RM: ${s.estimated1RMLbs!.toStringAsFixed(0)} lbs' : ''}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ];
          }).toList(),
        ],
      ),
    );
  }

  // ─── Workout Trends ───
  Widget _buildTrendsCard() {
    // Filter workouts by exercise if filter is active
    final filteredWorkouts = _trendExerciseFilter == 'All'
        ? _pastWorkouts
        : _pastWorkouts.where((w) =>
            w.sets.any((s) => s.exercise == _trendExerciseFilter)
          ).toList();

    // Collect all unique exercises from past workouts
    final exercises = <String>{'All'};
    for (final w in _pastWorkouts) {
      for (final s in w.sets) {
        if (s.exercise != 'Unspecified') exercises.add(s.exercise);
      }
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Workout Trends', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
              const Spacer(),
              if (exercises.length > 1)
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    value: _trendExerciseFilter,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                    items: exercises.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 11)))).toList(),
                    onChanged: (v) => setState(() => _trendExerciseFilter = v!),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: filteredWorkouts.length > 1
                ? CustomPaint(size: Size.infinite, painter: _TrendChartPainter(filteredWorkouts))
                : Center(
                    child: Text('Need at least 2 workouts for trends',
                        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13)),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.blue, 'MCV'),
              const SizedBox(width: 16),
              _legendDot(Colors.orange, 'PCV'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  // ─── Reusable Components ───
  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _metricMini(String title, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Velocity Curve Painter ───
class _VelocityCurvePainter extends CustomPainter {
  final List<VelocitySample> samples;
  _VelocityCurvePainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    // Filter out leading idle samples (near-zero velocity)
    const double movementThreshold = 0.05; // m/s (increased from 0.01 to ignore sensor noise)
    int startIdx = 0;
    for (int i = 0; i < samples.length; i++) {
      if (samples[i].velocity.abs() > movementThreshold) {
        startIdx = i;
        break;
      }
    }

    // Filter out trailing idle samples (flat tail after set ends)
    int endIdx = samples.length - 1;
    for (int i = samples.length - 1; i >= startIdx; i--) {
      if (samples[i].velocity.abs() > movementThreshold) {
        endIdx = i;
        break;
      }
    }

    final activeSamples = samples.sublist(startIdx, endIdx + 1);
    if (activeSamples.length < 2) return;

    final minT = activeSamples.first.timestampMs.toDouble();
    final maxT = activeSamples.last.timestampMs.toDouble();
    final timeRange = maxT - minT;
    if (timeRange <= 0) return;

    double minV = double.infinity, maxV = double.negativeInfinity;
    for (final s in activeSamples) {
      if (s.velocity < minV) minV = s.velocity;
      if (s.velocity > maxV) maxV = s.velocity;
    }
    final vRange = (maxV - minV).clamp(0.1, double.infinity);

    final gridPaint = Paint()..color = const Color(0xFFE0E0E0)..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (minV < 0 && maxV > 0) {
      final zeroY = size.height - ((0 - minV) / vRange) * size.height;
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY),
          Paint()..color = const Color(0xFFBDBDBD)..strokeWidth = 1);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF1E88E5)..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    final path = ui.Path();
    for (int i = 0; i < activeSamples.length; i++) {
      final x = ((activeSamples[i].timestampMs - minT) / timeRange) * size.width;
      final y = size.height - ((activeSamples[i].velocity - minV) / vRange) * size.height;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, linePaint);

    final lastX = size.width;
    final lastY = size.height - ((activeSamples.last.velocity - minV) / vRange) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = const Color(0xFF1E88E5));
  }

  @override
  bool shouldRepaint(covariant _VelocityCurvePainter old) => true;
}

// ─── Trend Chart Painter ───
class _TrendChartPainter extends CustomPainter {
  final List<Workout> workouts;
  _TrendChartPainter(this.workouts);

  @override
  void paint(Canvas canvas, Size size) {
    if (workouts.length < 2) return;
    final mcvs = workouts.reversed.map((w) => w.meanConcentricVelocity).toList();
    final pcvs = workouts.reversed.map((w) => w.peakConcentricVelocity).toList();
    _drawLine(canvas, size, mcvs, const Color(0xFF1E88E5));
    _drawLine(canvas, size, pcvs, const Color(0xFFFB8C00));
  }

  void _drawLine(Canvas canvas, Size size, List<double> values, Color color) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).clamp(0.1, double.infinity);

    final paint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = ui.Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * (size.height * 0.8) - size.height * 0.1;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = color;
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * (size.height * 0.8) - size.height * 0.1;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) => true;
}
