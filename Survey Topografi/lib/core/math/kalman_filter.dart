import 'dart:math';

/// 1D Kalman Filter untuk meredam noise fluktuasi sinyal BLE RSSI
/// dan mengestimasi jarak yang stabil ke masing-masing handphone anchor.
class RssiKalmanFilter {
  double _q; // Process noise covariance (fluktuasi gerakan fisik rover)
  double _r; // Measurement noise covariance (noise radio frekuensi BLE)
  double _x; // State estimasi (RSSI terfilter)
  double _p; // Estimation error covariance
  double _k = 0; // Kalman gain
  bool _initialized = false;

  RssiKalmanFilter({
    double processNoise = 0.05,
    double measurementNoise = 2.5,
  })  : _q = processNoise,
        _r = measurementNoise,
        _x = -70.0,
        _p = 1.0;

  /// Masukkan nilai RSSI mentah (dBm), mengembalikan nilai RSSI halus
  double filter(double rawRssi) {
    if (!_initialized) {
      _x = rawRssi;
      _p = 1.0;
      _initialized = true;
      return _x;
    }

    // 1. Time Update (Predict)
    _p = _p + _q;

    // 2. Measurement Update (Correct)
    _k = _p / (_p + _r);
    _x = _x + _k * (rawRssi - _x);
    _p = (1 - _k) * _p;

    return _x;
  }

  double get currentEstimate => _x;
  double get errorCovariance => _p;
  bool get isInitialized => _initialized;

  void reset() {
    _initialized = false;
  }
}

/// Model Propagasi Log-Distance Path Loss untuk mengubah RSSI menjadi Jarak (Meter)
class BleDistanceEstimator {
  /// Kalibrasi RSSI pada jarak 1 meter (TxPower @ 1m, tipikal -59 s/d -65 dBm pada HP)
  final double txPowerAt1m;

  /// Eksponen atenuasi lingkungan (n):
  /// n = 2.0 (Ruang terbuka / Line-of-sight ideal)
  /// n = 2.5 (Area lapangan survei dengan sedikit vegetasi)
  /// n = 3.0 (Area rintangan tanah bergelombang / pepohonan)
  final double pathLossExponent;

  final RssiKalmanFilter kalman;

  BleDistanceEstimator({
    this.txPowerAt1m = -62.0,
    this.pathLossExponent = 2.4,
  }) : kalman = RssiKalmanFilter();

  /// Hitung jarak dari RSSI mentah setelah melalui filter Kalman
  double estimateDistance(double rawRssi) {
    double filteredRssi = kalman.filter(rawRssi);
    return convertRssiToDistance(filteredRssi, txPowerAt1m, pathLossExponent);
  }

  /// Rumus Log-Distance Path Loss: d = 10 ^ ((A - RSSI) / (10 * n))
  static double convertRssiToDistance(double rssi, double a, double n) {
    if (rssi >= 0) return 0.2; // Nilai anomali / sangat dekat
    double ratio = (a - rssi) / (10.0 * n);
    double distance = pow(10.0, ratio).toDouble();
    // Batasi dalam rentang praktis survei BLE (0.1m - 80m)
    return distance.clamp(0.1, 100.0);
  }
}

/// Filter Kalman untuk Fusi Ketinggian Permukaan (Z):
/// Menggabungkan pembacaan Barometer Diferensial (resolusi tinggi, drift rendah antar base-rover)
/// dan akselerometer vertikal.
class SurfaceElevationKalmanFilter {
  double _z = 0.0;     // Ketinggian estimasi (meter)
  double _vz = 0.0;    // Kecepatan vertikal (meter/detik)
  double _p00 = 1.0;
  double _p01 = 0.0;
  double _p10 = 0.0;
  double _p11 = 1.0;

  final double _qZ;    // Process noise elevasi
  final double _qVz;   // Process noise kecepatan
  final double _rBaro; // Measurement noise barometer diferensial (sekitar 0.15m)

  bool _isInit = false;

  SurfaceElevationKalmanFilter({
    double processNoiseZ = 0.02,
    double processNoiseVz = 0.1,
    double baroNoise = 0.15,
  })  : _qZ = processNoiseZ,
        _qVz = processNoiseVz,
        _rBaro = baroNoise;

  /// Update dengan selang waktu dt (detik), akselerasi vertikal (m/s^2), dan elevasi barometer (m)
  double update(double dt, double baroElevation, [double vertAccel = 0.0]) {
    if (!_isInit) {
      _z = baroElevation;
      _vz = 0.0;
      _isInit = true;
      return _z;
    }

    // 1. Predict state
    _z += _vz * dt + 0.5 * vertAccel * dt * dt;
    _vz += vertAccel * dt;

    // Predict covariance
    double p00Temp = _p00 + dt * (_p10 + _p01) + dt * dt * _p11 + _qZ;
    double p01Temp = _p01 + dt * _p11;
    double p10Temp = _p10 + dt * _p11;
    double p11Temp = _p11 + _qVz;

    // 2. Correct state with baro observation
    double y = baroElevation - _z; // Inovasi pengukuran
    double s = p00Temp + _rBaro;
    double k0 = p00Temp / s;
    double k1 = p10Temp / s;

    _z += k0 * y;
    _vz += k1 * y;

    // Correct covariance
    _p00 = (1.0 - k0) * p00Temp;
    _p01 = (1.0 - k0) * p01Temp;
    _p10 = -k1 * p00Temp + p10Temp;
    _p11 = -k1 * p01Temp + p11Temp;

    return _z;
  }

  double get elevation => _z;
  double get verticalVelocity => _vz;
  void reset(double initialZ) {
    _z = initialZ;
    _vz = 0.0;
    _isInit = true;
  }
}

