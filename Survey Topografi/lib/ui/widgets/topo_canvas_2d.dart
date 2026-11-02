import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/topo_dataset.dart';
import '../../core/math/multilateration.dart';
import '../theme/topo_theme.dart';

/// Kanvas Topografi 2D Interaktif (TIN Mesh & Garis Kontur)
class TopoCanvas2D extends StatelessWidget {
  final TopoDataset dataset;
  final Vector3D currentRoverPos;
  final bool showTin;
  final bool showContours;
  final bool showLabels;

  const TopoCanvas2D({
    super.key,
    required this.dataset,
    required this.currentRoverPos,
    this.showTin = true,
    this.showContours = true,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TopoTheme.bgDark,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(300),
        minScale: 0.2,
        maxScale: 6.0,
        child: CustomPaint(
          size: const Size(600, 600),
          painter: _TopoCanvasPainter(
            dataset: dataset,
            rover: currentRoverPos,
            showTin: showTin,
            showContours: showContours,
            showLabels: showLabels,
          ),
        ),
      ),
    );
  }
}

class _TopoCanvasPainter extends CustomPainter {
  final TopoDataset dataset;
  final Vector3D rover;
  final bool showTin;
  final bool showContours;
  final bool showLabels;

  _TopoCanvasPainter({
    required this.dataset,
    required this.rover,
    required this.showTin,
    required this.showContours,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double scale = 14.0; // 14 piksel per meter

    // 1. Gambar Grid Latar Belakang Kartesian (interval 5 meter)
    final gridPaint = Paint()
      ..color = TopoTheme.borderDark.withOpacity(0.4)
      ..strokeWidth = 0.8;

    for (double i = -150; i <= 150; i += 5) {
      double screenX = center.dx + i * scale;
      double screenY = center.dy - i * scale;
      canvas.drawLine(Offset(screenX, 0), Offset(screenX, size.height), gridPaint);
      canvas.drawLine(Offset(0, screenY), Offset(size.width, screenY), gridPaint);
    }

    // 2. Gambar Jaring Segitiga TIN (Triangulated Irregular Network)
    if (showTin && dataset.tinTriangles.isNotEmpty) {
      final tinLinePaint = Paint()
        ..color = TopoTheme.borderDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      for (var tri in dataset.tinTriangles) {
        final p1 = Offset(center.dx + tri.a.x * scale, center.dy - tri.a.y * scale);
        final p2 = Offset(center.dx + tri.b.x * scale, center.dy - tri.b.y * scale);
        final p3 = Offset(center.dx + tri.c.x * scale, center.dy - tri.c.y * scale);

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

        // Shading berdasarkan elevasi rata-rata
        Color triColor = TopoTheme.getElevationColor(
          tri.meanElevation,
          dataset.minElevation,
          dataset.maxElevation,
        ).withOpacity(0.18);

        canvas.drawPath(path, Paint()..color = triColor..style = PaintingStyle.fill);
        canvas.drawPath(path, tinLinePaint);
      }
    }

    // 3. Gambar Garis Kontur Topografi
    if (showContours && dataset.contourSegments.isNotEmpty) {
      final intermediatePaint = Paint()
        ..color = const Color(0xFFFBBF24).withOpacity(0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final indexPaint = Paint()
        ..color = const Color(0xFFEA580C)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      for (var c in dataset.contourSegments) {
        final start = Offset(center.dx + c.start.x * scale, center.dy - c.start.y * scale);
        final end = Offset(center.dx + c.end.x * scale, center.dy - c.end.y * scale);

        canvas.drawLine(start, end, c.isIndexContour ? indexPaint : intermediatePaint);

        if (c.isIndexContour && showLabels) {
          final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
          _drawText(
            canvas,
            '${c.elevation.toStringAsFixed(1)}m',
            mid,
            const Color(0xFFEA580C),
            8,
          );
        }
      }
    }

    // 4. Gambar Titik-titik Survei yang Sudah Direkam
    final pointPaint = Paint()..style = PaintingStyle.fill;
    for (var p in dataset.points) {
      final screenPos = Offset(center.dx + p.localPosition.x * scale, center.dy - p.localPosition.y * scale);

      pointPaint.color = TopoTheme.getElevationColor(
        p.groundElevation,
        dataset.minElevation,
        dataset.maxElevation,
      );

      canvas.drawCircle(screenPos, 4.5, pointPaint);
      canvas.drawCircle(
        screenPos,
        6.5,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      if (showLabels) {
        _drawText(
          canvas,
          '${p.id} (${p.groundElevation.toStringAsFixed(2)}m)',
          Offset(screenPos.dx + 6, screenPos.dy - 10),
          TopoTheme.textLight,
          8,
        );
      }
    }

    // 5. Gambar Posisi Realtime Rover
    final roverScreen = Offset(center.dx + rover.x * scale, center.dy - rover.y * scale);
    canvas.drawCircle(
      roverScreen,
      8.0,
      Paint()..color = TopoTheme.safetyAmber..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      roverScreen,
      14.0,
      Paint()
        ..color = TopoTheme.safetyAmber.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double fontSize) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black.withOpacity(0.6),
      ),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _TopoCanvasPainter oldDelegate) => true;
}

