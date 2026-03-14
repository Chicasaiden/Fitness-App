import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/real_ble_service.dart';
import 'services/theme_service.dart';
import 'pages/home.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';
import 'repositories/firestore_workout_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — connects to your project via firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp(themeService: ThemeService.instance));
}

class MyApp extends StatefulWidget {
  final ThemeService themeService;

  const MyApp({super.key, required this.themeService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    widget.themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: widget.themeService.themeMode,

      // ─── Light Theme ────────────────────────────────────────────────
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.black87,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
        cardColor: Colors.white,
        fontFamily: 'Roboto',
      ),

      // ─── Dark Theme ─────────────────────────────────────────────────
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardColor: const Color(0xFF1E1E1E),
        fontFamily: 'Roboto',
      ),

      home: _AppRoot(authService: authService),
    );
  }
}

/// Handles the onboarding-first flow and auth state routing.
class _AppRoot extends StatefulWidget {
  final AuthService authService;
  const _AppRoot({required this.authService});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool? _showOnboarding; // null = still checking

  @override
  void initState() {
    super.initState();
    OnboardingPage.shouldShow().then((show) {
      if (mounted) setState(() => _showOnboarding = show);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Still loading onboarding flag
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show onboarding on first launch
    if (_showOnboarding!) {
      return OnboardingPage(
        onFinished: () {
          if (mounted) setState(() => _showOnboarding = false);
        },
      );
    }

    // Normal auth-gated routing
    return StreamBuilder<firebase_auth.User?>(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          final workoutRepo = FirestoreWorkoutRepository(userId: uid);
          workoutRepo.pruneExpiredDetails();

          return HomePage(
            bleService: RealBleService(),
            authService: widget.authService,
            workoutRepository: workoutRepo,
          );
        }

        return LoginPage(authService: widget.authService);
      },
    );
  }
}
