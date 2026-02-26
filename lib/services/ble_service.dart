import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble_metrics.dart';

abstract class BleService {
  Stream<BleMetrics> metricsStream();

  /// The name of the currently connected device, or empty if none.
  String get connectedDeviceName;

  Stream<List<int>> get dataStream;

  Stream<List<ScanResult>> get scanResults;

  Future<void> startScan();

  void stopScan();

  Future<void> connectToDevice(BluetoothDevice device);

  void reset();

  void dispose();
}
