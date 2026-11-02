import 'package:flutter/material.dart';
import '../core/models/topo_dataset.dart';
import '../core/models/survey_point.dart';
import '../core/math/multilateration.dart';
import 'theme/topo_theme.dart';
import 'screens/survey_screen.dart';
import 'screens/map_contour_screen.dart';
import 'screens/mesh_config_screen.dart';
import 'screens/point_list_screen.dart';
import 'screens/export_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final TopoDataset _dataset = TopoDataset(projectName: 'Proyek Topografi Lahan');

  @override
  void initState() {
    super.initState();
    _loadSampleBenchmarkPoints();
  }

  void _loadSampleBenchmarkPoints() {
    // Muat contoh titik awal untuk demonstrasi kontur & TIN seketika
    final samples = [
      {'id': 'PT-001', 'x': 2.0, 'y': 3.0, 'z': 100.0, 'code': 'BM'},
      {'id': 'PT-002', 'x': 18.0, 'y': 2.5, 'z': 100.3, 'code': 'GL'},
      {'id': 'PT-003', 'x': 17.5, 'y': 15.0, 'z': 101.8, 'code': 'CR'},
      {'id': 'PT-004', 'x': 3.0, 'y': 16.0, 'z': 101.2, 'code': 'TS'},
      {'id': 'PT-005', 'x': 10.0, 'y': 8.5, 'z': 100.9, 'code': 'GL'},
      {'id': 'PT-006', 'x': 8.0, 'y': 14.0, 'z': 101.4, 'code': 'BL'},
    ];

    for (var s in samples) {
      _dataset.addPoint(
        SurveyPoint(
          id: s['id'] as String,
          code: s['code'] as String,
          description: 'Benchmark Sample',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          localPosition: Vector3D(s['x'] as double, s['y'] as double, s['z'] as double),
          easting: 684200.0 + (s['x'] as double),
          northing: 9245100.0 + (s['y'] as double),
          utmZone: 48,
          isNorth: false,
          latitude: -6.82415,
          longitude: 107.61842,
          altitudeMsl: s['z'] as double,
          rmse: 0.15,
          gdop: 1.6,
          anchorCount: 3,
          baroPressure: 1001.2,
          poleHeight: 0.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SurveyScreen(
        dataset: _dataset,
        onDatasetUpdated: () => setState(() {}),
      ),
      MapContourScreen(
        dataset: _dataset,
        onDatasetUpdated: () => setState(() {}),
      ),
      const MeshConfigScreen(),
      PointListScreen(
        dataset: _dataset,
        onDatasetUpdated: () => setState(() {}),
      ),
      ExportScreen(dataset: _dataset),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: TopoTheme.safetyAmber,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'TOPOMESH',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'GEODETIC SURVEYOR',
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: TopoTheme.surfaceDark,
        selectedItemColor: TopoTheme.safetyAmber,
        unselectedItemColor: TopoTheme.textMuted,
        selectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 9),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.my_location),
            label: 'SURVEI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terrain),
            label: 'KONTUR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_input_antenna),
            label: 'JARINGAN',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_numbered),
            label: 'TITIK',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'EKSPOR',
          ),
        ],
      ),
    );
  }
}

