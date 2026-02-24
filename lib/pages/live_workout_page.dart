import 'package:flutter/material.dart';

class LiveWorkoutPage extends StatefulWidget {
  final String? connectedDeviceName;

  const LiveWorkoutPage({super.key, this.connectedDeviceName});

  @override
  State<LiveWorkoutPage> createState() => _LiveWorkoutPageState();
}

class _LiveWorkoutPageState extends State<LiveWorkoutPage> {
  bool _isWorkoutActive = false;
  double _elapsedSeconds = 0;

  @override
  Widget build(BuildContext context) {
    final isDeviceConnected = widget.connectedDeviceName != null && widget.connectedDeviceName!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Workout'),
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: !isDeviceConnected
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No Device Connected',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please connect to your device first',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Connect Device'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Device Status
                  Container(
                    color: Colors.deepPurple.shade700,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Connected: ${widget.connectedDeviceName}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Timer Display
                  Text(
                    _formatDuration(_elapsedSeconds),
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 32),
                  // Metrics Placeholder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Metrics',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMetricTile('MCV', '--', 'm/s'),
                            _buildMetricTile('Peak Velocity', '--', 'm/s'),
                            _buildMetricTile('TUT', '--', 's'),
                            _buildMetricTile('ROM', '--', 'cm'),
                            _buildMetricTile('Avg Z-Accel', '--', 'm/s²'),
                            _buildMetricTile('Peak Z-Accel', '--', 'm/s²'),
                            _buildMetricTile('Rep #', '--', ''),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Start/Stop Button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isWorkoutActive = !_isWorkoutActive;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isWorkoutActive ? Colors.red.shade400 : Colors.green.shade400,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isWorkoutActive ? 'Stop Workout' : 'Start Workout',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile(String title, String value, String unit) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade700.withOpacity(0.8), Colors.deepPurple.shade700.withOpacity(0.6)],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
