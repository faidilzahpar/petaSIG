import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/topo_theme.dart';

/// Widget Waterpass Digital (Dual-Axis Bubble Spirit Level)
/// Memastikan jalon survei tegak lurus sempurna (< 2.0 derajat deviasi) saat merekam elevasi tanah
class BubbleLevelWidget extends StatelessWidget {
  final double pitch; // Derajat (-90 s/d +90)
  final double roll;  // Derajat (-90 s/d +90)
  final double size;

  const BubbleLevelWidget({
    super.key,
    required this.pitch,
    required this.roll,
    this.size = 110.0,
  });

  @override
  Widget build(BuildContext context) {
    double tilt = sqrt(pitch * pitch + roll * roll);
    bool isLevel = tilt <= 2.0;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TopoTheme.surfaceDark,
        shape: BoxShape.circle,
        border: Border.all(
          color: isLevel ? TopoTheme.statusGreen : TopoTheme.borderDark,
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _LevelCrosshairPainter(isLevel: isLevel),
          ),
          // Gelembung udara bergerak
          _BubbleIndicator(
            pitch: pitch,
            roll: roll,
            maxRadius: (size - 24) / 2,
            isLevel: isLevel,
          ),
          // Label Sudut Kemiringan
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '${tilt.toStringAsFixed(1)}°',
                style: TextStyle(
                  color: isLevel ? TopoTheme.statusGreen : TopoTheme.alertRed,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _LevelCrosshairPainter extends CustomPainter {
  final bool isLevel;
  _LevelCrosshairPainter({required this.isLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintLine = Paint()
      ..color = TopoTheme.borderDark
      ..strokeWidth = 1.0;

    // Garis bidik silang
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paintLine);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paintLine);

    // Lingkaran target toleransi 2 derajat
    final paintTolerance = Paint()
      ..color = isLevel ? TopoTheme.statusGreen.withOpacity(0.4) : TopoTheme.borderDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 12.0, paintTolerance);
    canvas.drawCircle(center, size.width / 2 - 4, paintLine);
  }

  @override
  bool shouldRepaint(covariant _LevelCrosshairPainter oldDelegate) =>
      oldDelegate.isLevel != isLevel;
}

class _BubbleIndicator extends StatelessWidget {
  final double pitch;
  final double roll;
  final double maxRadius;
  final bool isLevel;

  const _BubbleIndicator({
    required this.pitch,
    required this.roll,
    required this.maxRadius,
    required this.isLevel,
  });

  @override
  Widget build(BuildContext context) {
    // 10 derajat kemiringan mencapai batas tepi widget
    double dx = (roll / 10.0).clamp(-1.0, 1.0) * maxRadius;
    double dy = (pitch / 10.0).clamp(-1.0, 1.0) * maxRadius;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: isLevel ? TopoTheme.statusGreen : TopoTheme.safetyAmber,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isLevel ? TopoTheme.statusGreen : TopoTheme.safetyAmber).withOpacity(0.6),
              blurRadius: 6,
            )
          ],
        ),
      ),
    );
  }
}

