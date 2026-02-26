import '../models/workout.dart';

/// Abstract repository for managing workout data.
/// This interface stays the same — Phase 2 will add a FirestoreWorkoutRepository.
///
/// Why use an abstract class (interface)?
/// It lets us swap implementations without changing the rest of the app.
/// Currently we use InMemoryWorkoutRepository (temporary),
/// and in Phase 2 we'll create FirestoreWorkoutRepository.
abstract class WorkoutRepository {
  Future<void> addWorkout(Workout workout);
  Future<List<Workout>> getWorkoutsByUserId(String userId);
  Future<Workout?> getWorkoutById(String id);
  Future<void> updateWorkout(Workout workout);
  Future<void> deleteWorkout(String id);
  Future<void> clearAllWorkouts();
}

/// Temporary in-memory implementation until Phase 2 (Firestore).
/// Data will NOT persist across app restarts — that's expected for now.
/// Phase 2 replaces this with FirestoreWorkoutRepository.
class HiveWorkoutRepository implements WorkoutRepository {
  final Map<String, Workout> _workouts = {};

  @override
  Future<void> addWorkout(Workout workout) async {
    _workouts[workout.id] = workout;
  }

  @override
  Future<List<Workout>> getWorkoutsByUserId(String userId) async {
    final userWorkouts = _workouts.values
        .where((w) => w.userId == userId)
        .toList();
    userWorkouts.sort((a, b) => b.date.compareTo(a.date));
    return userWorkouts;
  }

  @override
  Future<Workout?> getWorkoutById(String id) async {
    return _workouts[id];
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    _workouts[workout.id] = workout;
  }

  @override
  Future<void> deleteWorkout(String id) async {
    _workouts.remove(id);
  }

  @override
  Future<void> clearAllWorkouts() async {
    _workouts.clear();
  }
}
