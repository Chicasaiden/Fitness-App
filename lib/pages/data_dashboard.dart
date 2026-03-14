import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';

/// Premium connection page: scan, discover, and connect to the Arduino.
class DataDashboard extends StatefulWidget {
  final BleService bleService;

  const DataDashboard({super.key, required this.bleService});

  @override
  State<DataDashboard> createState() => _DataDashboardState();
}

class _DataDashboardState extends State<DataDashboard>
    with TickerProviderStateMixin {
  String _status = "idle"; // idle | scanning | connected
  String _deviceName = "";
  List<ScanResult> _devices = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _scanSub = widget.bleService.scanResults.listen((results) {
      if (mounted) setState(() => _devices = results);
    });

    // Check if already connected
    if (widget.bleService.connectedDeviceName.isNotEmpty) {
      _status = "connected";
      _deviceName = widget.bleService.connectedDeviceName;
      _successController.forward();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _status = "scanning";
      _devices.clear();
    });

    await widget.bleService.startScan();
    await Future.delayed(const Duration(seconds: 5));
    widget.bleService.stopScan();

    if (mounted && _status != "connected") {
      setState(() => _status = "idle");
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _status = "scanning";
      _deviceName = device.platformName.isNotEmpty
          ? device.platformName
          : device.remoteId.toString();
    });

    await widget.bleService.connectToDevice(device);

    if (mounted) {
      setState(() => _status = "connected");
      _successController.forward(from: 0);
    }
  }

  // ── RSSI → signal bars (0–4) ──────────────────────────────────────
  int _signalBars(int rssi) {
    if (rssi >= -55) return 4;
    if (rssi >= -67) return 3;
    if (rssi >= -78) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _deviceName.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _deviceName.isNotEmpty) {
          Navigator.pop(context, _deviceName);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: CustomScrollView(
          slivers: [
            // ── DARK GRADIENT HEADER ──────────────────────────────
            SliverToBoxAdapter(child: _buildHeader()),
            // ── BODY ─────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_status == "connected") _buildConnectedCard(),
                  if (_status != "connected") _buildScanButton(),
                  if (_devices.isNotEmpty && _status != "connected") ...[
                    const SizedBox(height: 20),
                    _buildDeviceList(),
                  ],
                  if (_status == "idle" && _devices.isEmpty) ...[
                    const SizedBox(height: 40),
                    _buildEmptyState(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            children: [
              // Top bar with back button
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_deviceName.isNotEmpty) {
                        Navigator.pop(context, _deviceName);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _status == "connected" ? "Connected" : "Connect Device",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 34), // balance the back button
                ],
              ),
              const SizedBox(height: 28),

              // Animated Bluetooth icon area
              SizedBox(
                height: 120,
                width: 120,
                child: _buildBluetoothVisual(),
              ),

              const SizedBox(height: 16),

              // Status text
              Text(
                _statusTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusSubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _statusTitle {
    switch (_status) {
      case "scanning":
        return "Searching...";
      case "connected":
        return _deviceName;
      default:
        return "Ready to Connect";
    }
  }

  String get _statusSubtitle {
    switch (_status) {
      case "scanning":
        return "Looking for nearby devices";
      case "connected":
        return "Device connected successfully";
      default:
        return "Tap scan to find your device";
    }
  }

  // ── BLUETOOTH VISUAL (animated radar / checkmark) ─────────────────
  Widget _buildBluetoothVisual() {
    if (_status == "connected") {
      return AnimatedBuilder(
        animation: _successScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _successScale.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.15),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3), width: 2),
              ),
              child: const Center(
                child: Icon(Icons.check_rounded,
                    color: Colors.greenAccent, size: 56),
              ),
            ),
          );
        },
      );
    }

    final isScanning = _status == "scanning";

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ripple rings (only while scanning)
            if (isScanning) ...[
              _buildRipple(_pulseAnimation.value, 0.3),
              _buildRipple((_pulseAnimation.value + 0.33) % 1.0, 0.3),
              _buildRipple((_pulseAnimation.value + 0.66) % 1.0, 0.3),
            ],
            // Center icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isScanning
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: isScanning
                      ? Colors.blue.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.bluetooth,
                color: isScanning ? Colors.blueAccent : Colors.white54,
                size: 30,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRipple(double progress, double maxOpacity) {
    final size = 64 + (56 * progress);
    final opacity = maxOpacity * (1.0 - progress);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: opacity),
          width: 2,
        ),
      ),
    );
  }

  // ── SCAN BUTTON ───────────────────────────────────────────────────
  Widget _buildScanButton() {
    final isScanning = _status == "scanning";
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isScanning
            ? null
            : const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
        color: isScanning ? Colors.grey.shade300 : null,
        boxShadow: isScanning
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isScanning ? null : _startScan,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                else
                  const Icon(Icons.bluetooth_searching,
                      color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  isScanning ? "Scanning..." : "Scan for Devices",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CONNECTED CARD ────────────────────────────────────────────────
  Widget _buildConnectedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bluetooth_connected,
                    color: Colors.green.shade600, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Connected and ready",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Live",
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Go back to start training with live velocity data",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DEVICE LIST ───────────────────────────────────────────────────
  Widget _buildDeviceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                "AVAILABLE DEVICES",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${_devices.length} found",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...List.generate(_devices.length, (i) => _buildDeviceCard(_devices[i])),
      ],
    );
  }

  Widget _buildDeviceCard(ScanResult result) {
    final device = result.device;
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : "Unknown Device";
    final rssi = result.rssi;
    final bars = _signalBars(rssi);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _connect(device),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Device icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    device.platformName.isNotEmpty
                        ? Icons.developer_board
                        : Icons.devices_other,
                    color: Colors.grey.shade600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Name + ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        device.remoteId.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                // Signal bars
                _buildSignalBars(bars),
                const SizedBox(width: 12),
                // Connect arrow
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignalBars(int bars) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final isActive = i < bars;
        final height = 6.0 + (i * 4.0);
        return Container(
          width: 4,
          height: height,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isActive
                ? (bars >= 3 ? Colors.green : Colors.orange)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
            ),
            child: Icon(
              Icons.bluetooth_disabled,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No devices found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Make sure your device is powered on\nand in range, then tap scan",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
