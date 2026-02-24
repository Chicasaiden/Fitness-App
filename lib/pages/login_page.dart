import 'package:flutter/material.dart';
import 'home.dart';
import 'create_account_page.dart';
import '../repositories/user_repository.dart';
import '../repositories/workout_repository.dart';
import '../services/real_ble_service.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  final UserRepository userRepository;

  const LoginPage({super.key, required this.userRepository});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Stack(
        children: [
          // Small Bulls logo in top-right (subtle branding)
          Positioned(
            top: 50,
            right: 20,
            child: Image.asset(
              'assets/bulls_logo.png',
              height: 40,
              opacity: const AlwaysStoppedAnimation(0.8),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App title
                  const Text(
                    'CT Fit',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Username field
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Password field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  // Error message
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final username = _usernameController.text.trim();
                        final password = _passwordController.text;

                        // Basic validation
                        if (username.isEmpty || password.isEmpty) {
                          setState(() {
                            errorMessage = 'Please enter username and password';
                          });
                          return;
                        }

                        final userExists = users.any(
                          (u) =>
                              u.username == username &&
                              u.password == password,
                        );

                        if (!userExists) {
                          setState(() {
                            errorMessage = 'Invalid username or password';
                          });
                          return;
                        }

                        // Find user and save to repository
                        final user = users.firstWhere(
                          (u) => u.username == username && u.password == password,
                        );
                        
                        await widget.userRepository.saveCurrentUser(user);

                        // Clear error and navigate
                        if (mounted) {
                          setState(() => errorMessage = null);

                          // Initialize repositories
                          final workoutRepository = HiveWorkoutRepository();
                          await (workoutRepository).init();
                          final bleService = RealBleService();

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HomePage(
                                bleService: bleService,
                                userRepository: widget.userRepository,
                                workoutRepository: workoutRepository,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Create account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateAccountPage(userRepository: widget.userRepository),
                            ),
                          );
                        },
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
