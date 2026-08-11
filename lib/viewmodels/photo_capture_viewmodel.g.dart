// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_capture_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PhotoCaptureViewModel)
final photoCaptureViewModelProvider = PhotoCaptureViewModelProvider._();

final class PhotoCaptureViewModelProvider
    extends $AsyncNotifierProvider<PhotoCaptureViewModel, Student?> {
  PhotoCaptureViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoCaptureViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoCaptureViewModelHash();

  @$internal
  @override
  PhotoCaptureViewModel create() => PhotoCaptureViewModel();
}

String _$photoCaptureViewModelHash() =>
    r'f1023d57d5c5f8f0d520679e5857ef20fedac209';

abstract class _$PhotoCaptureViewModel extends $AsyncNotifier<Student?> {
  FutureOr<Student?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Student?>, Student?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Student?>, Student?>,
              AsyncValue<Student?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
