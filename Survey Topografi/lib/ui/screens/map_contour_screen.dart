import 'package:flutter/material.dart';
import '../../core/models/topo_dataset.dart';
import '../../core/math/multilateration.dart';
import '../theme/topo_theme.dart';
import '../widgets/topo_canvas_2d.dart';
import '../widgets/topo_canvas_3d.dart';

class MapContourScreen extends StatefulWidget {
  final TopoDataset dataset;
  final VoidCallback onDatasetUpdated;

  const MapContourScreen({
    super.key,
    required this.dataset,
    required this.onDatasetUpdated,
  });

  @override
  State<MapContourScreen> createState() => _MapContourScreenState();
}

class _MapContourScreenState extends State<MapContourScreen> {
  bool _is3DView = false;
  bool _showTin = true;
  bool _showContours = true;
  bool _showLabels = true;
  double _datumLevel = 100.0;

  @override
  void initState() {
    super.initState();
    if (widget.dataset.points.isNotEmpty) {
      _datumLevel = (widget.dataset.minElevation + widget.dataset.maxElevation) / 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataset;
    final cutFill = ds.computeCutFillVolume(_datumLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PETA TOPOGRAFI & KONTUR'),
        actions: [
          IconButton(
            icon: Icon(_is3DView ? Icons.map : Icons.view_in_ar),
            tooltip: _is3DView ? 'Pindah ke 2D Plan' : 'Pindah ke 3D Relief',
            onPressed: () => setState(() => _is3DView = !_is3DView),
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Bar: Layer toggles & Interval
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: TopoTheme.surfaceDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _toggleChip('TIN', _showTin, () => setState(() => _showTin = !_showTin)),
                    const SizedBox(width: 6),
                    _toggleChip('KONTUR', _showContours, () => setState(() => _showContours = !_showContours)),
                    const SizedBox(width: 6),
                    _toggleChip('LABEL', _showLabels, () => setState(() => _showLabels = !_showLabels)),
                  ],
                ),
                // Dropdown Interval Kontur
                Row(
                  children: [
                    const Text('INT:', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: TopoTheme.textMuted)),
                    const SizedBox(width: 4),
                    DropdownButton<double>(
                      value: ds.contourInterval,
                      dropdownColor: TopoTheme.cardDark,
                      underline: const SizedBox(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: TopoTheme.safetyAmber, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 0.25, child: Text('0.25m')),
                        DropdownMenuItem(value: 0.50, child: Text('0.50m')),
                        DropdownMenuItem(value: 1.00, child: Text('1.00m')),
                        DropdownMenuItem(value: 2.00, child: Text('2.00m')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            ds.contourInterval = val;
                            ds.recomputeSurfaceModel();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main View: 2D Canvas atau 3D Wireframe
          Expanded(
            child: ds.points.isEmpty
                ? _buildEmptyState()
                : _is3DView
                    ? TopoCanvas3D(dataset: ds)
                    : TopoCanvas2D(
                        dataset: ds,
                        currentRoverPos: const Vector3D(8.5, 6.2, 100.8),
                        showTin: _showTin,
                        showContours: _showContours,
                        showLabels: _showLabels,
                      ),
          ),

          // Bottom Bar: Statistik Topografi & Cut-Fill Volume
          Container(
            padding: const EdgeInsets.all(10),
            color: TopoTheme.surfaceDark,
            child: Column(
              children: [
                // Legenda Elevasi (Hypsometric Tint)
                Row(
                  children: [
                    Text(
                      '${ds.minElevation.toStringAsFixed(1)}m',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: TopoTheme.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF065F46),
                              Color(0xFF10B981),
                              Color(0xFFFBBF24),
                              Color(0xFFEA580C),
                              Color(0xFFF8FAFC),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${ds.maxElevation.toStringAsFixed(1)}m',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: TopoTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Baris Info Geometrik & Cut/Fill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _bottomStat('TITIK', '${ds.points.length}'),
                    _bottomStat('SEGITIGA TIN', '${ds.tinTriangles.length}'),
                    _bottomStat('BEDA TINGGI', '${ds.reliefDifference.toStringAsFixed(2)}m'),
                    _bottomStat('LUAS AREA', '${ds.totalSurfaceArea.toStringAsFixed(1)}m²'),
                    _bottomStat('CUT / FILL', '${cutFill['net']?.toStringAsFixed(1)}m³'),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? TopoTheme.safetyAmber : TopoTheme.cardDark,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : TopoTheme.textLight,
          ),
        ),
      ),
    );
  }

  Widget _bottomStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: TopoTheme.textMuted)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: TopoTheme.textLight)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.terrain, size: 48, color: TopoTheme.borderDark),
          SizedBox(height: 12),
          Text(
            'BELUM ADA TITIK TOPOGRAFI',
            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: TopoTheme.textMuted),
          ),
          SizedBox(height: 6),
          Text(
            'Gunakan menu SURVEI untuk merekam titik pertama Anda.',
            style: TextStyle(fontSize: 12, color: TopoTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

