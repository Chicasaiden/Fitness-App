/// Data model matching the Arduino Nano 33 BLE Rev 2 RepData struct.
///
/// Rep stats (29-byte struct) are sent at end of each rep.
/// Current velocity is streamed separately at ~100ms intervals.
class BleMetrics {
  final double meanConcentricVelocity;   // MCV (m/s)
  final double peakConcentricVelocity;   // Peak velocity during concentric phase (m/s)
  final double timeUnderTension;         // TUT in seconds
  final double rangeOfMotion;            // ROM in meters
  final double averageZAcceleration;     // Average Z-axis acceleration (m/s²)
  final double peakZAcceleration;        // Peak Z-axis acceleration (m/s²)
  final int repNumber;                   // Rep count
  final bool isSetComplete;             // True when set is finished
  final double? currentVelocity;         // Real-time Vz (m/s) - streamed at ~100ms

  BleMetrics({
    required this.meanConcentricVelocity,
    required this.peakConcentricVelocity,
    required this.timeUnderTension,
    required this.rangeOfMotion,
    required this.averageZAcceleration,
    required this.peakZAcceleration,
    required this.repNumber,
    required this.isSetComplete,
    this.currentVelocity,
  });
}
