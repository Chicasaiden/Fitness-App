import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout.dart';
import '../models/set_summary.dart';
import '../models/rep_record.dart';
import 'workout_repository.dart';

/// Firestore-backed implementation of WorkoutRepository.
///
/// How the data is organized in Firestore:
///
///   users/{userId}/workouts/{workoutId}      ← workout document
///     └── sets/{setIndex}                     ← set summary document
///           └── reps/{repIndex}               ← individual rep document
///
/// WHY SUBCOLLECTIONS?
/// Firestore charges per document read. By keeping reps in a subcollection:
/// 1. Listing all workouts only reads workout docs (cheap)
/// 2. Viewing one workout reads workout + sets (moderate)
/// 3. Deep comparison reads workout + sets + reps (full cost, but only when needed)
/// 4. After 10 days, we can DELETE just the reps subcollection without touching
///    the set summaries — clean separation.
///
/// 10-DAY RETENTION RULE:
/// Each workout has a `detailExpiry` timestamp = date + 10 days.
/// - Before expiry: reps subcollection exists, full rep-by-rep data available
/// - After expiry: `pruneExpiredDetails()` deletes the reps subcollection
///   The set summary fields remain on the set document forever.
class FirestoreWorkoutRepository implements WorkoutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  FirestoreWorkoutRepository({required this.userId});

  /// Helper: get the workouts collection reference for this user.
  CollectionReference<Map<String, dynamic>> get _workoutsRef =>
      _firestore.collection('users').doc(userId).collection('workouts');

  // ── Add Workout ───────────────────────────────────────────────────────

  /// Save a complete workout with sets and reps to Firestore.
  /// This uses a BATCH WRITE — all documents are written atomically
  /// (either all succeed or all fail, no partial writes).
  @override
  Future<void> addWorkout(Workout workout) async {
    final batch = _firestore.batch();
    final workoutRef = _workoutsRef.doc(workout.id);

    // Write the workout document (top-level summary data)
    // detailExpiry tells us when to prune the rep-level detail
    batch.set(workoutRef, {
      ...workout.toJson(),
      'detailExpiry': Timestamp.fromDate(
        workout.date.add(const Duration(days: 10)),
      ),
      // Remove sets from the workout doc — they go in a subcollection
      'sets': null,
    });

    // Write each set as a subcollection document
    for (int i = 0; i < workout.sets.length; i++) {
      final set = workout.sets[i];
      final setRef = workoutRef.collection('sets').doc('set_$i');

      // Write set summary fields (these stay forever)
      final setData = set.toJson();
      // Remove reps from the set doc — they go in their own subcollection
      setData.remove('reps');
      setData['hasDetailedReps'] = true;
      setData['setIndex'] = i;
      batch.set(setRef, setData);

      // Write each rep as a subcollection document under the set
      for (int j = 0; j < set.reps.length; j++) {
        final repRef = setRef.collection('reps').doc('rep_$j');
        batch.set(repRef, set.reps[j].toJson());
      }
    }

    // Commit all writes atomically
    await batch.commit();
  }

  // ── Get Workouts ──────────────────────────────────────────────────────

  /// Get all workouts for this user, sorted newest first.
  /// This only reads the workout documents (not sets/reps) — efficient!
  @override
  Future<List<Workout>> getWorkoutsByUserId(String userId) async {
    final snapshot = await _workoutsRef
        .orderBy('date', descending: true)
        .get();

    final workouts = <Workout>[];
    for (final doc in snapshot.docs) {
      final workout = await _workoutFromDoc(doc);
      workouts.add(workout);
    }
    return workouts;
  }

  /// Get a single workout by ID, including full sets and optionally reps.
  @override
  Future<Workout?> getWorkoutById(String id) async {
    final doc = await _workoutsRef.doc(id).get();
    if (!doc.exists) return null;
    return _workoutFromDoc(doc);
  }

  // ── Update / Delete ───────────────────────────────────────────────────

  @override
  Future<void> updateWorkout(Workout workout) async {
    // For simplicity, delete and re-add (handles subcollection updates)
    await deleteWorkout(workout.id);
    await addWorkout(workout);
  }

  @override
  Future<void> deleteWorkout(String id) async {
    final workoutRef = _workoutsRef.doc(id);

    // Delete all reps in all sets first (Firestore doesn't cascade deletes)
    final setsSnapshot = await workoutRef.collection('sets').get();
    for (final setDoc in setsSnapshot.docs) {
      final repsSnapshot = await setDoc.reference.collection('reps').get();
      for (final repDoc in repsSnapshot.docs) {
        await repDoc.reference.delete();
      }
      await setDoc.reference.delete();
    }

    // Then delete the workout document itself
    await workoutRef.delete();
  }

  @override
  Future<void> clearAllWorkouts() async {
    final snapshot = await _workoutsRef.get();
    for (final doc in snapshot.docs) {
      await deleteWorkout(doc.id);
    }
  }

  // ── 10-Day Retention: Pruning ─────────────────────────────────────────

  /// Remove rep-level detail from workouts older than 10 days.
  /// Called on app startup to keep Firestore lean.
  ///
  /// This is the key to your data retention strategy:
  /// - Recent workouts (< 10 days): full rep-by-rep data for comparison
  /// - Older workouts (> 10 days): compact set summaries only
  Future<void> pruneExpiredDetails() async {
    final now = Timestamp.now();

    // Find workouts where detailExpiry has passed
    final expiredSnapshot = await _workoutsRef
        .where('detailExpiry', isLessThan: now)
        .get();

    for (final workoutDoc in expiredSnapshot.docs) {
      final setsSnapshot =
          await workoutDoc.reference.collection('sets').get();

      for (final setDoc in setsSnapshot.docs) {
        // Check if reps still exist (might already be pruned)
        final repsSnapshot =
            await setDoc.reference.collection('reps').get();

        if (repsSnapshot.docs.isNotEmpty) {
          // Delete all rep documents in this set
          final batch = _firestore.batch();
          for (final repDoc in repsSnapshot.docs) {
            batch.delete(repDoc.reference);
          }
          // Mark this set as no longer having detailed reps
          batch.update(setDoc.reference, {'hasDetailedReps': false});
          await batch.commit();
        }
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Build a Workout object from a Firestore document.
  /// Loads sets from the subcollection, and conditionally loads reps
  /// based on whether the detail hasn't expired yet.
  Future<Workout> _workoutFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data()!;

    // Load sets from subcollection
    final setsSnapshot = await doc.reference
        .collection('sets')
        .orderBy('setIndex')
        .get();

    final sets = <SetSummary>[];
    for (final setDoc in setsSnapshot.docs) {
      final setData = Map<String, dynamic>.from(setDoc.data());
      final hasDetailedReps = setData['hasDetailedReps'] as bool? ?? false;

      // Load reps if they haven't been pruned
      List<RepRecord> reps = [];
      if (hasDetailedReps) {
        final repsSnapshot = await setDoc.reference.collection('reps').get();
        reps = repsSnapshot.docs
            .map((r) => RepRecord.fromJson(r.data()))
            .toList();
        // Sort by rep number
        reps.sort((a, b) => a.repNumber.compareTo(b.repNumber));
      }

      // Build the SetSummary with or without reps
      setData['reps'] = reps.map((r) => r.toJson()).toList();
      setData.remove('hasDetailedReps');
      setData.remove('setIndex');
      sets.add(SetSummary.fromJson(setData));
    }

    // Build the Workout object
    return Workout(
      id: doc.id,
      userId: data['userId'] as String,
      date: DateTime.parse(data['date'] as String),
      duration: (data['duration'] as num).toDouble(),
      meanConcentricVelocity:
          (data['meanConcentricVelocity'] as num?)?.toDouble() ?? 0.0,
      peakConcentricVelocity:
          (data['peakConcentricVelocity'] as num?)?.toDouble() ?? 0.0,
      timeUnderTension:
          (data['timeUnderTension'] as num?)?.toDouble() ?? 0.0,
      rangeOfMotion: (data['rangeOfMotion'] as num?)?.toDouble() ?? 0.0,
      averageZAcceleration:
          (data['averageZAcceleration'] as num?)?.toDouble() ?? 0.0,
      peakZAcceleration:
          (data['peakZAcceleration'] as num?)?.toDouble() ?? 0.0,
      sets: sets,
      notes: data['notes'] as String?,
    );
  }
}
