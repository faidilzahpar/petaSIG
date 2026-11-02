import '../math/multilateration.dart';

enum NodeRole {
  anchorA_Base,  // Base Station Utama (Titik 0,0,Z0 / Referensi Barometrik)
  anchorB,       // Titik Acuan Kedua (Sumbu Baseline X)
  anchorC,       // Titik Acuan Ketiga (Menutup Segitiga Trilaterasi)
  anchorExtra,   // Titik Acuan Tambahan (D, E, dst. untuk redundancy)
  rover,         // Handphone Bergerak Pembawa Jalon Survei
}

extension NodeRoleExt on NodeRole {
  String get displayName {
    switch (this) {
      case NodeRole.anchorA_Base: return 'Anchor A (Base Station 0,0)';
      case NodeRole.anchorB: return 'Anchor B (Baseline X)';
      case NodeRole.anchorC: return 'Anchor C (Triangulation)';
      case NodeRole.anchorExtra: return 'Anchor Cadangan';
      case NodeRole.rover: return 'Rover (Surveyor Probe)';
    }
  }

  String get shortCode {
    switch (this) {
      case NodeRole.anchorA_Base: return 'A-BASE';
      case NodeRole.anchorB: return 'ANC-B';
      case NodeRole.anchorC: return 'ANC-C';
      case NodeRole.anchorExtra: return 'ANC+';
      case NodeRole.rover: return 'ROVER';
    }
  }
}

/// State Handphone yang terhubung dalam jaringan Mesh Survei
class SurveyNode {
  final String id;
  final String deviceName;
  final NodeRole role;
  Vector3D localPosition;
  double latitude;
  double longitude;
  double altitudeMsl;
  double baroPressure; // hPa
  double rawRssi;      // dBm
  double filteredRssi; // dBm dari Kalman
  double measuredDistance; // meter
  DateTime lastSeen;
  int batteryLevel;

  SurveyNode({
    required this.id,
    required this.deviceName,
    required this.role,
    required this.localPosition,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.altitudeMsl = 0.0,
    this.baroPressure = 1013.25,
    this.rawRssi = -70.0,
    this.filteredRssi = -70.0,
    this.measuredDistance = 5.0,
    DateTime? lastSeen,
    this.batteryLevel = 100,
  }) : lastSeen = lastSeen ?? DateTime.now();

  bool get isOnline => DateTime.now().difference(lastSeen).inSeconds < 5;

  AnchorObservation toObservation() {
    return AnchorObservation(
      id: id,
      name: deviceName,
      position: localPosition,
      distance: measuredDistance,
      weight: _calculateWeight(),
    );
  }

  double _calculateWeight() {
    // Beri bobot lebih tinggi pada node dengan RSSI stabil dan sinyal kuat
    if (filteredRssi > -60) return 1.5;
    if (filteredRssi > -75) return 1.0;
    if (filteredRssi > -85) return 0.7;
    return 0.4;
  }
}

