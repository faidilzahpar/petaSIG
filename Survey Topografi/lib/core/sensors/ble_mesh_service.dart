import 'dart:async';
import 'dart:math';
import '../models/survey_node.dart';
import '../math/multilateration.dart';
import '../math/kalman_filter.dart';

/// Service BLE Mesh & Ranging untuk sinkronisasi antar minimal 3 handphone survei
class BleMeshService {
  static final BleMeshService _instance = BleMeshService._internal();
  factory BleMeshService() => _instance;
  BleMeshService._internal();

  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isSimulationMode = false;

  final Map<String, SurveyNode> _nodes = {};
  final Map<String, BleDistanceEstimator> _estimators = {};

  final StreamController<Map<String, SurveyNode>> _nodeStreamController =
      StreamController<Map<String, SurveyNode>>.broadcast();

  Stream<Map<String, SurveyNode>> get nodeStream => _nodeStreamController.stream;
  Map<String, SurveyNode> get activeNodes => Map.unmodifiable(_nodes);

  Timer? _simTimer;
  Timer? _pruneTimer;

  // Kalibrasi BLE default
  double txPowerAt1m = -60.0; // dBm
  double pathLossExponent = 2.4; // Lingkungan lapangan terbuka

  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  bool get isSimulationMode => _isSimulationMode;

  /// Memulai pemindaian BLE aktif
  Future<void> startScan({bool simulate = false}) async {
    _isSimulationMode = simulate;
    _isScanning = true;

    // Bersihkan node yang tidak aktif secara periodik
    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pruneStaleNodes();
    });

    if (simulate) {
      _startSimulationConstellation();
    }
  }

  /// Hentikan pemindaian
  Future<void> stopScan() async {
    _isScanning = false;
    _simTimer?.cancel();
    _pruneTimer?.cancel();
  }

  /// Update data node yang diterima dari sinyal BLE (atau UDP Multicast P2P)
  void updateNodeObservation({
    required String id,
    required String deviceName,
    required NodeRole role,
    required double rawRssi,
    required double baroPressure,
    required Vector3D localPos,
    int battery = 100,
  }) {
    if (!_estimators.containsKey(id)) {
      _estimators[id] = BleDistanceEstimator(
        txPowerAt1m: txPowerAt1m,
        pathLossExponent: pathLossExponent,
      );
    }

    final estimator = _estimators[id]!;
    final double dist = estimator.estimateDistance(rawRssi);
    final double filteredRssi = estimator.kalman.currentEstimate;

    if (_nodes.containsKey(id)) {
      final node = _nodes[id]!;
      node.rawRssi = rawRssi;
      node.filteredRssi = filteredRssi;
      node.measuredDistance = dist;
      node.baroPressure = baroPressure;
      node.localPosition = localPos;
      node.lastSeen = DateTime.now();
      node.batteryLevel = battery;
    } else {
      _nodes[id] = SurveyNode(
        id: id,
        deviceName: deviceName,
        role: role,
        localPosition: localPos,
        rawRssi: rawRssi,
        filteredRssi: filteredRssi,
        measuredDistance: dist,
        baroPressure: baroPressure,
        batteryLevel: battery,
      );
    }

    _nodeStreamController.add(_nodes);
  }

  void _pruneStaleNodes() {
    final now = DateTime.now();
    _nodes.removeWhere((id, node) => now.difference(node.lastSeen).inSeconds > 10);
    _nodeStreamController.add(_nodes);
  }

  /// Mode Simulasi Cerdas (Untuk Pengujian Lapangan / Demonstrasi Ketika Hanya 1 HP Aktif)
  /// Mensimulasikan 3 titik Anchor Base dengan karakteristik fluktuasi radio BLE nyata
  void _startSimulationConstellation() {
    _simTimer?.cancel();

    // Buat konfigurasi segitiga anchor ideal dengan baseline 20 meter
    // Anchor A (Base di 0,0, Z=100.0)
    // Anchor B (di 20, 0, Z=100.2)
    // Anchor C (di 10, 17.32, Z=101.5)
    final random = Random();

    // Posisi rover bergerak simulasi
    double roverX = 8.5;
    double roverY = 6.2;
    double roverZ = 100.8;

    _simTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!_isScanning) return;

      final anchors = [
        {
          'id': 'BLE_ANCHOR_A_BASE',
          'name': 'Anchor A (Base Station 0,0)',
          'role': NodeRole.anchorA_Base,
          'pos': const Vector3D(0.0, 0.0, 100.0),
          'baro': 1001.25,
        },
        {
          'id': 'BLE_ANCHOR_B',
          'name': 'Anchor B (Sumbu X Baseline)',
          'role': NodeRole.anchorB,
          'pos': const Vector3D(20.0, 0.0, 100.2),
          'baro': 1001.22,
        },
        {
          'id': 'BLE_ANCHOR_C',
          'name': 'Anchor C (Triangulasi Y)',
          'role': NodeRole.anchorC,
          'pos': const Vector3D(10.0, 17.32, 101.5),
          'baro': 1001.08,
        },
      ];

      for (var a in anchors) {
        final pos = a['pos'] as Vector3D;
        double realDist = sqrt(
          pow(roverX - pos.x, 2) +
          pow(roverY - pos.y, 2) +
          pow(roverZ - pos.z, 2)
        );

        // Simulasi RSSI dengan Log-Distance Path Loss + Gaussian Shadowing Noise (Multipath)
        double idealRssi = txPowerAt1m - 10 * pathLossExponent * (log(max(0.1, realDist)) / ln10);
        double noise = (random.nextDouble() - 0.5) * 3.5; // +/- 1.75 dBm noise
        double simulatedRssi = (idealRssi + noise).clamp(-95.0, -35.0);

        updateNodeObservation(
          id: a['id'] as String,
          deviceName: a['name'] as String,
          role: a['role'] as NodeRole,
          rawRssi: simulatedRssi,
          baroPressure: (a['baro'] as double) + (random.nextDouble() - 0.5) * 0.02,
          localPos: pos,
          battery: 88,
        );
      }
    });
  }

  /// Kalibrasi otomatis parameter A (TxPower @ 1m) dan n (Path Loss Exponent)
  /// Menggunakan jarak diketahui antar 2 Anchor stationary
  void autoCalibratePathLoss({required double knownDistanceMeters, required double measuredRssi}) {
    if (knownDistanceMeters <= 0.5) return;
    // n = (A - RSSI) / (10 * log10(d))
    double log10D = log(knownDistanceMeters) / ln10;
    double calculatedN = (txPowerAt1m - measuredRssi) / (10.0 * log10D);
    pathLossExponent = calculatedN.clamp(1.8, 3.5);
  }
}

