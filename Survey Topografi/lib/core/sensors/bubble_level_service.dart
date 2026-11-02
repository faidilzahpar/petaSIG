import 'dart:async';
import 'dart:math';

/// Service Waterpass Digital (Bubble Spirit Level) Menggunakan Sensor Gravitasi / Akselerometer Handphone
class BubbleLevelService {
  static final BubbleLevelService _instance = BubbleLevelService._internal();
  factory _instance() => _instance;
  BubbleLevelService._internal();

  double _pitch = 0.0; // Derajat kemiringan depan-belakang (-90 s/d +90)
  double _roll = 0.0;  // Derajat kemiringan kiri-kanan (-90 s/d +90)
  double _tiltAngle = 0.0; // Total deviasi sudut dari garis tegak lurus (derajat)

  final StreamController<Map<String, double>> _levelStream =
      StreamController<Map<String, double>>.broadcast();

  Stream<Map<String, double>> get levelStream => _levelStream.stream;
  double get pitch => _pitch;
  double get roll => _roll;
  double get tiltAngle => _tiltAngle;

  /// Toleransi maksimal kemiringan jalon survei (derajat)
  final double plumbToleranceDegrees = 2.0;

  bool get isPlumbAndLevel => _tiltAngle <= plumbToleranceDegrees;

  /// Update data percepatan akselerometer (gx, gy, gz dalam m/s^2)
  void updateAccelerometer(double gx, double gy, double gz) {
    // Normalisasi percepatan
    double gNorm = sqrt(gx * gx + gy * gy + gz * gz);
    if (gNorm < 0.001) return;

    double ax = gx / gNorm;
    double ay = gy / gNorm;
    double az = gz / gNorm;

    // Sudut Roll dan Pitch
    _roll = atan2(ax, sqrt(ay * ay + az * az)) * (180.0 / pi);
    _pitch = atan2(ay, sqrt(ax * ax + az * az)) * (180.0 / pi);

    // Deviasi sudut total terhadap sumbu vertikal
    _tiltAngle = sqrt(_roll * _roll + _pitch * _pitch);

    _levelStream.add({
      'pitch': _pitch,
      'roll': _roll,
      'tilt': _tiltAngle,
      'isLevel': isPlumbAndLevel ? 1.0 : 0.0,
    });
  }
}

