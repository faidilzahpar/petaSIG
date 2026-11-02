import 'dart:async';
import 'dart:math';
import '../math/geodetic_utils.dart';
import '../math/kalman_filter.dart';

/// Service Barometer Diferensial untuk penentuan elevasi mikro permukaan topografi
class BarometerService {
  static final BarometerService _instance = BarometerService._internal();
  factory BarometerService() => _instance;
  BarometerService._internal();

  double _currentPressure = 1013.25; // hPa
  double _basePressure = 1013.25;    // hPa dari Anchor A (Base Station)
  double _baseElevation = 100.0;     // Elevasi patok benchmark awal (meter dpl)
  double _ambientTemperature = 25.0; // Celsius

  final SurfaceElevationKalmanFilter _kalman = SurfaceElevationKalmanFilter();
  final StreamController<double> _elevationStream = StreamController<double>.broadcast();

  Stream<double> get elevationStream => _elevationStream.stream;
  double get currentPressure => _currentPressure;
  double get basePressure => _basePressure;
  double get baseElevation => _baseElevation;
  double get ambientTemperature => _ambientTemperature;

  /// Update tekanan udara saat ini dari sensor internal handphone (atau simulasi jika tidak tersedia)
  void updateLocalPressure(double pressureHpa, {double? tempC}) {
    _currentPressure = pressureHpa;
    if (tempC != null) _ambientTemperature = tempC;

    double rawDiffZ = GeodeticUtils.calculateDifferentialElevation(
      pBase: _basePressure,
      pRover: _currentPressure,
      tempC: _ambientTemperature,
      baseElevation: _baseElevation,
    );

    // Filter Kalman untuk menghasilkan elevasi halus tanpa getaran sensor
    double filteredZ = _kalman.update(0.2, rawDiffZ);
    _elevationStream.add(filteredZ);
  }

  /// Sinkronkan tekanan referensi Base Station (dari Anchor A via BLE/P2P)
  void setBaseReferencePressure({required double baseHpa, double? knownBaseElevation}) {
    _basePressure = baseHpa;
    if (knownBaseElevation != null) {
      _baseElevation = knownBaseElevation;
    }
  }

  /// Hitung elevasi diferensial saat ini
  double getCurrentRelativeElevation() {
    return GeodeticUtils.calculateDifferentialElevation(
      pBase: _basePressure,
      pRover: _currentPressure,
      tempC: _ambientTemperature,
      baseElevation: _baseElevation,
    );
  }
}

