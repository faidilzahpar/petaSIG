import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/survey_node.dart';
import '../../core/math/multilateration.dart';
import '../theme/topo_theme.dart';

/// Widget Radar Konstelasi Multilaterasi Multi-Handphone
class MeshRadarWidget extends StatelessWidget {
  final Map<String, SurveyNode> nodes;
  final Vector3D roverPosition;
  final double width;
  final double height;

  const MeshRadarWidget({
    super.key,
    required this.nodes,
    required this.roverPosition,
    this.width = double.infinity,
    this.height = 200.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: TopoTheme.surfaceDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TopoTheme.borderDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(
          size: Size(width, height),
          painter: _MeshRadarPainter(
            nodes: nodes,
            rover: roverPosition,
          ),
        ),
      ),
    );
  }
}

class _MeshRadarPainter extends CustomPainter {
  final Map<String, SurveyNode> nodes;
  final Vector3D rover;

  _MeshRadarPainter({required this.nodes, required this.rover});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Gambar grid lingkaran konsentris radar (jarak 5m, 10m, 20m, 30m)
    final gridPaint = Paint()
      ..color = TopoTheme.borderDark.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double maxRange = 35.0; // meter
    double scale = (min(size.width, size.height) * 0.42) / maxRange;

    for (double r in [10.0, 20.0, 30.0]) {
      canvas.drawCircle(center, r * scale, gridPaint);
      _drawText(canvas, '${r.toInt()}m', Offset(center.dx + r * scale + 2, center.dy - 10),
          TopoTheme.textMuted, 8);
    }

    // Sumbu X and Y
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);

    // 2. Gambar garis trilaterasi dari Anchor ke Rover
    final rayPaint = Paint()
      ..color = TopoTheme.laserCyan.withOpacity(0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final roverScreenPos = Offset(
      center.dx + rover.x * scale,
      center.dy - rover.y * scale, // Flip Y untuk koordinat kartesian
    );

    for (var node in nodes.values) {
      final anchorScreenPos = Offset(
        center.dx + node.localPosition.x * scale,
        center.dy - node.localPosition.y * scale,
      );

      // Garis vektor trilaterasi
      canvas.drawLine(anchorScreenPos, roverScreenPos, rayPaint);

      // Label Jarak Terukur di tengah garis
      final midRay = Offset(
        (anchorScreenPos.dx + roverScreenPos.dx) / 2,
        (anchorScreenPos.dy + roverScreenPos.dy) / 2,
      );
      _drawText(
        canvas,
        '${node.measuredDistance.toStringAsFixed(1)}m',
        midRay,
        TopoTheme.laserCyan,
        8,
      );

      // Lingkaran node Anchor
      final nodePaint = Paint()
        ..color = _getAnchorColor(node.role)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(anchorScreenPos, 6.0, nodePaint);
      canvas.drawCircle(
        anchorScreenPos,
        9.0,
        Paint()
          ..color = _getAnchorColor(node.role).withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label Nama Node
      _drawText(
        canvas,
        '${node.role.shortCode}\n${node.filteredRssi.toStringAsFixed(0)}dBm',
        Offset(anchorScreenPos.dx + 8, anchorScreenPos.dy - 12),
        TopoTheme.textLight,
        9,
      );
    }

    // 3. Gambar Posisi Rover (Surveyor)
    final roverPaint = Paint()
      ..color = TopoTheme.safetyAmber
      ..style = PaintingStyle.fill;

    canvas.drawCircle(roverScreenPos, 7.0, roverPaint);
    canvas.drawCircle(
      roverScreenPos,
      12.0,
      Paint()
        ..color = TopoTheme.safetyAmber.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    _drawText(
      canvas,
      'ROVER (${rover.x.toStringAsFixed(1)}, ${rover.y.toStringAsFixed(1)})',
      Offset(roverScreenPos.dx + 10, roverScreenPos.dy + 4),
      TopoTheme.safetyAmber,
      9,
    );
  }

  Color _getAnchorColor(NodeRole role) {
    switch (role) {
      case NodeRole.anchorA_Base: return TopoTheme.statusGreen;
      case NodeRole.anchorB: return const Color(0xFF38BDF8);
      case NodeRole.anchorC: return const Color(0xFFA855F7);
      default: return TopoTheme.textMuted;
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double fontSize) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _MeshRadarPainter oldDelegate) => true;
}

