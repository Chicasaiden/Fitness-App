// real_ble_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_service.dart';
import '../ble_metrics.dart';

const String velocityServiceUUID = "a7e5f8b0-3c14-4b92-8d7e-6f1a2b9c0e34";
const String velocityCharUUID = "a7e5f8b1-3c14-4b92-8d7e-6f1a2b9c0e34";
const String repStatsCharUUID = "a7e5f8b2-3c14-4b92-8d7e-6f1a2b9c0e34";

class RealBleService implements BleService {
  BluetoothDevice? _connectedDevice;
  StreamController<BleMetrics> _metricsController = StreamController.broadcast();
  StreamSubscription<List<int>>? _velocitySubscription;
  StreamSubscription<List<int>>? _repStatsSubscription;
  final StreamController<List<int>> _dataController = StreamController.broadcast();
  
  // Keep track of the last rep stats to merge with current velocity
  BleMetrics? _lastRepStats;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  String get connectedDeviceName {
    final dev = _connectedDevice;
    if (dev == null) return '';
    return dev.platformName.isNotEmpty
        ? dev.platformName
        : dev.remoteId.toString();
  }

  @override
  Future<void> startScan() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        debugPrint('Bluetooth not supported on this device');
        return;
      }

      // Wait for adapter ON
      await FlutterBluePlus.adapterState.firstWhere((s) => s == BluetoothAdapterState.on);

      // Ensure runtime permissions on Android
      final ok = await _ensurePermissions();
      if (!ok) {
        debugPrint('Required permissions not granted');
        return;
      }

      debugPrint('Starting scan');
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint('startScan error: $e');
    }
  }

  Future<bool> _ensurePermissions() async {
    try {
      if (!Platform.isAndroid) return true;

      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      // Consider granted if all requested permissions are granted
      return statuses.values.every((s) => s.isGranted);
    } catch (e) {
      debugPrint('_ensurePermissions error: $e');
      return false;
    }
  }

  @override
  void stopScan() {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('stopScan error: $e');
    }
  }

  @override
  Stream<List<ScanResult>> get scanResults =>
      FlutterBluePlus.scanResults.map((results) {
    return results.where((r) {
      try {
        final advertised = r.advertisementData.serviceUuids
            .map((g) => g.toString().toLowerCase())
            .toList();

        final matches = advertised.contains(velocityServiceUUID.toLowerCase());
        if (matches) {
          debugPrint('Scan match: ${r.device.id} (${r.device.name})');
        }
        return matches;
      } catch (e) {
        return false;
      }
    }).toList();
  });

  @override
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _connectedDevice = device;

      // If already connected, skip connect
      final connectedState = await device.state.first;
      if (connectedState == BluetoothDeviceState.connected) {
        debugPrint('Device already connected');
      } else {
        debugPrint('Connecting to device ${device.id}...');
        await device.connect(timeout: const Duration(seconds: 10));
        debugPrint('Connected to ${device.id}');
      }

      await _discoverAndSubscribe(device);
    } catch (e) {
      debugPrint('connectToDevice error: $e');
    }
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      debugPrint('Discovered ${services.length} services');
      
      for (final service in services) {
        final svcUuid = service.uuid.toString().toLowerCase();
        debugPrint('Service UUID: $svcUuid');
        
        if (svcUuid == velocityServiceUUID.toLowerCase()) {
          debugPrint('Found velocity service on device ${device.id}');
          for (final characteristic in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toLowerCase();
            debugPrint('Characteristic: $charUuid, properties: ${characteristic.properties}');
            
            // Subscribe to VELOCITY characteristic (real-time float updates at ~100ms)
            if (charUuid == velocityCharUUID.toLowerCase()) {
              if (characteristic.properties.notify) {
                debugPrint('Subscribing to velocity characteristic (real-time Vz)');
                await characteristic.setNotifyValue(true);

                _velocitySubscription?.cancel();
                _velocitySubscription = characteristic.value.listen(
                  (data) {
                    if (data.length >= 4) {
                      try {
                        final byteData = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 4)));
                        final vz = byteData.getFloat32(0, Endian.little);
                        debugPrint('[VelocityChar] Vz: ${vz.toStringAsFixed(4)} m/s');
                        
                        // Emit current velocity merged with last rep stats
                        final metrics = BleMetrics(
                          meanConcentricVelocity: _lastRepStats?.meanConcentricVelocity ?? 0.0,
                          peakConcentricVelocity: _lastRepStats?.peakConcentricVelocity ?? 0.0,
                          timeUnderTension: _lastRepStats?.timeUnderTension ?? 0.0,
                          rangeOfMotion: _lastRepStats?.rangeOfMotion ?? 0.0,
                          averageZAcceleration: _lastRepStats?.averageZAcceleration ?? 0.0,
                          peakZAcceleration: _lastRepStats?.peakZAcceleration ?? 0.0,
                          repNumber: _lastRepStats?.repNumber ?? 0,
                          isSetComplete: _lastRepStats?.isSetComplete ?? false,
                          currentVelocity: vz,
                        );
                        _metricsController.add(metrics);
                        _dataController.add(data);
                      } catch (e) {
                        debugPrint('Error decoding velocity float: $e');
                      }
                    }
                  },
                  onError: (e) {
                    debugPrint('Velocity characteristic stream error: $e');
                  },
                );
              }
            }
            
            // Subscribe to REP_STATS characteristic (29-byte RepData struct, sent at end of each rep)
            if (charUuid == repStatsCharUUID.toLowerCase()) {
              if (characteristic.properties.notify) {
                debugPrint('Subscribing to rep stats characteristic (29-byte RepData)');
                await characteristic.setNotifyValue(true);

                _repStatsSubscription?.cancel();
                _repStatsSubscription = characteristic.value.listen(
                  (data) {
                    if (data.length >= 29) {
                      try {
                        final byteData = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 29)));
                        
                        // Arduino RepData struct (packed, little-endian):
                        //  0: float meanConcentricVelocity (m/s)
                        //  4: float peakConcentricVelocity (m/s)
                        //  8: float timeUnderTension       (seconds)
                        // 12: float rangeOfMotion           (meters)
                        // 16: float averageZAcceleration    (m/s²)
                        // 20: float peakZAcceleration       (m/s²)
                        // 24: uint32_t repNumber
                        // 28: bool isSetComplete
                        final mcv = byteData.getFloat32(0, Endian.little);
                        final pcv = byteData.getFloat32(4, Endian.little);
                        final tut = byteData.getFloat32(8, Endian.little);
                        final rom = byteData.getFloat32(12, Endian.little);
                        final avgZAccel = byteData.getFloat32(16, Endian.little);
                        final peakZAccel = byteData.getFloat32(20, Endian.little);
                        final repNum = byteData.getUint32(24, Endian.little);
                        final setComplete = data[28] != 0;
                        
                        debugPrint('[RepStatsChar] MCV: ${mcv.toStringAsFixed(4)} m/s, '
                            'PCV: ${pcv.toStringAsFixed(4)} m/s, '
                            'TUT: ${tut.toStringAsFixed(2)} s, '
                            'ROM: ${rom.toStringAsFixed(3)} m, '
                            'AvgZAccel: ${avgZAccel.toStringAsFixed(3)} m/s², '
                            'PeakZAccel: ${peakZAccel.toStringAsFixed(3)} m/s², '
                            'Rep#: $repNum, '
                            'SetComplete: $setComplete');
                        
                        final metrics = BleMetrics(
                          meanConcentricVelocity: mcv,
                          peakConcentricVelocity: pcv,
                          timeUnderTension: tut,
                          rangeOfMotion: rom,
                          averageZAcceleration: avgZAccel,
                          peakZAcceleration: peakZAccel,
                          repNumber: repNum,
                          isSetComplete: setComplete,
                          currentVelocity: _lastRepStats?.currentVelocity,
                        );
                        _lastRepStats = metrics;
                        _metricsController.add(metrics);
                      } catch (e) {
                        debugPrint('Error decoding rep stats: $e');
                      }
                    } else {
                      debugPrint('RepStats data too short: ${data.length} bytes (need 29)');
                    }
                  },
                  onError: (e) {
                    debugPrint('Rep stats characteristic stream error: $e');
                  },
                );
              }
            }
          }
        }
      }
      debugPrint('Service discovery complete for device ${device.id}');
    } catch (e) {
      debugPrint('_discoverAndSubscribe error: $e');
    }
  }

  @override
  Stream<BleMetrics> metricsStream() => _metricsController.stream;

  @override
  void reset() {
    _velocitySubscription?.cancel();
    _repStatsSubscription?.cancel();
    _metricsController = StreamController.broadcast();
  }

  @override
  void dispose() {
    _velocitySubscription?.cancel();
    _repStatsSubscription?.cancel();
    _metricsController.close();
    _dataController.close();
    _connectedDevice?.disconnect();
  }
}
