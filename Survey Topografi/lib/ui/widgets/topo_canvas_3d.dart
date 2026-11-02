import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/topo_dataset.dart';
import '../../core/math/multilateration.dart';
import '../theme/topo_theme.dart';

/// Kanvas Relief Topografi 3D (Proyeksi Isometrik / Axonometrik Berbobot Z)
class TopoCanvas3D extends StatefulWidget {
  final TopoDataset dataset;

  const TopoCanvas3D({super.key, required this.dataset});

  @override
  State<TopoCanvas3D> createState() => _TopoCanvas3DState();
}

class _TopoCanvas3DState extends State<TopoCanvas3D> {
  double _yaw = 45.0 * pi / 180.0;   // Rotasi horizontal (rad)
  double _pitch = 30.0 * pi / 180.0; // Sudut pandang vertikal (rad)
  double _zExaggeration = 2.5;       // Faktor elevasi vertikal untuk visualisasi relief

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _yaw += details.delta.dx * 0.01;
          _pitch = (_pitch - details.delta.dy * 0.01).clamp(0.1, 1.4);
        });
      },
      child: Container(
        color: TopoTheme.bgDark,
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _Topo3DPainter(
                dataset: widget.dataset,
                yaw: _yaw,
                pitch: _pitch,
                zExaggeration: _zExaggeration,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TopoTheme.surfaceDark.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: TopoTheme.borderDark),
                ),
                child: Text(
                  '3D RELIEF (Z EXAG: ${_zExaggeration.toStringAsFixed(1)}x)\nGeser layar untuk memutar sudut pandang',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: TopoTheme.textMuted,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _Topo3DPainter extends CustomPainter {
  final TopoDataset dataset;
  final double yaw;
  final double pitch;
  final double zExaggeration;

  _Topo3DPainter({
    required this.dataset,
    required this.yaw,
    required this.pitch,
    required this.zExaggeration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    const double scale = 12.0;

    double cosYaw = cos(yaw);
    double sinYaw = sin(yaw);
    double cosPitch = cos(pitch);
    double sinPitch = sin(pitch);

    Offset project(Vector3D v, double minZ) {
      // Rotasi Yaw (Horizontal)
      double x1 = v.x * cosYaw - v.y * sinYaw;
      double y1 = v.x * sinYaw + v.y * cosYaw;

      // Z relatif terhadap minZ dengan faktor eksagerasi
      double relZ = (v.z - minZ) * zExaggeration;

      // Proyeksi Pitch (Vertikal)
      double screenX = center.dx + x1 * scale;
      double screenY = center.dy + (-y1 * sinPitch - relZ * cosPitch) * scale;

      return Offset(screenX, screenY);
    }

    double minZ = dataset.minElevation;

    // 1. Gambar Wireframe Jaring TIN 3D
    final linePaint = Paint()
      ..color = TopoTheme.laserCyan.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var tri in dataset.tinTriangles) {
      final p1 = project(tri.a, minZ);
      final p2 = project(tri.b, minZ);
      final p3 = project(tri.c, minZ);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      Color triColor = TopoTheme.getElevationColor(
        tri.meanElevation,
        dataset.minElevation,
        dataset.maxElevation,
      ).withOpacity(0.25);

      canvas.drawPath(path, Paint()..color = triColor..style = PaintingStyle.fill);
      canvas.drawPath(path, linePaint);
    }

    // 2. Gambar Titik-titik Puncak Survei 3D
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (var p in dataset.points) {
      final pt = project(
        Vector3D(p.localPosition.x, p.localPosition.y, p.groundElevation),
        minZ,
      );

      nodePaint.color = TopoTheme.getElevationColor(
        p.groundElevation,
        dataset.minElevation,
        dataset.maxElevation,
      );

      canvas.drawCircle(pt, 4.0, nodePaint);

      // Garis drop vertikal ke bidang dasar (datum)
      final ptBase = project(
        Vector3D(p.localPosition.x, p.localPosition.y, minZ),
        minZ,
      );
      canvas.drawLine(
        pt,
        ptBase,
        Paint()
          ..color = TopoTheme.borderDark.withOpacity(0.5)
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Topo3DPainter oldDelegate) => true;
}

