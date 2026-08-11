// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_quality_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Analyse la photo réellement capturée (déjà recadrée au format identité
/// par `CameraViewModel`) pour vérifier que le cadrage et la luminosité sont
/// exploitables, plutôt que d'afficher une checklist toujours positive.

@ProviderFor(PhotoQualityViewModel)
final photoQualityViewModelProvider = PhotoQualityViewModelProvider._();

/// Analyse la photo réellement capturée (déjà recadrée au format identité
/// par `CameraViewModel`) pour vérifier que le cadrage et la luminosité sont
/// exploitables, plutôt que d'afficher une checklist toujours positive.
final class PhotoQualityViewModelProvider
    extends $AsyncNotifierProvider<PhotoQualityViewModel, PhotoQualityResult?> {
  /// Analyse la photo réellement capturée (déjà recadrée au format identité
  /// par `CameraViewModel`) pour vérifier que le cadrage et la luminosité sont
  /// exploitables, plutôt que d'afficher une checklist toujours positive.
  PhotoQualityViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoQualityViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoQualityViewModelHash();

  @$internal
  @override
  PhotoQualityViewModel create() => PhotoQualityViewModel();
}

String _$photoQualityViewModelHash() =>
    r'3aab6644e8d846e720d113a7baf54d1c296ea5f2';

/// Analyse la photo réellement capturée (déjà recadrée au format identité
/// par `CameraViewModel`) pour vérifier que le cadrage et la luminosité sont
/// exploitables, plutôt que d'afficher une checklist toujours positive.

abstract class _$PhotoQualityViewModel
    extends $AsyncNotifier<PhotoQualityResult?> {
  FutureOr<PhotoQualityResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PhotoQualityResult?>, PhotoQualityResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PhotoQualityResult?>, PhotoQualityResult?>,
              AsyncValue<PhotoQualityResult?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
