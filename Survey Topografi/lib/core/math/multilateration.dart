import 'dart:math';

/// Representasi koordinat 3D lokal (Easting X, Northing Y, Elevation Z) dalam meter.
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  double distanceTo(Vector3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  double horizontalDistanceTo(Vector3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator *(double scale) => Vector3D(x * scale, y * scale, z * scale);

  @override
  String toString() => 'Vector3D(X: ${x.toStringAsFixed(3)}, Y: ${y.toStringAsFixed(3)}, Z: ${z.toStringAsFixed(3)})';
}

/// Node acuan (Anchor / Base Station) dengan posisi diketahui dan jarak terukur ke Rover.
class AnchorObservation {
  final String id;
  final String name;
  final Vector3D position;
  final double distance; // Jarak terukur (misal dari BLE RSSI atau rangefinder) dalam meter
  final double weight;   // Bobot (berdasarkan SNR / stabilitas RSSI), default 1.0

  const AnchorObservation({
    required this.id,
    required this.name,
    required this.position,
    required this.distance,
    this.weight = 1.0,
  });
}

/// Hasil kalkulasi multilaterasi dengan metrik kualitas geodetik.
class MultilaterationResult {
  final Vector3D estimatedPosition;
  final double rmse;         // Root Mean Square Error (residu kuadrat terkecil dalam meter)
  final double gdop;         // Geometric Dilution of Precision
  final int iterations;      // Iterasi konvergensi Gauss-Newton
  final bool isConverged;
  final String statusMessage;

  const MultilaterationResult({
    required this.estimatedPosition,
    required this.rmse,
    required this.gdop,
    required this.iterations,
    required this.isConverged,
    required this.statusMessage,
  });

  /// Tingkat akurasi estimasi geodetik
  String get accuracyGrade {
    if (rmse < 0.3 && gdop < 2.5) return 'Sub-Desimeter (Survey Grade)';
    if (rmse < 1.0 && gdop < 4.0) return 'Tinggi (Engineering Grade)';
    if (rmse < 2.5) return 'Sedang (Topographic Rough)';
    return 'Rendah (Verifikasi Geometri Anchor)';
  }
}

/// Solver Multilaterasi Menggunakan Kombinasi Linear Least Squares (Inisialisasi)
/// dan Non-Linear Gauss-Newton Optimization (Presisi Sub-Meter).
class MultilaterationSolver {
  /// Memecahkan posisi 3D Rover berdasarkan >= 3 titik anchor.
  /// [anchors]: minimal 3 titik acuan dengan jarak terukur.
  /// [initialZGuess]: estimasi Z awal dari altimeter/barometer diferensial jika tersedia.
  static MultilaterationResult solve({
    required List<AnchorObservation> anchors,
    double? initialZGuess,
    int maxIterations = 30,
    double convergenceThreshold = 0.001, // 1 mm
  }) {
    if (anchors.length < 3) {
      return MultilaterationResult(
        estimatedPosition: const Vector3D(0, 0, 0),
        rmse: 999.0,
        gdop: 99.0,
        iterations: 0,
        isConverged: false,
        statusMessage: 'Dibutuhkan minimal 3 Handphone Anchor aktif (saat ini: ${anchors.length})',
      );
    }

    // 1. Inisialisasi posisi awal menggunakan Linear Least Squares
    Vector3D currentEstimate = _linearLeastSquaresInit(anchors, initialZGuess);

    // 2. Iterasi Gauss-Newton Non-Linear Least Squares
    int iter = 0;
    bool converged = false;

    for (iter = 0; iter < maxIterations; iter++) {
      // Hitung vektor Jacobian (J) dan residual (r)
      // r_i = distance_measured_i - distance_computed_i
      List<List<double>> J = [];
      List<double> residuals = [];

      for (var anchor in anchors) {
        double compDist = currentEstimate.distanceTo(anchor.position);
        if (compDist < 0.0001) compDist = 0.0001; // Cegah pembagian dengan nol

        double residual = anchor.distance - compDist;
        residuals.add(residual * anchor.weight);

        // Turunan parsial: dr_i/dx = -(x - x_i)/d_i
        double dx = (currentEstimate.x - anchor.position.x) / compDist;
        double dy = (currentEstimate.y - anchor.position.y) / compDist;
        double dz = (currentEstimate.z - anchor.position.z) / compDist;

        J.add([dx * anchor.weight, dy * anchor.weight, dz * anchor.weight]);
      }

      // Hitung J^T * J (Matrix 3x3) dan J^T * residual (Vector 3)
      List<List<double>> JtJ = List.generate(3, (_) => List.filled(3, 0.0));
      List<double> JtR = List.filled(3, 0.0);

      for (int i = 0; i < anchors.length; i++) {
        for (int r = 0; r < 3; r++) {
          JtR[r] += J[i][r] * residuals[i];
          for (int c = 0; c < 3; c++) {
            JtJ[r][c] += J[i][r] * J[i][c];
          }
        }
      }

      // Tambahkan Levenberg-Marquardt damping sederhana untuk stabilitas Z jika anchor berada pada bidang datar (coplanar)
      double damping = 0.01;
      for (int d = 0; d < 3; d++) {
        JtJ[d][d] += damping;
      }

      // Invers matriks 3x3
      final invJtJ = _invert3x3(JtJ);
      if (invJtJ == null) {
        // Matriks singular (konstelasi anchor degenerat / collinear)
        break;
      }

      // delta = (J^T J)^-1 * (J^T R)
      double deltaX = invJtJ[0][0] * JtR[0] + invJtJ[0][1] * JtR[1] + invJtJ[0][2] * JtR[2];
      double deltaY = invJtJ[1][0] * JtR[0] + invJtJ[1][1] * JtR[1] + invJtJ[1][2] * JtR[2];
      double deltaZ = invJtJ[2][0] * JtR[0] + invJtJ[2][1] * JtR[1] + invJtJ[2][2] * JtR[2];

      // Batasi step delta per iterasi agar tidak divergen
      const double maxStep = 5.0; // Maksimum koreksi 5 meter per langkah
      deltaX = deltaX.clamp(-maxStep, maxStep);
      deltaY = deltaY.clamp(-maxStep, maxStep);
      deltaZ = deltaZ.clamp(-maxStep, maxStep);

      currentEstimate = Vector3D(
        currentEstimate.x + deltaX,
        currentEstimate.y + deltaY,
        currentEstimate.z + deltaZ,
      );

      double stepSize = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);
      if (stepSize < convergenceThreshold) {
        converged = true;
        break;
      }
    }

    // Jika barometer memberikan elevasi diferensial langsung, kita kunci Z atau beri bobot lebih
    if (initialZGuess != null && anchors.every((a) => (a.position.z - anchors.first.position.z).abs() < 0.5)) {
      // Handphone diletakkan pada elevasi permukaan yang hampir sama (coplanar horizontal),
      // maka Z multilaterasi geometris memiliki DOP tinggi; gunakan initialZGuess dari barometer diferensial!
      currentEstimate = Vector3D(currentEstimate.x, currentEstimate.y, initialZGuess);
    }

    // 3. Hitung Residu RMSE Akhir
    double sumSqResiduals = 0.0;
    for (var anchor in anchors) {
      double diff = currentEstimate.distanceTo(anchor.position) - anchor.distance;
      sumSqResiduals += diff * diff;
    }
    double rmse = sqrt(sumSqResiduals / anchors.length);

    // 4. Hitung GDOP (Geometric Dilution of Precision)
    double gdop = _calculateGDOP(anchors, currentEstimate);

    return MultilaterationResult(
      estimatedPosition: currentEstimate,
      rmse: rmse,
      gdop: gdop,
      iterations: iter,
      isConverged: converged,
      statusMessage: converged
          ? 'Konvergensi tercapai (${iter} iterasi, RMSE: ${rmse.toStringAsFixed(2)}m)'
          : 'Estimasi optimal tercapai (RMSE: ${rmse.toStringAsFixed(2)}m)',
    );
  }

  /// Inisialisasi cepat posisi dengan Linear Least Squares (Metode Anchor Subtraction)
  static Vector3D _linearLeastSquaresInit(List<AnchorObservation> anchors, double? initialZGuess) {
    final ref = anchors.first;
    final r1Sq = ref.distance * ref.distance;
    final x1 = ref.position.x;
    final y1 = ref.position.y;
    final z1 = ref.position.z;

    // Matriks A dan Vektor B untuk Ax = B dalam 2D/3D
    // 2*(xi - x1)*x + 2*(yi - y1)*y + 2*(zi - z1)*z = r1^2 - ri^2 + xi^2 - x1^2 + yi^2 - y1^2 + zi^2 - z1^2
    double sumX = 0, sumY = 0, sumZ = initialZGuess ?? 0;
    double weightSum = 0;

    for (int i = 1; i < anchors.length; i++) {
      final a = anchors[i];
      final riSq = a.distance * a.distance;
      final xi = a.position.x;
      final yi = a.position.y;

      final dx = xi - x1;
      final dy = yi - y1;
      final dSq = dx * dx + dy * dy;

      if (dSq > 0.01) {
        // Trilaterasi 2D baseline
        final double b = (r1Sq - riSq + dSq) / (2 * sqrt(dSq));
        final double ux = dx / sqrt(dSq);
        final double uy = dy / sqrt(dSq);
        sumX += x1 + ux * b;
        sumY += y1 + uy * b;
        weightSum += 1.0;
      }
    }

    if (weightSum > 0) {
      return Vector3D(sumX / weightSum, sumY / weightSum, sumZ);
    }

    // Fallback: Centroid berbobot invers jarak
    double wx = 0, wy = 0, wz = 0, totalW = 0;
    for (var a in anchors) {
      double w = 1.0 / max(0.5, a.distance);
      wx += a.position.x * w;
      wy += a.position.y * w;
      wz += a.position.z * w;
      totalW += w;
    }
    return Vector3D(wx / totalW, wy / totalW, initialZGuess ?? (wz / totalW));
  }

  /// Hitung GDOP (Geometric Dilution of Precision)
  static double _calculateGDOP(List<AnchorObservation> anchors, Vector3D roverPos) {
    if (anchors.length < 3) return 99.0;
    List<List<double>> G = [];

    for (var a in anchors) {
      double d = roverPos.distanceTo(a.position);
      if (d < 0.01) d = 0.01;
      G.add([
        (roverPos.x - a.position.x) / d,
        (roverPos.y - a.position.y) / d,
        (roverPos.z - a.position.z) / d,
        1.0 // Komponen offset waktu / drift
      ]);
    }

    // Normal matrix: G^T * G (4x4)
    List<List<double>> GtG = List.generate(4, (_) => List.filled(4, 0.0));
    for (int i = 0; i < anchors.length; i++) {
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          GtG[r][c] += G[i][r] * G[i][c];
        }
      }
    }

    // Trace aproksimasi
    double traceSum = 0.0;
    for (int i = 0; i < 3; i++) {
      if (GtG[i][i] > 0.001) {
        traceSum += 1.0 / GtG[i][i];
      } else {
        traceSum += 10.0;
      }
    }
    return sqrt(max(1.0, traceSum));
  }

  /// Inversi Matriks 3x3 Analitis
  static List<List<double>>? _invert3x3(List<List<double>> m) {
    double det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
                 m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
                 m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);

    if (det.abs() < 1e-9) return null; // Matriks Singular

    double invDet = 1.0 / det;
    return [
      [
        (m[1][1] * m[2][2] - m[1][2] * m[2][1]) * invDet,
        (m[0][2] * m[2][1] - m[0][1] * m[2][2]) * invDet,
        (m[0][1] * m[1][2] - m[0][2] * m[1][1]) * invDet,
      ],
      [
        (m[1][2] * m[2][0] - m[1][0] * m[2][2]) * invDet,
        (m[0][0] * m[2][2] - m[0][2] * m[2][0]) * invDet,
        (m[0][2] * m[1][0] - m[0][0] * m[1][2]) * invDet,
      ],
      [
        (m[1][0] * m[2][1] - m[1][1] * m[2][0]) * invDet,
        (m[0][1] * m[2][0] - m[0][0] * m[2][1]) * invDet,
        (m[0][0] * m[1][1] - m[0][1] * m[1][0]) * invDet,
      ]
    ];
  }
}

