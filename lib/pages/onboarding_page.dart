import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Three-screen first-launch onboarding experience.
///
/// Shown only once. On completion (or skip) writes [onboardingComplete] = true
/// to SharedPreferences and calls [onFinished].
class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingPage({super.key, required this.onFinished});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboardingComplete') ?? false);
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingData(
      emoji: '📡',
      color1: Color(0xFF0D47A1),
      color2: Color(0xFF1565C0),
      title: 'Connect Your Device',
      subtitle:
          'Pair your velocity sensor over Bluetooth to start capturing real-time bar velocity on every rep.',
      decoration: Icons.bluetooth_connected,
    ),
    _OnboardingData(
      emoji: '⚡',
      color1: Color(0xFF1B5E20),
      color2: Color(0xFF2E7D32),
      title: 'Live VBT Metrics',
      subtitle:
          'See mean concentric velocity, peak velocity, and velocity loss % as you train. Know when you\'re fatigued before you feel it.',
      decoration: Icons.speed,
    ),
    _OnboardingData(
      emoji: '🎯',
      color1: Color(0xFF4A148C),
      color2: Color(0xFF6A1B9A),
      title: 'Intelligent Insights',
      subtitle:
          'Plan your sessions with auto-suggested loads, track 1RM trends, and let the app tell you when to push harder — or rest.',
      decoration: Icons.insights,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 380), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await OnboardingPage.markComplete();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page content
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, i) => _OnboardingSlide(data: _pages[i]),
          ),

          // Bottom controls
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 44),
              child: Column(
                children: [
                  // Dot indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Skip (only show on non-last pages)
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
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

// ─── Slide Widget ─────────────────────────────────────────────────────────────

class _OnboardingData {
  final String emoji;
  final Color color1;
  final Color color2;
  final String title;
  final String subtitle;
  final IconData decoration;

  const _OnboardingData({
    required this.emoji,
    required this.color1,
    required this.color2,
    required this.title,
    required this.subtitle,
    required this.decoration,
  });
}

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [data.color1, data.color2],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big background icon (decorative)
              Align(
                alignment: Alignment.centerRight,
                child: Icon(data.decoration,
                    size: 140,
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              const SizedBox(height: 0),

              // Emoji
              Text(data.emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 24),

              // Title
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                data.subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
