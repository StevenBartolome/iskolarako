import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:iskoako/services/face_verification_service.dart';

void main() {
  group('FaceVerificationService - calculateActionProgress', () {
    test('Turn Left - correct left turn yields positive progress in mirrored camera', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        headEulerAngleY: 20.0, // Turning left in mirrored front camera
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.turnLeft,
        face: face,
        targetTurnDegrees: 32.0,
      );

      // (20.0 - 5.0) / (32.0 - 5.0) = 15 / 27 ~ 0.555
      expect(result.progress, closeTo(0.555, 0.01));
      expect(result.isCompleted, isFalse);
      expect(result.isWrongDirection, isFalse);
    });

    test('Turn Left - 100% completion when angle meets or exceeds target (e.g. +35 deg)', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        headEulerAngleY: 35.0,
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.turnLeft,
        face: face,
        targetTurnDegrees: 32.0,
      );

      expect(result.progress, equals(1.0));
      expect(result.isCompleted, isTrue);
      expect(result.isWrongDirection, isFalse);
    });

    test('Turn Left - wrong direction detected when user turns right (delta < -12 deg)', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        headEulerAngleY: -15.0, // Turning right instead of left
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.turnLeft,
        face: face,
        targetTurnDegrees: 32.0,
      );

      expect(result.progress, equals(0.0));
      expect(result.isCompleted, isFalse);
      expect(result.isWrongDirection, isTrue);
      expect(result.hint.contains('Wrong direction'), isTrue);
    });

    test('Turn Right - correct right turn yields positive progress in mirrored camera', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        headEulerAngleY: -20.0, // Turning right in mirrored front camera
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.turnRight,
        face: face,
        targetTurnDegrees: 32.0,
      );

      // (20.0 - 5.0) / (32.0 - 5.0) = 15 / 27 ~ 0.555
      expect(result.progress, closeTo(0.555, 0.01));
      expect(result.isCompleted, isFalse);
      expect(result.isWrongDirection, isFalse);
    });

    test('Turn Right - wrong direction detected when user turns left (delta > 12 deg)', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        headEulerAngleY: 15.0, // Turning left instead of right
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.turnRight,
        face: face,
        targetTurnDegrees: 32.0,
      );

      expect(result.progress, equals(0.0));
      expect(result.isCompleted, isFalse);
      expect(result.isWrongDirection, isTrue);
      expect(result.hint.contains('Wrong direction'), isTrue);
    });

    test('Blink - open eyes yield 0 progress', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        leftEyeOpenProbability: 0.95,
        rightEyeOpenProbability: 0.92,
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.blink,
        face: face,
        eyesOpenObserved: true,
      );

      expect(result.progress, equals(0.0));
      expect(result.isCompleted, isFalse);
    });

    test('Blink - closed eyes without eyesOpenObserved does NOT pass immediately', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        leftEyeOpenProbability: 0.10,
        rightEyeOpenProbability: 0.12,
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.blink,
        face: face,
        eyesOpenObserved: false, // Eyes were not observed open first
      );

      expect(result.isCompleted, isFalse);
    });

    test('Blink - closed eyes WITH eyesOpenObserved passes 100%', () {
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
        leftEyeOpenProbability: 0.10,
        rightEyeOpenProbability: 0.12,
      );

      final result = FaceVerificationService.calculateActionProgress(
        expectedAction: LivenessAction.blink,
        face: face,
        eyesOpenObserved: true,
      );

      expect(result.progress, equals(1.0));
      expect(result.isCompleted, isTrue);
    });
  });
}
