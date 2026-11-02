import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/topo_dataset.dart';
import '../../core/models/survey_point.dart';
import '../../core/models/survey_node.dart';
import '../../core/math/multilateration.dart';
import '../../core/math/geodetic_utils.dart';
import '../../core/sensors/ble_mesh_service.dart';
import '../../core/sensors/barometer_service.dart';
import '../../core/sensors/bubble_level_service.dart';
import '../theme/topo_theme.dart';
import '../widgets/bubble_level_widget.dart';
import '../widgets/mesh_radar_widget.dart';
import '../widgets/telemetry_hud.dart';

class SurveyScreen extends StatefulWidget {
  final TopoDataset dataset;
  final VoidCallback onDatasetUpdated;

  const SurveyScreen({
    super.key,
    required this.dataset,
    required this.onDatasetUpdated,
  });

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final BleMeshService _bleMesh = BleMeshService();
  final BarometerService _baro = BarometerService();
  final BubbleLevelService _bubble = BubbleLevelService();

  StreamSubscription? _bleSub;
  StreamSubscription? _levelSub;
  Timer? _sensorTicker;

  // State Realtime
  Vector3D _currentLocalPos = const Vector3D(8.5, 6.2, 100.8);
  double _easting = 684210.5;
  double _northing = 9245120.3;
  double _groundElevation = 99.3; // Z - poleHeight
  double _baseDeltaZ = 0.8;
  double _poleHeight = 1.5; // Tinggi jalon survei (meter)
  String _currentCode = 'GL'; // Ground Level
  int _pointCounter = 1;

  MultilaterationResult _lastMultResult = const MultilaterationResult(
    estimatedPosition: Vector3D(8.5, 6.2, 100.8),
    rmse: 0.18,
    gdop: 1.8,
    iterations: 4,
    isConverged: true,
    statusMessage: 'Konvergensi optimal',
  );

  final List<String> _featureCodes = ['GL', 'CR', 'TS', 'BM', 'BL', 'RD', 'WL'];

  @override
  void initState() {
    super.initState();
    _startSensors();
  }

