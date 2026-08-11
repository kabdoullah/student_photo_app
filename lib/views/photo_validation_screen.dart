import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student.dart';
import '../viewmodels/camera_viewmodel.dart' show idPhotoAspectRatio;
import '../viewmodels/photo_capture_viewmodel.dart';
import '../viewmodels/photo_quality_viewmodel.dart';
import 'widgets/camera_overlay.dart' show IdPhotoGuidePainter;

class PhotoValidationScreen extends ConsumerStatefulWidget {
  const PhotoValidationScreen({
    super.key,
    required this.photoFile,
    required this.student,
  });

  final File photoFile;
  final Student student;

  @override
  ConsumerState<PhotoValidationScreen> createState() =>
      _PhotoValidationScreenState();
}

class _PhotoValidationScreenState extends ConsumerState<PhotoValidationScreen> {
  static const _primary = Color(0xFF002B48);
  static const _primaryContainer = Color(0xFF1E415F);
  static const _background = Color(0xFFF6F9FF);
  static const _outline = Color(0xFFC3C7CE);
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(photoQualityViewModelProvider.notifier)
          .analyze(widget.photoFile),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final success = await ref
        .read(photoCaptureViewModelProvider.notifier)
        .uploadPhoto(widget.photoFile);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("L'enregistrement a échoué. Réessayez."),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qualityState = ref.watch(photoQualityViewModelProvider);
    final quality = qualityState.value;
    final qualityBlocksSave = quality != null && !quality.isAcceptable;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back),
        ),
        centerTitle: true,
        title: const Text(
          'Vérification',
          style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _outline, height: 1),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(child: _stepPill()),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _outline),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: idPhotoAspectRatio,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      widget.photoFile,
                                      fit: BoxFit.cover,
                                    ),
                                    const _SuccessGuide(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                _framingChecklistItem(qualityState),
                                _brightnessChecklistItem(qualityState),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Column(
                      children: [
                        if (qualityBlocksSave) ...[
                          _qualityWarning(quality),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed:
                                (_isSaving ||
                                    qualityState.isLoading ||
                                    qualityBlocksSave)
                                ? null
                                : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primaryContainer,
                              shape: const StadiumBorder(),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(
                              _isSaving
                                  ? 'Enregistrement…'
                                  : 'Valider et enregistrer',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: const BorderSide(color: _primary),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.replay),
                            label: const Text('Reprendre la photo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qualityWarning(PhotoQualityResult quality) {
    final reasons = [
      if (quality.framing != FramingQuality.good)
        _framingLabel(quality.framing),
      if (quality.brightness != BrightnessQuality.good)
        _brightnessLabel(quality.brightness),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        border: Border.all(color: const Color(0xFFF2B8B5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${reasons.join(' · ')}. Reprenez la photo.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _framingChecklistItem(AsyncValue<PhotoQualityResult?> state) {
    if (state.isLoading) {
      return const _ChecklistItem(
        icon: Icons.hourglass_top,
        title: 'Cadrage',
        subtitle: 'Analyse en cours…',
        status: _ChecklistStatus.pending,
      );
    }
    final framing = state.value?.framing;
    if (framing == null) {
      return const _ChecklistItem(
        icon: Icons.help_outline,
        title: 'Cadrage',
        subtitle: 'Non vérifié',
        status: _ChecklistStatus.pending,
      );
    }
    return _ChecklistItem(
      icon: framing == FramingQuality.good
          ? Icons.check_circle
          : Icons.error_outline,
      title: 'Cadrage',
      subtitle: _framingLabel(framing),
      status: framing == FramingQuality.good
          ? _ChecklistStatus.good
          : _ChecklistStatus.bad,
    );
  }

  Widget _brightnessChecklistItem(AsyncValue<PhotoQualityResult?> state) {
    if (state.isLoading) {
      return const _ChecklistItem(
        icon: Icons.hourglass_top,
        title: 'Luminosité',
        subtitle: 'Analyse en cours…',
        status: _ChecklistStatus.pending,
      );
    }
    final brightness = state.value?.brightness;
    if (brightness == null) {
      return const _ChecklistItem(
        icon: Icons.help_outline,
        title: 'Luminosité',
        subtitle: 'Non vérifié',
        status: _ChecklistStatus.pending,
      );
    }
    return _ChecklistItem(
      icon: brightness == BrightnessQuality.good
          ? Icons.check_circle
          : Icons.error_outline,
      title: 'Luminosité',
      subtitle: _brightnessLabel(brightness),
      status: brightness == BrightnessQuality.good
          ? _ChecklistStatus.good
          : _ChecklistStatus.bad,
    );
  }

  String _framingLabel(FramingQuality framing) => switch (framing) {
    FramingQuality.good => 'Visage centré',
    FramingQuality.noFace => 'Aucun visage détecté',
    FramingQuality.tooManyFaces => 'Plusieurs visages détectés',
    FramingQuality.tooFar => 'Trop loin — rapprochez-vous',
    FramingQuality.tooClose => 'Trop près — reculez-vous',
    FramingQuality.offCenterHorizontal => 'Visage décentré horizontalement',
    FramingQuality.tooHigh => 'Visage trop haut — cadrez plus bas',
    FramingQuality.tooLow => 'Visage trop bas — cadrez plus haut',
  };

  String _brightnessLabel(BrightnessQuality brightness) => switch (brightness) {
    BrightnessQuality.good => 'Éclairage uniforme',
    BrightnessQuality.tooDark => 'Trop sombre',
    BrightnessQuality.tooBright => 'Trop de lumière',
  };

  Widget _stepPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF4FD),
      border: Border.all(color: _outline),
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Text(
      'ÉTAPE 2 / 2 : Validation',
      style: TextStyle(
        color: _primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

enum _ChecklistStatus { pending, good, bad }

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final _ChecklistStatus status;

  @override
  Widget build(BuildContext context) {
    final (iconBackground, iconColor) = switch (status) {
      _ChecklistStatus.good => (
        const Color(0xFFE8F5E9),
        const Color(0xFF237A3B),
      ),
      _ChecklistStatus.bad => (const Color(0xFFFDECEA), Colors.red.shade700),
      _ChecklistStatus.pending => (
        const Color(0xFFE8EEF7),
        const Color(0xFF42474D),
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FD),
        border: Border.all(color: const Color(0x80C3C7CE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF42474D),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rejoue le même repère que le viseur en direct (`CameraOverlay`), pour que
/// la zone attendue affichée ici corresponde exactement à celle vue pendant
/// la prise de vue — et donc à la vraie zone recadrée dans le fichier envoyé.
class _SuccessGuide extends StatelessWidget {
  const _SuccessGuide();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: IdPhotoGuidePainter(color: const Color(0x661E415F)),
      size: Size.infinite,
    ),
  );
}
