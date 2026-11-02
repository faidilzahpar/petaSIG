import 'dart:math';
import 'multilateration.dart';

/// Segitiga pada jaring TIN (Triangulated Irregular Network)
class TinTriangle {
  final Vector3D a;
  final Vector3D b;
  final Vector3D c;

  TinTriangle(this.a, this.b, this.c);

  /// Cek apakah titik p berada di dalam circumcircle (lingkaran luar) segitiga (proyeksi 2D X-Y)
  bool inCircumcircle2D(Vector3D p) {
    double ax = a.x - p.x;
    double ay = a.y - p.y;
    double bx = b.x - p.x;
    double by = b.y - p.y;
    double cx = c.x - p.x;
    double cy = c.y - p.y;

    double det = (ax * ax + ay * ay) * (bx * cy - cx * by) -
                 (bx * bx + by * by) * (ax * cy - cx * ay) +
                 (cx * cx + cy * cy) * (ax * by - bx * ay);

    // CCW check
    double orientation = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    if (orientation < 0) {
      return det < 0;
    }
    return det > 0;
  }

  /// Menghitung kemiringan lereng rata-rata (slope gradient dalam %)
  double get slopePercentage {
    // Normal vector n = (b - a) x (c - a)
    double v1x = b.x - a.x, v1y = b.y - a.y, v1z = b.z - a.z;
    double v2x = c.x - a.x, v2y = c.y - a.y, v2z = c.z - a.z;

    double nx = v1y * v2z - v1z * v2y;
    double ny = v1z * v2x - v1x * v2z;
    double nz = v1x * v2y - v1y * v2x;

    if (nz.abs() < 1e-6) return 999.0;
    double horizontalGrad = sqrt(nx * nx + ny * ny) / nz.abs();
    return horizontalGrad * 100.0;
  }

  /// Luas 2D segitiga
  double get area2D {
    return 0.5 * ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)).abs();
  }

  /// Elevasi rata-rata segitiga
  double get meanElevation => (a.z + b.z + c.z) / 3.0;
}

class Edge2D {
  final Vector3D u;
  final Vector3D v;

  Edge2D(this.u, this.v);

  bool isSame(Edge2D other) {
    return (u == other.u && v == other.v) || (u == other.v && v == other.u);
  }
}

/// Generator Triangulated Irregular Network (TIN) dengan Algoritma Bowyer-Watson
class DelaunayTinGenerator {
  /// Membangun jaring segitiga Delaunay dari kumpulan titik ukur survei topografi
  static List<TinTriangle> triangulate(List<Vector3D> points) {
    if (points.length < 3) return [];

    // Tentukan bounding box
    double minX = points.first.x, maxX = points.first.x;
    double minY = points.first.y, maxY = points.first.y;
    double minZ = points.first.z, maxZ = points.first.z;

    for (var p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }

    double dx = maxX - minX;
    double dy = maxY - minY;
    double deltaMax = max(dx, dy) * 2;
    if (deltaMax < 10) deltaMax = 10;
    double midX = (minX + maxX) / 2;
    double midY = (minY + maxY) / 2;
    double avgZ = (minZ + maxZ) / 2;

    // Super-segitiga yang melingkupi semua titik
    final p1 = Vector3D(midX - 2 * deltaMax, midY - deltaMax, avgZ);
    final p2 = Vector3D(midX, midY + 2 * deltaMax, avgZ);
    final p3 = Vector3D(midX + 2 * deltaMax, midY - deltaMax, avgZ);

    List<TinTriangle> triangles = [TinTriangle(p1, p2, p3)];

    // Masukkan setiap titik satu per satu (Incremental Delaunay)
    for (var point in points) {
      List<TinTriangle> badTriangles = [];
      List<Edge2D> polygon = [];

      for (var tri in triangles) {
        if (tri.inCircumcircle2D(point)) {
          badTriangles.add(tri);
        }
      }

      // Cari tepi poligon batas rongga (cavity)
      for (var tri in badTriangles) {
        List<Edge2D> edges = [
          Edge2D(tri.a, tri.b),
          Edge2D(tri.b, tri.c),
          Edge2D(tri.c, tri.a),
        ];

        for (var edge in edges) {
          bool shared = false;
          for (var otherTri in badTriangles) {
            if (otherTri == tri) continue;
            List<Edge2D> otherEdges = [
              Edge2D(otherTri.a, otherTri.b),
              Edge2D(otherTri.b, otherTri.c),
              Edge2D(otherTri.c, otherTri.a),
            ];
            if (otherEdges.any((oe) => oe.isSame(edge))) {
              shared = true;
              break;
            }
          }
          if (!shared) {
            polygon.add(edge);
          }
        }
      }

      // Hapus segitiga lama yang melanggar kondisi Delaunay
      triangles.removeWhere((t) => badTriangles.contains(t));

      // Bentuk segitiga baru menghubungkan titik baru ke setiap edge batas poligon
      for (var edge in polygon) {
        triangles.add(TinTriangle(edge.u, edge.v, point));
      }
    }

    // Hapus segitiga yang mengandung simpul dari super-segitiga
    triangles.removeWhere((t) =>
        t.a == p1 || t.a == p2 || t.a == p3 ||
        t.b == p1 || t.b == p2 || t.b == p3 ||
        t.c == p1 || t.c == p2 || t.c == p3);

    return triangles;
  }
}

