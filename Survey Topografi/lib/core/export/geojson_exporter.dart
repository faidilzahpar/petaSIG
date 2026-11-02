import 'dart:convert';
import '../models/topo_dataset.dart';

/// Eksportir Format Standar SIG (GeoJSON FeatureCollection)
class GeoJsonExporter {
  static String exportGeoJson(TopoDataset dataset) {
    List<Map<String, dynamic>> features = [];

    // 1. Titik-titik survei
    for (var p in dataset.points) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [p.longitude, p.latitude, p.groundElevation],
        },
        'properties': {
          'id': p.id,
          'code': p.code,
          'description': p.description,
          'elevation_m': p.groundElevation,
          'rmse_m': p.rmse,
          'gdop': p.gdop,
          'anchors': p.anchorCount,
          'timestamp': p.timestamp.toIso8601String(),
        }
      });
    }

    // 2. Garis Kontur Topografi
    for (var c in dataset.contourSegments) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          // Perkiraan koordinat lokal
          'coordinates': [
            [c.start.x, c.start.y, c.elevation],
            [c.end.x, c.end.y, c.elevation],
          ],
        },
        'properties': {
          'elevation': c.elevation,
          'is_index': c.isIndexContour,
        }
      });
    }

    final geoJson = {
      'type': 'FeatureCollection',
      'metadata': {
        'project': dataset.projectName,
        'surveyor': dataset.surveyorName,
        'created_at': dataset.createdAt.toIso8601String(),
        'point_count': dataset.points.length,
        'min_elevation': dataset.minElevation,
        'max_elevation': dataset.maxElevation,
        'relief': dataset.reliefDifference,
      },
      'features': features,
    };

    return const JsonEncoder.withIndent('  ').convert(geoJson);
  }
}

