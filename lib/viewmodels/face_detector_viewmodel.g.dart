// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'face_detector_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FaceDetectorViewModel)
final faceDetectorViewModelProvider = FaceDetectorViewModelProvider._();

final class FaceDetectorViewModelProvider
    extends $NotifierProvider<FaceDetectorViewModel, FaceDetectionStatus> {
  FaceDetectorViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'faceDetectorViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$faceDetectorViewModelHash();

  @$internal
  @override
  FaceDetectorViewModel create() => FaceDetectorViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FaceDetectionStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FaceDetectionStatus>(value),
    );
  }
}

String _$faceDetectorViewModelHash() =>
    r'960ec851e1a01fd6c6cf932de164e24ac2a1b03f';

abstract class _$FaceDetectorViewModel extends $Notifier<FaceDetectionStatus> {
  FaceDetectionStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FaceDetectionStatus, FaceDetectionStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FaceDetectionStatus, FaceDetectionStatus>,
              FaceDetectionStatus,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
