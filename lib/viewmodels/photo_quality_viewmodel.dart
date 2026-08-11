import 'dart:async';
import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_quality_viewmodel.g.dart';

enum FramingQuality {
  good,
  noFace,
  tooManyFaces,
  tooFar,
  tooClose,
  offCenterHorizontal,
  tooHigh,
  tooLow,
}

enum BrightnessQuality { good, tooDark, tooBright }

class PhotoQualityResult {
  const PhotoQualityResult({required this.framing, required this.brightness});

  final FramingQuality framing;
  final BrightnessQuality brightness;

  bool get isAcceptable =>
      framing == FramingQuality.good && brightness == BrightnessQuality.good;
}

/// Analyse la photo réellement capturée (déjà recadrée au format identité
/// par `CameraViewModel`) pour vérifier que le cadrage et la luminosité sont
/// exploitables, plutôt que d'afficher une checklist toujours positive.
@riverpod
class PhotoQualityViewModel extends _$PhotoQualityViewModel {
  @override
  FutureOr<PhotoQualityResult?> build() => null;

  Future<void> analyze(File photoFile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _analyze(photoFile));
  }

  Future<PhotoQualityResult> _analyze(File photoFile) async {
    final bytes = await photoFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    final brightness = decoded == null
        ? BrightnessQuality.good
        : _brightnessOf(decoded);

    final detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
    );
    try {
      final faces = await detector.processImage(
        InputImage.fromFilePath(photoFile.path),
      );
      final framing = _framingOf(faces, decoded);
      return PhotoQualityResult(framing: framing, brightness: brightness);
    } finally {
      await detector.close();
    }
  }

  FramingQuality _framingOf(List<Face> faces, img.Image? image) {
    if (faces.isEmpty) return FramingQuality.noFace;
    if (faces.length > 1) return FramingQuality.tooManyFaces;
    if (image == null) return FramingQuality.good;

    final box = faces.first.boundingBox;
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    final heightRatio = box.height / imageHeight;
    final centerX = (box.left + box.right) / 2;
    final centerY = (box.top + box.bottom) / 2;
    final horizontalOffset = (centerX - imageWidth / 2).abs() / imageWidth;
    // Sur la photo de référence, la tête (cheveux à menton) occupe 6.9% à
    // 89.6% de la hauteur, donc son centre se situe vers 48% du cadre —
    // le visage détecté par ML Kit (plus étroit que cheveux+menton) doit
    // rester proche de ce même centre vertical.
    const expectedCenterY = 0.48;
    final verticalOffset = (centerY / imageHeight) - expectedCenterY;

    if (horizontalOffset > 0.12) return FramingQuality.offCenterHorizontal;
    if (verticalOffset < -0.15) return FramingQuality.tooHigh;
    if (verticalOffset > 0.15) return FramingQuality.tooLow;
    if (heightRatio < 0.28) return FramingQuality.tooFar;
    if (heightRatio > 0.62) return FramingQuality.tooClose;
    return FramingQuality.good;
  }

  BrightnessQuality _brightnessOf(img.Image image) {
    // Échantillonnage pour rester rapide même sur une image haute résolution.
    const sampleStep = 7;
    var total = 0.0;
    var count = 0;
    for (var y = 0; y < image.height; y += sampleStep) {
      for (var x = 0; x < image.width; x += sampleStep) {
        total += image.getPixel(x, y).luminance;
        count++;
      }
    }
    final average = count == 0 ? 128.0 : total / count;
    if (average < 70) return BrightnessQuality.tooDark;
    if (average > 200) return BrightnessQuality.tooBright;
    return BrightnessQuality.good;
  }
}
