import 'package:flutter/material.dart';
import '../../core/math/multilateration.dart';
import '../theme/topo_theme.dart';

/// Telemetry HUD (Heads-Up Display) Data Geodetik & Sensor Lapangan
class TelemetryHud extends StatelessWidget {
  final Vector3D localPos;
  final double easting;
  final double northing;
  final double elevationZ;
  final double baseDeltaZ;
  final double baroPressure;
  final MultilaterationResult multResult;
  final int activeAnchors;
  final bool isLevel;

  const TelemetryHud({
    super.key,
    required this.localPos,
    required this.easting,
    required this.northing,
    required this.elevationZ,
    required this.baseDeltaZ,
    required this.baroPressure,
    required this.multResult,
    required this.activeAnchors,
    required this.isLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TopoTheme.surfaceDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TopoTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeAnchors >= 3 ? TopoTheme.statusGreen : TopoTheme.alertRed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'MULTILATERASI: $activeAnchors ANCHORS ACTIVE',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: TopoTheme.textLight,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: multResult.rmse < 1.0
                      ? TopoTheme.statusGreen.withOpacity(0.15)
                      : TopoTheme.safetyAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: multResult.rmse < 1.0 ? TopoTheme.statusGreen : TopoTheme.safetyAmber,
                  ),
                ),
                child: Text(
                  multResult.accuracyGrade,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: multResult.rmse < 1.0 ? TopoTheme.statusGreen : TopoTheme.safetyAmber,
                  ),
                ),
              )
            ],
          ),
          const Divider(color: TopoTheme.borderDark, height: 16),

          // Baris Utama: Elevasi Z (Ketinggian Permukaan Tanah)
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SURFACE ELEVATION (Z MSL)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: TopoTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          elevationZ.toStringAsFixed(3),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: TopoTheme.textLight,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'm',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TopoTheme.laserCyan,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TopoTheme.cardDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REL. TO BASE (ΔZ)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8,
                          color: TopoTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${baseDeltaZ >= 0 ? "+" : ""}${baseDeltaZ.toStringAsFixed(3)} m',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: baseDeltaZ >= 0 ? TopoTheme.statusGreen : TopoTheme.safetyAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Baris Kedua: Koordinat Kartesian Lokal & Proyeksi UTM
          Row(
            children: [
              Expanded(
                child: _hudStatBox('LOCAL X', '${localPos.x.toStringAsFixed(2)} m', TopoTheme.laserCyan),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _hudStatBox('LOCAL Y', '${localPos.y.toStringAsFixed(2)} m', TopoTheme.laserCyan),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _hudStatBox('RMSE (σ)', '±${multResult.rmse.toStringAsFixed(2)} m',
                    multResult.rmse < 1.0 ? TopoTheme.statusGreen : TopoTheme.safetyAmber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _hudStatBox('GDOP', multResult.gdop.toStringAsFixed(1),
                    multResult.gdop < 3.0 ? TopoTheme.statusGreen : TopoTheme.textLight),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Baris Ketiga: Tekanan Barometer & Koordinat UTM
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: TopoTheme.cardDark.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'UTM E: ${easting.toStringAsFixed(1)} | N: ${northing.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: TopoTheme.textMuted,
                  ),
                ),
                Text(
                  'BARO: ${baroPressure.toStringAsFixed(2)} hPa',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: TopoTheme.laserCyan,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _hudStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: TopoTheme.cardDark,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 7.5,
              color: TopoTheme.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

