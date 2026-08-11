import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/face_detector_viewmodel.dart';

class CameraOverlay extends ConsumerWidget {
  const CameraOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(faceDetectorViewModelProvider);

    final (color, message) = switch (status) {
      FaceDetectionStatus.faceDetected => (Colors.green, 'Visage détecté'),
      FaceDetectionStatus.tooManyFaces => (
        Colors.orange,
        'Un seul visage requis',
      ),
      FaceDetectionStatus.noFace => (Colors.red, 'Aucun visage détecté'),
      FaceDetectionStatus.searching => (Colors.white70, 'Analyse...'),
      FaceDetectionStatus.error => (
        Colors.red,
        "Erreur lors de l'analyse du visage",
      ),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: IdPhotoGuidePainter(color: color)),
        ),
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dessine le repère (ovale de tête + coins de cadrage) mesuré sur la photo
/// de référence fournie par l'établissement. Partagé entre le viseur en
/// direct (`CameraOverlay`) et l'écran de validation (`_SuccessGuide`), pour
/// que les deux affichent exactement la même zone attendue.
class IdPhotoGuidePainter extends CustomPainter {
  final Color color;
  IdPhotoGuidePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Ovale mesuré directement sur la photo de référence fournie par
    // l'établissement (haut des cheveux à 6.9% du cadre, menton à 89.6%,
    // largeur max au niveau des oreilles à 51.7% de la largeur) — pas une
    // estimation à l'œil.
    final ovalWidth = size.width * 0.52;
    final ovalHeight = size.height * 0.83;
    final rect = Rect.fromLTWH(
      (size.width - ovalWidth) / 2,
      size.height * 0.07,
      ovalWidth,
      ovalHeight,
    );
    canvas.drawOval(rect, paint);

    // Repères ouverts aux quatre coins : sur la photo de référence, les
    // épaules atteignent 98.6% de la largeur vers 84.8% de la hauteur.
    final left = size.width * 0.05;
    final right = size.width * 0.95;
    final top = size.height * 0.03;
    final bottom = size.height * 0.95;
    final horizontal = size.width * 0.09;
    final vertical = size.height * 0.05;

    canvas.drawLine(Offset(left, top), Offset(left + horizontal, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + vertical), paint);
    canvas.drawLine(Offset(right - horizontal, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + vertical), paint);
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + horizontal, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(left, bottom - vertical),
      Offset(left, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right - horizontal, bottom),
      Offset(right, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom - vertical),
      Offset(right, bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant IdPhotoGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}
