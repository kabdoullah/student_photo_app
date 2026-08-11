import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'face_detector_viewmodel.g.dart';

enum FaceDetectionStatus {
  noFace,
  faceDetected,
  tooManyFaces,
  searching,
  error,
}

@Riverpod(keepAlive: true)
class FaceDetectorViewModel extends _$FaceDetectorViewModel {
  late final FaceDetector _faceDetector;
  bool _isProcessing = false;

  @override
  FaceDetectionStatus build() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );

    ref.onDispose(() => _faceDetector.close());
    return FaceDetectionStatus.noFace;
  }

  Future<void> processCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image, camera);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        state = FaceDetectionStatus.noFace;
      } else if (faces.length > 1) {
        state = FaceDetectionStatus.tooManyFaces;
      } else {
        state = FaceDetectionStatus.faceDetected;
      }
    } catch (_) {
      state = FaceDetectionStatus.error;
    } finally {
      _isProcessing = false;
    }
  }

  InputImage _convertCameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: ui.Size(image.width.toDouble(), image.height.toDouble()),
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }
}
