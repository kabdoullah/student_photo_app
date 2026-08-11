import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student.dart';
import '../viewmodels/auth_viewmodel.dart' show authTokenProvider;
import '../viewmodels/camera_viewmodel.dart'
    show cameraViewModelProvider, idPhotoAspectRatio;
import '../viewmodels/face_detector_viewmodel.dart';
import '../viewmodels/photo_capture_viewmodel.dart';
import 'photo_validation_screen.dart';
import 'widgets/camera_overlay.dart';

class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  static const _primary = Color(0xFF002B48);
  static const _background = Color(0xFFF6F9FF);
  static const _outline = Color(0xFFC3C7CE);
  static const _onSurfaceVariant = Color(0xFF42474D);

  final _formKey = GlobalKey<FormState>();
  final _matriculeController = TextEditingController();
  final _matriculeFocusNode = FocusNode();
  Student? _student;
  bool _isGuidedMode = true;

  @override
  void dispose() {
    _matriculeController.dispose();
    _matriculeFocusNode.dispose();
    super.dispose();
  }

  void _onCameraImage(CameraImage image) {
    final controller = ref.read(cameraViewModelProvider).value;
    if (controller == null) return;
    ref
        .read(faceDetectorViewModelProvider.notifier)
        .processCameraImage(image, controller.description);
  }

  Future<void> _confirmIdentity() async {
    if (!_formKey.currentState!.validate()) return;
    final matricule = _matriculeController.text.trim();

    Student? selectedStudent;
    await ref
        .read(photoCaptureViewModelProvider.notifier)
        .searchStudent(matricule);
    selectedStudent = ref.read(photoCaptureViewModelProvider).value;
    if (selectedStudent == null) {
      if (mounted) {
        _showMessage(
          'Élève introuvable. Vérifiez le matricule.',
          isError: true,
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _student = selectedStudent);
    await ref.read(cameraViewModelProvider.notifier).initialize(_onCameraImage);
  }

  Future<void> _takePhoto() async {
    final cameraNotifier = ref.read(cameraViewModelProvider.notifier);
    final controller = ref.read(cameraViewModelProvider).value;
    if (controller == null ||
        !controller.value.isInitialized ||
        _student == null) {
      return;
    }

    final isFaceValid =
        ref.read(faceDetectorViewModelProvider) ==
        FaceDetectionStatus.faceDetected;
    if (_isGuidedMode && !isFaceValid) {
      _showMessage(
        'Placez un seul visage dans le repère avant de capturer.',
        isError: true,
      );
      return;
    }

    final photo = await cameraNotifier.takePicture();
    if (!mounted) return;
    if (photo == null) {
      _showMessage("La photo n'a pas pu être capturée.", isError: true);
      await cameraNotifier.resumeStream(_onCameraImage);
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhotoValidationScreen(
          photoFile: File(photo.path),
          student: _student!,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      _showMessage('Photo enregistrée avec succès.');
      await cameraNotifier.resumeStream(_onCameraImage);
      if (!mounted) return;
      _matriculeController.clear();
      setState(() => _student = null);
      _matriculeFocusNode.requestFocus();
    } else {
      await cameraNotifier.resumeStream(_onCameraImage);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez ressaisir vos identifiants pour continuer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authTokenProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final studentState = ref.watch(photoCaptureViewModelProvider);
    final faceStatus = ref.watch(faceDetectorViewModelProvider);
    final isFaceValid = faceStatus == FaceDetectionStatus.faceDetected;
    final cameraState = ref.watch(cameraViewModelProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: const SizedBox(width: 48),
        title: const Column(
          children: [
            Text(
              "Photo d'identité élève",
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Collège Privé La Vallée du Centre',
              style: TextStyle(
                color: _onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        toolbarHeight: 82,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: _primary),
            tooltip: 'Se déconnecter',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _outline),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              children: [
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ÉTAPE 1 — ÉLÈVE',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _matriculeController,
                          focusNode: _matriculeFocusNode,
                          textInputAction: TextInputAction.done,
                          onTapUpOutside: (_) =>
                              FocusScope.of(context).unfocus(),
                          onChanged: (_) {
                            if (_student != null) {
                              setState(() => _student = null);
                            }
                          },
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                            if (!studentState.isLoading && _student == null) {
                              _confirmIdentity();
                            }
                          },
                          decoration:
                              _inputDecoration(
                                'Matricule',
                                hint: 'ex : 21676696F',
                              ).copyWith(
                                suffixIcon: _student != null
                                    ? const Padding(
                                        padding: EdgeInsets.only(right: 12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: _primary,
                                              size: 18,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              'Vérifié',
                                              style: TextStyle(
                                                color: _primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Le matricule est requis.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_student != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: _onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _student!.fullName,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed:
                              (studentState.isLoading || _student != null)
                              ? null
                              : _confirmIdentity,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: studentState.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                          label: Text(
                            _student == null
                                ? 'Vérifier et continuer'
                                : 'Identité confirmée — Continuer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _sectionCard(child: _photoStep(isFaceValid, cameraState)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoStep(
    bool isFaceValid,
    AsyncValue<CameraController?> cameraState,
  ) {
    final canCapture =
        _student != null &&
        cameraState.value != null &&
        (!_isGuidedMode || isFaceValid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ÉTAPE 2 — PHOTO',
          style: TextStyle(
            color: _primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 20),
        _modeSelector(),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: idPhotoAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFDCE3EC),
                border: Border.all(color: _outline),
              ),
              child: _cameraContent(cameraState),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: _shutterButton(canCapture)),
      ],
    );
  }

  Widget _shutterButton(bool enabled) {
    final color = enabled ? _primary : const Color(0xFF9DA8B5);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Prendre la photo',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? _takePhoto : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 94,
            height: 94,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 4),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraContent(AsyncValue<CameraController?> cameraState) {
    if (_student == null) {
      return const _CameraPlaceholder(
        icon: Icons.badge_outlined,
        message: "Confirmez l'identité de l'élève pour activer la caméra.",
      );
    }
    if (cameraState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (cameraState.hasError) {
      return const _CameraPlaceholder(
        icon: Icons.videocam_off_outlined,
        message: "La caméra n'a pas pu être démarrée.",
      );
    }
    final controller = cameraState.value;
    if (controller == null) {
      return const _CameraPlaceholder(
        icon: Icons.videocam_outlined,
        message: 'Initialisation de la caméra…',
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        if (_isGuidedMode) const CameraOverlay(),
      ],
    );
  }

  Widget _modeSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EEF7),
      border: Border.all(color: _outline),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: _modeButton(true, Icons.square_foot_outlined, 'Viseur guidé'),
        ),
        Expanded(
          child: _modeButton(
            false,
            Icons.photo_camera_outlined,
            'Caméra native',
          ),
        ),
      ],
    ),
  );

  Widget _modeButton(bool guided, IconData icon, String label) {
    final selected = _isGuidedMode == guided;
    return TextButton.icon(
      onPressed: () => setState(() => _isGuidedMode = guided),
      style: TextButton.styleFrom(
        foregroundColor: selected ? _primary : _onSurfaceVariant,
        backgroundColor: selected ? Colors.white : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _outline),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );

  InputDecoration _inputDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      );
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: const Color(0xFF42474D)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF42474D)),
          ),
        ],
      ),
    ),
  );
}
