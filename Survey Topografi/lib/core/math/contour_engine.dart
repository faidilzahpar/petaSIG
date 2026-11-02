import 'dart:math';
import 'multilateration.dart';
import 'delaunay_tin.dart';

/// Segmen garis kontur pada elevasi tertentu
class ContourSegment {
  final Vector3D start;
  final Vector3D end;
  final double elevation;
  final bool isIndexContour; // Kontur indeks (biasanya setiap kelipatan 5x interval, digambar lebih tebal)

  ContourSegment({
    required this.start,
    required this.end,
    required this.elevation,
    this.isIndexContour = false,
  });
}

/// Poligaris Kontur tersambung
class ContourLine {
  final double elevation;
  final List<Vector3D> points;
  final bool isIndexContour;

  ContourLine({
    required this.elevation,
    required this.points,
    this.isIndexContour = false,
  });
}

/// Mesin Interpolasi Garis Kontur Topografi (Marching Triangles)
class ContourEngine {
  /// Menghasilkan segmen garis kontur dari jaring TIN dengan interval elevasi tertentu
  static List<ContourSegment> generateContourSegments({
    required List<TinTriangle> triangles,
    double interval = 0.5, // Interval kontur (meter), misal 0.5m atau 1.0m
    int indexMultiplier = 5, // Tiap kelipatan ke-5 adalah kontur indeks
  }) {
    if (triangles.isEmpty || interval <= 0) return [];

    // Cari rentang Z global
    double minZ = double.infinity;
    double maxZ = -double.infinity;

    for (var tri in triangles) {
      minZ = min(minZ, min(tri.a.z, min(tri.b.z, tri.c.z)));
      maxZ = max(maxZ, max(tri.a.z, max(tri.b.z, tri.c.z)));
    }

    if (minZ == double.infinity || (maxZ - minZ) < 0.01) return [];

    double startLevel = (minZ / interval).ceil() * interval;
    List<ContourSegment> segments = [];

    for (double level = startLevel; level <= maxZ; level += interval) {
      bool isIndex = (level / (interval * indexMultiplier)).roundToDouble() ==
                     (level / (interval * indexMultiplier));

      for (var tri in triangles) {
        final seg = _interpolateTriangle(tri, level, isIndex);
        if (seg != null) {
          segments.add(seg);
        }
      }
    }

    return segments;
  }

  /// Interpolasi perpotongan bidang elevasi kontur dengan sebuah segitiga TIN
  static ContourSegment? _interpolateTriangle(TinTriangle tri, double zLevel, bool isIndex) {
    List<Vector3D> intersections = [];

    _checkEdge(tri.a, tri.b, zLevel, intersections);
    _checkEdge(tri.b, tri.c, zLevel, intersections);
    _checkEdge(tri.c, tri.a, zLevel, intersections);

    if (intersections.length == 2) {
      return ContourSegment(
        start: intersections[0],
        end: intersections[1],
        elevation: zLevel,
        isIndexContour: isIndex,
      );
    }

    return null;
  }

  static void _checkEdge(Vector3D p1, Vector3D p2, double z, List<Vector3D> intersections) {
    if ((p1.z <= z && p2.z >= z) || (p1.z >= z && p2.z <= z)) {
      double dz = p2.z - p1.z;
      if (dz.abs() > 1e-6) {
        double t = (z - p1.z) / dz;
        // Interpolasi linear X dan Y pada ketinggian Z yang sama
        double x = p1.x + t * (p2.x - p1.x);
        double y = p1.y + t * (p2.y - p1.y);
        intersections.add(Vector3D(x, y, z));
      }
    }
  }
}

