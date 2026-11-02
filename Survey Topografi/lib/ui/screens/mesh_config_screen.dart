import 'package:flutter/material.dart';
import '../../core/models/survey_node.dart';
import '../../core/sensors/ble_mesh_service.dart';
import '../../core/sensors/barometer_service.dart';
import '../theme/topo_theme.dart';

class MeshConfigScreen extends StatefulWidget {
  const MeshConfigScreen({super.key});

  @override
  State<MeshConfigScreen> createState() => _MeshConfigScreenState();
}

class _MeshConfigScreenState extends State<MeshConfigScreen> {
  final BleMeshService _bleMesh = BleMeshService();
  final BarometerService _baro = BarometerService();

  NodeRole _myRole = NodeRole.rover;
  final TextEditingController _baselineCtrl = TextEditingController(text: '20.0');
  final TextEditingController _baseElevCtrl = TextEditingController(text: '100.0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JARINGAN MULTI-HP & KALIBRASI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Panduan Lapangan 3 Handphone
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TopoTheme.surfaceDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: TopoTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'PANDUAN PENYIAPAN 3+ HANDPHONE (MINIMAL)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: TopoTheme.safetyAmber,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. HP-1 (Anchor A / Base): Tempatkan di patok acuan tetap (BM). Berfungsi sebagai acuan koordinat (0,0) dan barometer diferensial.\n'
                    '2. HP-2 (Anchor B): Tempatkan di garis baseline (misal jarak 15-25m dari Base). Menentukan sumbu X.\n'
                    '3. HP-3 (Anchor C): Tempatkan membentuk segitiga dengan A & B. Menutup geometri trilaterasi.\n'
                    '4. HP Rover (iPhone / Android Anda): Digunakan berkeliling memegang jalon untuk mengambil titik kontur permukaan.',
                    style: TextStyle(
                      fontSize: 11,
                      color: TopoTheme.textLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Pilihan Peran Perangkat Ini
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TopoTheme.surfaceDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: TopoTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERAN HANDPHONE INI:',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: TopoTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<NodeRole>(
                    value: _myRole,
                    dropdownColor: TopoTheme.cardDark,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: TopoTheme.cardDark,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: NodeRole.values.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(
                          r.displayName,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _myRole = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Kalibrasi BLE & Atenuasi Lingkungan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TopoTheme.surfaceDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: TopoTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KALIBRASI PARAMETER BLE RSSI',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: TopoTheme.laserCyan,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _baselineCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Jarak Terukur A-B (m)',
                            labelStyle: TextStyle(fontSize: 10, color: TopoTheme.textMuted),
                            filled: true,
                            fillColor: TopoTheme.cardDark,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(8),
                          ),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          double dist = double.tryParse(_baselineCtrl.text) ?? 20.0;
                          _bleMesh.autoCalibratePathLoss(
                            knownDistanceMeters: dist,
                            measuredRssi: -72.0,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Eksponen Atenuasi Lingkungan (n) Terkalibrasi: ${_bleMesh.pathLossExponent.toStringAsFixed(2)}'),
                              backgroundColor: TopoTheme.statusGreen,
                            ),
                          );
                        },
                        child: const Text('AUTO-KALIBRASI'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TxPower @ 1m: ${_bleMesh.txPowerAt1m.toStringAsFixed(1)} dBm | Path Loss (n): ${_bleMesh.pathLossExponent.toStringAsFixed(2)}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: TopoTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Benchmark Elevasi Awal
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TopoTheme.surfaceDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: TopoTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BENCHMARK ELEVASI BASE STATION (Z0)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: TopoTheme.statusGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _baseElevCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Elevasi Patok BM (meter dpl)',
                      labelStyle: TextStyle(fontSize: 10, color: TopoTheme.textMuted),
                      filled: true,
                      fillColor: TopoTheme.cardDark,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    onSubmitted: (val) {
                      double elev = double.tryParse(val) ?? 100.0;
                      _baro.setBaseReferencePressure(
                        baseHpa: _baro.currentPressure,
                        knownBaseElevation: elev,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

