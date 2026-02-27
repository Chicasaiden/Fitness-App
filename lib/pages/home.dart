import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'data_dashboard.dart';
import 'live_workout_page.dart';
import 'view_old_workout_page.dart';
import 'plan_workout_page.dart';
import 'calendar_page.dart';
import 'news_page.dart';
import 'settings_page.dart';
import 'metrics_dashboard_page.dart';
import '../services/ble_service.dart';
import '../services/set_tracker.dart';
import '../services/auth_service.dart';
import '../repositories/workout_repository.dart';
import '../ble_metrics.dart';

class HomePage extends StatefulWidget {
  final BleService bleService;
  final AuthService authService;
  final WorkoutRepository workoutRepository;
  final String connectedDeviceName;

  const HomePage({
    Key? key,
    BleService? bleService,
    required this.authService,
    required this.workoutRepository,
    this.connectedDeviceName = '',
  })  : bleService = bleService ?? const _DummyBleService(),
        super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;
  String _connectedDevice = '';
  late final SetTracker _setTracker;

  @override
  void initState() {
    super.initState();
    _connectedDevice = widget.connectedDeviceName.isNotEmpty
        ? widget.connectedDeviceName
        : widget.bleService.connectedDeviceName;
    _setTracker = SetTracker(widget.bleService);
  }

  /// Sync connection state from the BLE service after returning from
  /// the DataDashboard (connect screen).
  void _syncConnectionStatus([String? returnedName]) {
    setState(() {
      if (returnedName != null && returnedName.isNotEmpty) {
        _connectedDevice = returnedName;
      } else {
        _connectedDevice = widget.bleService.connectedDeviceName;
      }
    });
  }

  Widget _buildHomePage() {
    final currentUser = widget.authService.currentUser;
    final userName = currentUser?.displayName ?? 'User';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting Section - Minimal, clean background
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi $userName,',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CONNECTION SECTION - Bubble
                _buildSectionBubble(
                  title: 'Connection',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DataDashboard(bleService: widget.bleService),
                            ),
                          );
                          if (mounted) {
                            _syncConnectionStatus(result as String?);
                          }
                        },
                        icon: const Icon(Icons.bluetooth, size: 22),
                        label: const Text('Connect to Device'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Device Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _connectedDevice.isEmpty
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          border: Border.all(
                            color: _connectedDevice.isEmpty
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _connectedDevice.isEmpty
                                    ? Colors.red.shade400
                                    : Colors.green.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _connectedDevice.isEmpty
                                    ? 'No Device Connected'
                                    : _connectedDevice,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // METRICS SECTION - Bubble
                _buildSectionBubble(
                  title: 'Metrics',
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final currentUser = widget.authService.currentUser;
                      final userId = currentUser?.id ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MetricsDashboardPage(
                            bleService: widget.bleService,
                            setTracker: _setTracker,
                            workoutRepository: widget.workoutRepository,
                            userId: userId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.show_chart, size: 22),
                    label: const Text('Workouts and Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // TRAINING SECTION - Bubble
                _buildSectionBubble(
                  title: 'Training',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Large Start Workout Button
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveWorkoutPage(
                                connectedDeviceName:
                                    _connectedDevice.isEmpty ? null : _connectedDevice,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: const Text('Start Workout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Two smaller buttons below
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final currentUser = widget.authService.currentUser;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewOldWorkoutPage(
                                      workoutRepository: widget.workoutRepository,
                                      userId: currentUser?.id ?? '',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text('View Old'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PlanWorkoutPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('Plan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reusable section bubble component
  Widget _buildSectionBubble({
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build pages dynamically so the home page refreshes when _connectedDevice changes
    final pages = <Widget>[
      _buildHomePage(),
      CalendarPage(
        workoutRepository: widget.workoutRepository,
        userId: widget.authService.currentUser?.id ?? '',
      ),
      const NewsPage(),
      SettingsPage(authService: widget.authService),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentPageIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        indicatorColor: Colors.blue.shade100.withOpacity(0.6),
        selectedIndex: _currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.calendar_month),
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.newspaper),
            icon: Icon(Icons.newspaper_outlined),
            label: 'News',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Dummy implementation to satisfy BleService requirement
class _DummyBleService implements BleService {
  const _DummyBleService();

  @override
  Stream<List<int>> get dataStream => Stream.empty();

  @override
  Stream<List<ScanResult>> get scanResults => Stream.empty();

  @override
  Stream<BleMetrics> metricsStream() => Stream.empty();

  @override
  Future<void> connectToDevice(BluetoothDevice device) async {}

  @override
  String get connectedDeviceName => '';

  @override
  void dispose() {}

  @override
  void reset() {}

  @override
  Future<void> startScan() async {}

  @override
  void stopScan() {}
}
