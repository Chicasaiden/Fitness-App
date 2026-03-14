import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout_plan.dart';
import 'workout_plan_repository.dart';

/// Firestore-backed implementation of [WorkoutPlanRepository].
///
/// Firestore path: users/{userId}/plans/{YYYYMMDD}
///
/// One simple flat document per day — plans are small so no subcollections
/// are needed.
///
/// Repeat Weekly Logic:
/// When no plan exists for a date, [getPlanForDate] checks if 7 days ago
/// had a plan with repeatWeekly movements. Those movements are returned as
/// a default plan (but NOT auto-saved — only saved when the user taps Save).
class FirestoreWorkoutPlanRepository implements WorkoutPlanRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _plansRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('plans');

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  @override
  Future<void> savePlan(WorkoutPlan plan) async {
    final key = _dateKey(plan.date);
    await _plansRef(plan.userId).doc(key).set(plan.toJson());
  }

  @override
  Future<WorkoutPlan?> getPlanForDate(String userId, DateTime date) async {
    final key = _dateKey(date);
    final doc = await _plansRef(userId).doc(key).get();

    if (doc.exists && doc.data() != null) {
      return WorkoutPlan.fromJson(doc.data()!);
    }

    // No plan found — check if 7 days ago had any repeatWeekly movements
    return _buildRepeatWeeklyPlan(userId, date);
  }

  /// Looks up the plan from exactly 7 days ago and returns the movements
  /// that are marked `repeatWeekly: true` as a NEW (unsaved) plan template.
  Future<WorkoutPlan?> _buildRepeatWeeklyPlan(
      String userId, DateTime date) async {
    final lastWeek = date.subtract(const Duration(days: 7));
    final key = _dateKey(lastWeek);
    final doc = await _plansRef(userId).doc(key).get();
    if (!doc.exists || doc.data() == null) return null;

    final lastWeekPlan = WorkoutPlan.fromJson(doc.data()!);
    final repeating = lastWeekPlan.movements
        .where((m) => m.repeatWeekly)
        .toList();

    if (repeating.isEmpty) return null;

    // Return a plan pre-filled with recurring movements but NOT saved yet
    return WorkoutPlan(
      id: WorkoutPlan.idFor(userId, date),
      userId: userId,
      date: date,
      movements: repeating,
      notes: null,
    );
  }

  @override
  Future<List<WorkoutPlan>> getAllPlans(String userId) async {
    final snapshot = await _plansRef(userId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .where((d) => d.exists)
        .map((d) => WorkoutPlan.fromJson(d.data()))
        .toList();
  }

  @override
  Future<void> deletePlan(String userId, DateTime date) async {
    final key = _dateKey(date);
    await _plansRef(userId).doc(key).delete();
  }
}
