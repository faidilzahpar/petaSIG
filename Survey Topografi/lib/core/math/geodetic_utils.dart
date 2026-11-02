import 'dart:math';

/// Utilitas Geodesi untuk konversi WGS84 (Lat, Lon, Alt) ke Koordinat Cartesian Proyeksi UTM (Easting, Northing)
/// dan Sistem Koordinat Relatif Lokal (Local Tangent Plane / ENU).
class GeodeticUtils {
  static const double wgs84A = 6378137.0; // Sumbu semi-mayor bumi (meter)
  static const double wgs84F = 1 / 298.257223563; // Flattening
  static const double wgs84B = 6356752.314245; // Sumbu semi-minor
  static const double wgs84E2 = 0.00669437999014; // Eksentrisitas kuadrat pertama

  /// Konversi Lat/Lon (WGS84 Derajat Desimal) ke UTM (Easting, Northing dalam meter)
  static UtmCoordinate latLonToUtm(double lat, double lon) {
    int zone = ((lon + 180) / 6).floor() + 1;
    bool isNorthernHemisphere = lat >= 0;

    double latRad = lat * pi / 180.0;
    double lonRad = lon * pi / 180.0;

    // Meridian sentral zona UTM
    double centralMeridian = ((zone - 1) * 6 - 180 + 3) * pi / 180.0;

    double k0 = 0.9996;
    double ePrime2 = (wgs84E2) / (1 - wgs84E2);

    double n = wgs84A / sqrt(1 - wgs84E2 * sin(latRad) * sin(latRad));
    double t = tan(latRad) * tan(latRad);
    double c = ePrime2 * cos(latRad) * cos(latRad);
    double a = cos(latRad) * (lonRad - centralMeridian);

    // Meridian distance M
    double m = wgs84A * (
        (1 - wgs84E2 / 4 - 3 * wgs84E2 * wgs84E2 / 64 - 5 * pow(wgs84E2, 3) / 256) * latRad -
        (3 * wgs84E2 / 8 + 3 * wgs84E2 * wgs84E2 / 32 + 45 * pow(wgs84E2, 3) / 1024) * sin(2 * latRad) +
        (15 * wgs84E2 * wgs84E2 / 256 + 45 * pow(wgs84E2, 3) / 1024) * sin(4 * latRad) -
        (35 * pow(wgs84E2, 3) / 3072) * sin(6 * latRad)
    );

    double easting = k0 * n * (
        a +
        (1 - t + c) * pow(a, 3) / 6 +
        (5 - 18 * t + t * t + 72 * c - 58 * ePrime2) * pow(a, 5) / 120
    ) + 500000.0;

    double northing = k0 * (
        m +
        n * tan(latRad) * (
            a * a / 2 +
            (5 - t + 9 * c + 4 * c * c) * pow(a, 4) / 24 +
            (61 - 58 * t + t * t + 600 * c - 330 * ePrime2) * pow(a, 6) / 720
        )
    );

    if (!isNorthernHemisphere) {
      northing += 10000000.0; // False northing untuk belahan bumi selatan (misal sebagian besar Indonesia)
    }

    return UtmCoordinate(
      easting: easting,
      northing: northing,
      zone: zone,
      isNorthernHemisphere: isNorthernHemisphere,
    );
  }

  /// Menghitung jarak geodesic horizontal antara dua koordinat Lat/Lon (Formula Haversine / Vincenty approx)
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000.0; // Radius rata-rata bumi (meter)
    double phi1 = lat1 * pi / 180.0;
    double phi2 = lat2 * pi / 180.0;
    double deltaPhi = (lat2 - lat1) * pi / 180.0;
    double deltaLambda = (lon2 - lon1) * pi / 180.0;

    double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  /// Menghitung elevasi ortometrik dari rumus barometrik diferensial
  /// [pBase]: Tekanan udara di Base Station (hPa)
  /// [pRover]: Tekanan udara di Rover (hPa)
  /// [tempC]: Suhu rata-rata udara (Celsius)
  /// [baseElevation]: Ketinggian Benchmark awal di Base Station (meter dpl)
  static double calculateDifferentialElevation({
    required double pBase,
    required double pRover,
    double tempC = 25.0,
    double baseElevation = 0.0,
  }) {
    if (pBase <= 0 || pRover <= 0) return baseElevation;

    // Formula Hypsometrik Atmosfer Standar Internasional:
    // delta_h = (R * T / (g * M)) * ln(P_base / P_rover)
    // Pendekatan standar barometrik: h = 44330 * (1 - (P / P0)^(1/5.255))
    // Dengan baseline diferensial relatif terhadap Base:
    double tKelvin = 273.15 + tempC;
    const double gasConstant = 287.058; // R_spesifik udara kering J/(kg·K)
    const double g = 9.80665; // Gravitasi standar m/s^2

    double deltaH = (gasConstant * tKelvin / g) * log(pBase / pRover);
    return baseElevation + deltaH;
  }
}

class UtmCoordinate {
  final double easting;
  final double northing;
  final int zone;
  final bool isNorthernHemisphere;

  const UtmCoordinate({
    required this.easting,
    required this.northing,
    required this.zone,
    required this.isNorthernHemisphere,
  });

  @override
  String toString() => 'UTM Zone $zone${isNorthernHemisphere ? "N" : "S"} E: ${easting.toStringAsFixed(2)} N: ${northing.toStringAsFixed(2)}';
}

