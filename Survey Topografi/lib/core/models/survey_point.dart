import '../math/multilateration.dart';

/// Titik hasil pengukuran survei topografi
class SurveyPoint {
  final String id;
  final String code;             // Kode fitur survei: BM, GL, TS, CR, BL, RD, WL, dll.
  final String description;
  final DateTime timestamp;

  // Koordinat Relatif Lokal Mesh (meter)
  final Vector3D localPosition;

  // Koordinat Global Proyeksi UTM
  final double easting;
  final double northing;
  final int utmZone;
  final bool isNorth;

  // Geodetik WGS84
  final double latitude;
  final double longitude;
  final double altitudeMsl; // Orthometric Height MSL (meter)

  // Metrik Kualitas & Sensor Fisik
  final double rmse;        // Root Mean Square Error (meter)
  final double gdop;        // Geometric Dilution of Precision
  final int anchorCount;    // Jumlah handphone anchor yang melacak saat pengukuran
  final double baroPressure;// Tekanan udara saat titik diambil (hPa)
  final double poleHeight;  // Tinggi jalon / pole survei (meter, offset koreksi Z)

  const SurveyPoint({
    required this.id,
    required this.code,
    required this.description,
    required this.timestamp,
    required this.localPosition,
    required this.easting,
    required this.northing,
    required this.utmZone,
    required this.isNorth,
    required this.latitude,
    required this.longitude,
    required this.altitudeMsl,
    required this.rmse,
    required this.gdop,
    required this.anchorCount,
    required this.baroPressure,
    this.poleHeight = 1.5, // Standar jalon survei 1.5m / 2.0m
  });

  /// Ketinggian elevasi permukaan tanah murni (Z dikurangi tinggi jalon)
  double get groundElevation => altitudeMsl - poleHeight;

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'local': {'x': localPosition.x, 'y': localPosition.y, 'z': localPosition.z},
    'utm': {'easting': easting, 'northing': northing, 'zone': utmZone, 'isNorth': isNorth},
    'wgs84': {'lat': latitude, 'lon': longitude, 'alt': altitudeMsl},
    'quality': {'rmse': rmse, 'gdop': gdop, 'anchors': anchorCount},
    'sensors': {'baro': baroPressure, 'poleHeight': poleHeight, 'groundZ': groundElevation},
  };
}

