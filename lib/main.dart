import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/real_ble_service.dart';
import 'pages/home.dart';
import 'pages/login_page.dart';
import 'user.dart';
import 'repositories/user_repository.dart';
import 'repositories/workout_repository.dart';

final List<User> users = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late UserRepository _userRepository;
  late WorkoutRepository _workoutRepository;
  late bool _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _initRepositories();
  }

  Future<void> _initRepositories() async {
    _userRepository = UserRepository();
    await _userRepository.init();

    _workoutRepository = HiveWorkoutRepository();
    await (_workoutRepository as HiveWorkoutRepository).init();

    _isLoggedIn = _userRepository.isLoggedIn();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Always use real BLE — data comes from Arduino only
    final bleService = RealBleService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _isLoggedIn
          ? HomePage(
              bleService: bleService,
              userRepository: _userRepository,
              workoutRepository: _workoutRepository,
            )
          : LoginPage(userRepository: _userRepository),
    );
  }
}
