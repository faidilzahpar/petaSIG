import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:topo_survey_mesh/core/math/multilateration.dart';

void main() {
  group('Multilateration Solver & Geodesy Tests', () {
    test('Recovers exact rover 3D position from 3 ideal anchors', () {
      // Setup Anchor A (Base), Anchor B, Anchor C
      final anchorA = Vector3D(0.0, 0.0, 100.0);
      final anchorB = Vector3D(20.0, 0.0, 100.2);
      final anchorC = Vector3D(10.0, 17.32, 101.5);

      // True Rover Position
      final trueRover = Vector3D(8.5, 6.2, 100.8);

      final obsA = AnchorObservation(
        id: 'A',
        name: 'Anchor A',
        position: anchorA,
        distance: trueRover.distanceTo(anchorA),
      );
      final obsB = AnchorObservation(
        id: 'B',
        name: 'Anchor B',
        position: anchorB,
        distance: trueRover.distanceTo(anchorB),
      );
      final obsC = AnchorObservation(
        id: 'C',
        name: 'Anchor C',
        position: anchorC,
        distance: trueRover.distanceTo(anchorC),
      );

      final result = MultilaterationSolver.solve(
        anchors: [obsA, obsB, obsC],
        initialZGuess: 100.8,
      );

      expect(result.isConverged, isTrue);
      expect((result.estimatedPosition.x - trueRover.x).abs(), lessThan(0.1));
      expect((result.estimatedPosition.y - trueRover.y).abs(), lessThan(0.1));
      expect((result.estimatedPosition.z - trueRover.z).abs(), lessThan(0.2));
      expect(result.rmse, lessThan(0.05));
    });

    test('Recovers rover position with noise in ranges (Sub-meter accuracy)', () {
      final anchorA = Vector3D(0.0, 0.0, 100.0);
      final anchorB = Vector3D(25.0, 0.0, 100.0);
      final anchorC = Vector3D(12.5, 21.65, 100.0);
      final anchorD = Vector3D(12.5, 7.2, 100.0);

      final trueRover = Vector3D(10.0, 8.0, 100.0);

      // Add simulated +/- 0.3m radio noise to measured distances
      final anchors = [
        AnchorObservation(id: 'A', name: 'A', position: anchorA, distance: trueRover.distanceTo(anchorA) + 0.15),
        AnchorObservation(id: 'B', name: 'B', position: anchorB, distance: trueRover.distanceTo(anchorB) - 0.20),
        AnchorObservation(id: 'C', name: 'C', position: anchorC, distance: trueRover.distanceTo(anchorC) + 0.10),
        AnchorObservation(id: 'D', name: 'D', position: anchorD, distance: trueRover.distanceTo(anchorD) - 0.12),
      ];

      final result = MultilaterationSolver.solve(anchors: anchors, initialZGuess: 100.0);

      // Even with noisy distances, error should be well under 1 meter (sub-meter)
      double horizontalError = sqrt(
        pow(result.estimatedPosition.x - trueRover.x, 2) +
        pow(result.estimatedPosition.y - trueRover.y, 2)
      );

      expect(horizontalError, lessThan(0.8));
      expect(result.gdop, lessThan(3.5));
    });
  });
}

