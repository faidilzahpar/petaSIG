import 'package:flutter_test/flutter_test.dart';
import 'package:topo_survey_mesh/core/math/multilateration.dart';
import 'package:topo_survey_mesh/core/math/delaunay_tin.dart';
import 'package:topo_survey_mesh/core/math/contour_engine.dart';
import 'package:topo_survey_mesh/core/models/topo_dataset.dart';
import 'package:topo_survey_mesh/core/models/survey_point.dart';
import 'package:topo_survey_mesh/core/export/csv_exporter.dart';
import 'package:topo_survey_mesh/core/export/geojson_exporter.dart';
import 'package:topo_survey_mesh/core/export/dxf_exporter.dart';

void main() {
  group('TIN Surface, Contour Engine & Export Tests', () {
    test('Builds Delaunay TIN mesh and extracts contour lines', () {
      final points = [
        Vector3D(0.0, 0.0, 100.0),
        Vector3D(10.0, 0.0, 100.5),
        Vector3D(10.0, 10.0, 102.0),
        Vector3D(0.0, 10.0, 101.5),
        Vector3D(5.0, 5.0, 101.0),
      ];

      final tin = DelaunayTinGenerator.triangulate(points);
      expect(tin.isNotEmpty, isTrue);
      expect(tin.length, greaterThanOrEqualTo(4));

      final contours = ContourEngine.generateContourSegments(
        triangles: tin,
        interval: 0.5,
      );

      expect(contours.isNotEmpty, isTrue);
      // Cek segmen kontur memiliki elevasi 100.5, 101.0, 101.5
      expect(contours.any((c) => (c.elevation - 101.0).abs() < 0.01), isTrue);
    });

    test('Exports dataset to CSV, GeoJSON and DXF properly', () {
      final dataset = TopoDataset(projectName: 'Test Project');
      dataset.addPoint(
        SurveyPoint(
          id: 'PT-001',
          code: 'BM',
          description: 'Benchmark',
          timestamp: DateTime.now(),
          localPosition: const Vector3D(1.0, 2.0, 100.0),
          easting: 684201.0,
          northing: 9245102.0,
          utmZone: 48,
          isNorth: false,
          latitude: -6.82,
          longitude: 107.61,
          altitudeMsl: 100.0,
          rmse: 0.12,
          gdop: 1.5,
          anchorCount: 3,
          baroPressure: 1001.2,
          poleHeight: 0.0,
        ),
      );

      final csv = CsvExporter.exportPnezd(dataset);
      expect(csv.contains('PT-001'), isTrue);
      expect(csv.contains('684201.000'), isTrue);

      final geojson = GeoJsonExporter.exportGeoJson(dataset);
      expect(geojson.contains('FeatureCollection'), isTrue);
      expect(geojson.contains('PT-001'), isTrue);

      final dxf = DxfExporter.exportDxf(dataset);
      expect(dxf.contains('SURVEY_POINTS'), isTrue);
      expect(dxf.contains('SECTION'), isTrue);
    });
  });
}

