import 'package:hive/hive.dart';
import '../models/workout.dart';

/// Abstract repository for managing workout data
abstract class WorkoutRepository {
  Future<void> addWorkout(Workout workout);
  Future<List<Workout>> getWorkoutsByUserId(String userId);
  Future<Workout?> getWorkoutById(String id);
  Future<void> updateWorkout(Workout workout);
  Future<void> deleteWorkout(String id);
  Future<void> clearAllWorkouts();
}

/// Hive-based implementation of WorkoutRepository
class HiveWorkoutRepository implements WorkoutRepository {
  static const String _boxName = 'workouts';
  late Box<Map> _workoutBox;

  /// Initialize the Hive box
  Future<void> init() async {
    _workoutBox = await Hive.openBox<Map>(_boxName);
  }

  @override
  Future<void> addWorkout(Workout workout) async {
    await _workoutBox.put(workout.id, workout.toJson());
  }

  @override
  Future<List<Workout>> getWorkoutsByUserId(String userId) async {
    final allWorkouts = _workoutBox.values
        .map((json) => Workout.fromJson(Map<String, dynamic>.from(json)))
        .where((w) => w.userId == userId)
        .toList();

    // Sort by date descending (newest first)
    allWorkouts.sort((a, b) => b.date.compareTo(a.date));
    return allWorkouts;
  }

  @override
  Future<Workout?> getWorkoutById(String id) async {
    final json = _workoutBox.get(id);
    if (json == null) return null;
    return Workout.fromJson(Map<String, dynamic>.from(json));
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    await _workoutBox.put(workout.id, workout.toJson());
  }

  @override
  Future<void> deleteWorkout(String id) async {
    await _workoutBox.delete(id);
  }

  @override
  Future<void> clearAllWorkouts() async {
    await _workoutBox.clear();
  }
}
