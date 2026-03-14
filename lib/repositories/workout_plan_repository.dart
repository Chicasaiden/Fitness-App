import '../models/workout_plan.dart';

/// Abstract interface for reading and writing daily workout plans.
abstract class WorkoutPlanRepository {
  /// Save or overwrite a plan for a given day.
  Future<void> savePlan(WorkoutPlan plan);

  /// Get the plan for a specific date, or null if none exists.
  Future<WorkoutPlan?> getPlanForDate(String userId, DateTime date);

  /// Get all plans for a user, sorted newest first.
  Future<List<WorkoutPlan>> getAllPlans(String userId);

  /// Delete a plan for a specific date.
  Future<void> deletePlan(String userId, DateTime date);
}
