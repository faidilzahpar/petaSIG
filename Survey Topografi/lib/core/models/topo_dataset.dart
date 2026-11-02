import 'dart:math';
import 'survey_point.dart';
import 'survey_node.dart';
import '../math/multilateration.dart';
import '../math/delaunay_tin.dart';
import '../math/contour_engine.dart';

/// Proyek Survei Topografi Lengkap
class TopoDataset {
  final String projectName;
  final String surveyorName;
  final String locationDescription;
  final DateTime createdAt;
  final List<SurveyPoint> points = [];
  final Map<String, SurveyNode> nodes = {};

  List<TinTriangle> tinTriangles = [];
  List<ContourSegment> contourSegments = [];
  double contourInterval = 0.5; // meter

  TopoDataset({
    required this.projectName,
    this.surveyorName = 'Surveyor Team',
    this.locationDescription = 'Area Pemetaan Topografi',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  void addPoint(SurveyPoint point) {
    points.add(point);
    recomputeSurfaceModel();
  }

  void removePoint(String id) {
    points.removeWhere((p) => p.id == id);
    recomputeSurfaceModel();
  }

  void clearPoints() {
    points.clear();
    tinTriangles.clear();
    contourSegments.clear();
  }

  /// Hitung ulang jaring segitiga TIN dan garis kontur
  void recomputeSurfaceModel() {
    if (points.length < 3) {
      tinTriangles.clear();
      contourSegments.clear();
      return;
    }

    // Ambil koordinat lokal X, Y, dan elevasi permukaan tanah murni (Z)
    List<Vector3D> vertices = points
        .map((p) => Vector3D(p.localPosition.x, p.localPosition.y, p.groundElevation))
        .toList();

    tinTriangles = DelaunayTinGenerator.triangulate(vertices);
    contourSegments = ContourEngine.generateContourSegments(
      triangles: tinTriangles,
      interval: contourInterval,
    );
  }

  // Statistik Ketinggian dan Area
  double get minElevation {
    if (points.isEmpty) return 0.0;
    return points.map((p) => p.groundElevation).reduce(min);
  }

  double get maxElevation {
    if (points.isEmpty) return 0.0;
    return points.map((p) => p.groundElevation).reduce(max);
  }

  double get reliefDifference => maxElevation - minElevation;

  double get totalSurfaceArea {
    if (tinTriangles.isEmpty) return 0.0;
    return tinTriangles.map((t) => t.area2D).reduce((a, b) => a + b);
  }

  /// Estimasi volume tanah (Cut & Fill terhadap Datum rata-rata) dalam meter kubik
  Map<String, double> computeCutFillVolume(double datumElevation) {
    double cutVol = 0.0;
    double fillVol = 0.0;

    for (var tri in tinTriangles) {
      double dz = tri.meanElevation - datumElevation;
      double vol = tri.area2D * dz.abs();
      if (dz >= 0) {
        cutVol += vol;
      } else {
        fillVol += vol;
      }
    }
    return {'cut': cutVol, 'fill': fillVol, 'net': cutVol - fillVol};
  }
}

