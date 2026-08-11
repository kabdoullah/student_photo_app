// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CameraViewModel)
final cameraViewModelProvider = CameraViewModelProvider._();

final class CameraViewModelProvider
    extends $AsyncNotifierProvider<CameraViewModel, CameraController?> {
  CameraViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraViewModelHash();

  @$internal
  @override
  CameraViewModel create() => CameraViewModel();
}

String _$cameraViewModelHash() => r'3af0ca14326805fbe8a49649b87538b878a12dfa';

abstract class _$CameraViewModel extends $AsyncNotifier<CameraController?> {
  FutureOr<CameraController?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<CameraController?>, CameraController?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CameraController?>, CameraController?>,
              AsyncValue<CameraController?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
