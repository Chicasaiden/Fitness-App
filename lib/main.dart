import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/real_ble_service.dart';
import 'pages/home.dart';
import 'pages/login_page.dart';
import 'repositories/firestore_workout_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — connects to your project via firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // StreamBuilder listens to Firebase auth state changes.
      // When user logs in → shows HomePage with Firestore-backed workout repo.
      // When user logs out → shows LoginPage.
      home: StreamBuilder<firebase_auth.User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          // Still loading auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // User is logged in → create their Firestore workout repo
          if (snapshot.hasData) {
            final uid = snapshot.data!.uid;

            // Create a Firestore-backed workout repository for this user.
            // The userId scopes all reads/writes to users/{uid}/workouts/...
            final workoutRepo = FirestoreWorkoutRepository(userId: uid);

            // Prune expired rep details in the background on app startup.
            // This is a "fire and forget" call — we don't await it because
            // we don't want to block the UI while it runs.
            workoutRepo.pruneExpiredDetails();

            return HomePage(
              bleService: RealBleService(),
              authService: authService,
              workoutRepository: workoutRepo,
            );
          }

          // No user → show login page
          return LoginPage(authService: authService);
        },
      ),
    );
  }
}
