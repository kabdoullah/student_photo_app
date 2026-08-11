import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_viewmodel.g.dart';

/// Ratio largeur/hauteur cible pour une photo d'identité, aligné sur le
/// format standard 35×45 mm plutôt que sur la photo de référence
/// (424 × 480 px, ratio 0.883) : cette dernière rendait le cadre trop
/// étroit et obligeait à trop se rapprocher pour cadrer le sujet. Utilisé
/// à la fois pour le cadre de prévisualisation (voir les écrans de capture
/// et de validation) et pour le recadrage final ci-dessous : les deux
/// doivent rester identiques pour que ce que l'agent voit à l'écran
/// corresponde exactement au fichier envoyé.
const idPhotoAspectRatio = 35 / 45;

/// Largeur finale en pixels : suffisante pour une carte/badge imprimé,
/// sans gonfler inutilement la taille du fichier uploadé.
const _idPhotoTargetWidth = 900;

@riverpod
class CameraViewModel extends _$CameraViewModel {
  @override
  FutureOr<CameraController?> build() {
    ref.onDispose(() {
      final controller = state.value;
      if (controller == null) return;
      if (controller.value.isStreamingImages) controller.stopImageStream();
      controller.dispose();
    });
    return null;
  }

  Future<void> initialize(void Function(CameraImage image) onImage) async {
    if (state.isLoading || state.value != null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no-camera', 'Aucune caméra disponible.');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit attend un buffer NV21 unique sur Android. Le format CameraX
        // par défaut est YUV_420_888 en trois plans, ce qui provoque l'erreur
        // native "Getting Image failed" lors de la conversion.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.startImageStream(onImage);
      return controller;
    });
  }

  Future<void> resumeStream(void Function(CameraImage image) onImage) async {
    final controller = state.value;
    if (controller == null || controller.value.isStreamingImages) return;
    await controller.startImageStream(onImage);
  }

  Future<XFile?> takePicture() async {
    final controller = state.value;
    if (controller == null || !controller.value.isInitialized) return null;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      return await _cropToIdPhotoFormat(photo);
    } on CameraException {
      return null;
    }
  }

  /// Recadre la photo au centre au ratio d'une photo d'identité et la
  /// redimensionne à une résolution fixe, pour que chaque envoi respecte le
  /// même format quel que soit le capteur/la résolution de l'appareil.
  Future<XFile> _cropToIdPhotoFormat(XFile photo) async {
    final bytes = await File(photo.path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return photo;

    final oriented = img.bakeOrientation(decoded);

    final currentRatio = oriented.width / oriented.height;
    img.Image cropped;
    if (currentRatio > idPhotoAspectRatio) {
      final width = (oriented.height * idPhotoAspectRatio).round();
      final x = ((oriented.width - width) / 2).round();
      cropped = img.copyCrop(
        oriented,
        x: x,
        y: 0,
        width: width,
        height: oriented.height,
      );
    } else {
      final height = (oriented.width / idPhotoAspectRatio).round();
      final y = ((oriented.height - height) / 2).round();
      cropped = img.copyCrop(
        oriented,
        x: 0,
        y: y,
        width: oriented.width,
        height: height,
      );
    }

    final resized = img.copyResize(cropped, width: _idPhotoTargetWidth);
    final encoded = img.encodeJpg(resized, quality: 92);
    await File(photo.path).writeAsBytes(encoded, flush: true);
    return photo;
  }
}
