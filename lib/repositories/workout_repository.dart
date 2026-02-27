import '../models/workout.dart';

/// Abstract repository for managing workout data.
///
/// This is an INTERFACE (abstract class in Dart). It defines WHAT methods
/// exist without specifying HOW they work. The actual implementation is
/// in FirestoreWorkoutRepository.
///
/// Why? Because any page that uses WorkoutRepository doesn't need to know
/// whether data is in Firestore, a local database, or memory — it just
/// calls the same methods. This is called "programming to an interface."
abstract class WorkoutRepository {
  Future<void> addWorkout(Workout workout);
  Future<List<Workout>> getWorkoutsByUserId(String userId);
  Future<Workout?> getWorkoutById(String id);
  Future<void> updateWorkout(Workout workout);
  Future<void> deleteWorkout(String id);
  Future<void> clearAllWorkouts();
}