  void _startSensors() {
    // Mulai pemindaian BLE (secara default menyalakan simulasi cerdas agar langsung siap dipakai)
    _bleMesh.startScan(simulate: true);

    _bleSub = _bleMesh.nodeStream.listen((nodes) {
      if (!mounted) return;
      _computePositionFromNodes(nodes);
    });

    _levelSub = _bubble.levelStream.listen((_) {
      if (mounted) setState(() {});
    });

    // Ticker untuk update akselerometer halus
    double t = 0;
    _sensorTicker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      t += 0.2;
      // Simulasi sedikit goyangan jalon waterpass saat dipegang surveyor
      _bubble.updateAccelerometer(
        0.15 * (1 + 0.3 * (t % 2)),
        0.08 * (1 - 0.2 * (t % 3)),
        9.8,
      );
      if (mounted) setState(() {});
    });
  }

  void _computePositionFromNodes(Map<String, SurveyNode> nodes) {
    List<AnchorObservation> obs = [];
    for (var node in nodes.values) {
      if (node.role != NodeRole.rover) {
        obs.add(node.toObservation());
      }
    }

    if (obs.length >= 3) {
      final res = MultilaterationSolver.solve(
        anchors: obs,
        initialZGuess: _baro.getCurrentRelativeElevation(),
      );

      setState(() {
        _lastMultResult = res;
        _currentLocalPos = res.estimatedPosition;
        _groundElevation = _currentLocalPos.z - _poleHeight;
        _baseDeltaZ = _groundElevation - _baro.baseElevation;

        // Proyeksi ke UTM
        _easting = 684200.0 + _currentLocalPos.x;
        _northing = 9245100.0 + _currentLocalPos.y;
      });
    }
  }

  void _logSurveyPoint() {
    if (!_bubble.isPlumbAndLevel) {
      // Peringatan jika jalon miring
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PERINGATAN: Jalon survei miring (${_bubble.tiltAngle.toStringAsFixed(1)}°)! Tegakkan waterpass sebelum merekam.'),
          backgroundColor: TopoTheme.alertRed,
          duration: const Duration(seconds: 2),
        ),
      );
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();

    final ptId = 'PT-${_pointCounter.toString().padLeft(3, '0')}';
    final newPoint = SurveyPoint(
      id: ptId,
      code: _currentCode,
      description: 'Point $_currentCode via BLE Trileterasi',
      timestamp: DateTime.now(),
      localPosition: _currentLocalPos,
      easting: _easting,
      northing: _northing,
      utmZone: 48,
      isNorth: false, // Belahan bumi selatan (Indonesia)
      latitude: -6.82415,
      longitude: 107.61842,
      altitudeMsl: _currentLocalPos.z,
      rmse: _lastMultResult.rmse,
      gdop: _lastMultResult.gdop,
      anchorCount: _bleMesh.activeNodes.length,
      baroPressure: _baro.currentPressure,
      poleHeight: _poleHeight,
    );

    widget.dataset.addPoint(newPoint);
    widget.onDatasetUpdated();
    _pointCounter++;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Titik $ptId ($currentCodeTitle) Terekam | Z: ${_groundElevation.toStringAsFixed(2)}m'),
        backgroundColor: TopoTheme.statusGreen,
        duration: const Duration(seconds: 1),
      ),
    );

    setState(() {});
  }

  String get currentCodeTitle {
    switch (_currentCode) {
      case 'GL': return 'Ground Surface';
      case 'CR': return 'Crest / Ridge';
      case 'TS': return 'Toe of Slope';
      case 'BM': return 'Benchmark';
      case 'BL': return 'Breakline';
      case 'RD': return 'Road / Pathway';
      case 'WL': return 'Water Level';
      default: return _currentCode;
    }
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _levelSub?.cancel();
    _sensorTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Telemetry HUD Lengkap
              TelemetryHud(
                localPos: _currentLocalPos,
                easting: _easting,
                northing: _northing,
                elevationZ: _groundElevation,
                baseDeltaZ: _baseDeltaZ,
                baroPressure: _baro.currentPressure,
                multResult: _lastMultResult,
                activeAnchors: _bleMesh.activeNodes.length,
                isLevel: _bubble.isPlumbAndLevel,
              ),
              const SizedBox(height: 12),

              // Baris Waterpass dan Pengaturan Jalon
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Waterpass Bubble Spirit Level
                  BubbleLevelWidget(
                    pitch: _bubble.pitch,
                    roll: _bubble.roll,
                    size: 96,
                  ),
                  const SizedBox(width: 12),

                  // Detail Pole & Status Kemiringan
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TopoTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _bubble.isPlumbAndLevel ? TopoTheme.statusGreen : TopoTheme.alertRed,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _bubble.isPlumbAndLevel ? '● JALON TEGAK (PLUMB)' : '▲ JALON MIRING',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _bubble.isPlumbAndLevel ? TopoTheme.statusGreen : TopoTheme.alertRed,
                                ),
                              ),
                              Text(
                                '${_bubble.tiltAngle.toStringAsFixed(1)}°',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _bubble.isPlumbAndLevel ? TopoTheme.statusGreen : TopoTheme.alertRed,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'POLE HEIGHT:',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color: TopoTheme.textMuted,
                                ),
                              ),
                              DropdownButton<double>(
                                value: _poleHeight,
                                dropdownColor: TopoTheme.cardDark,
                                underline: const SizedBox(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: TopoTheme.laserCyan,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 0.0, child: Text('0.00 m (Ground)')),
                                  DropdownMenuItem(value: 1.3, child: Text('1.30 m')),
                                  DropdownMenuItem(value: 1.5, child: Text('1.50 m (Standard)')),
                                  DropdownMenuItem(value: 1.8, child: Text('1.80 m')),
                                  DropdownMenuItem(value: 2.0, child: Text('2.00 m (Prism)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _poleHeight = val);
                                },
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Visualisasi Radar Mesh 3 Handphone
              MeshRadarWidget(
                nodes: _bleMesh.activeNodes,
                roverPosition: _currentLocalPos,
                height: 180,
              ),
              const SizedBox(height: 12),

              // Pemilih Kode Fitur Topografi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: TopoTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: TopoTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FEATURE CODE (JENIS PERMUKAAN):',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: TopoTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _featureCodes.map((code) {
                          bool isSelected = _currentCode == code;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                code,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isSelected ? Colors.black : TopoTheme.textLight,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: TopoTheme.safetyAmber,
                              backgroundColor: TopoTheme.cardDark,
                              onSelected: (_) => setState(() => _currentCode = code),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tombol Rekam Titik Survei
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _logSurveyPoint,
                  icon: const Icon(Icons.my_location, size: 22),
                  label: Text(
                    'REKAM TITIK SURVEI [PT-${_pointCounter.toString().padLeft(3, '0')}]',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

