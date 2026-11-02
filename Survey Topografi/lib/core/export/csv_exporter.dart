import '../models/survey_point.dart';
import '../models/topo_dataset.dart';

/// Eksportir Data Survei ke Format CSV (PNEZD: Point, Northing, Easting, Z-Elevation, Description)
class CsvExporter {
  static String exportPnezd(TopoDataset dataset) {
    final StringBuffer sb = StringBuffer();
    // Header Standar Surveyor
    sb.writeln('Point_ID,Northing_Y_m,Easting_X_m,Elevation_Z_m,Feature_Code,Local_X,Local_Y,RMSE_m,GDOP,Anchors,Baro_hPa,Timestamp');

    for (var p in dataset.points) {
      sb.writeln(
        '${p.id},'
        '${p.northing.toStringAsFixed(3)},'
        '${p.easting.toStringAsFixed(3)},'
        '${p.groundElevation.toStringAsFixed(3)},'
        '${p.code},'
        '${p.localPosition.x.toStringAsFixed(3)},'
        '${p.localPosition.y.toStringAsFixed(3)},'
        '${p.rmse.toStringAsFixed(2)},'
        '${p.gdop.toStringAsFixed(2)},'
        '${p.anchorCount},'
        '${p.baroPressure.toStringAsFixed(2)},'
        '${p.timestamp.toIso8601String()}'
      );
    }

    return sb.toString();
  }
}

