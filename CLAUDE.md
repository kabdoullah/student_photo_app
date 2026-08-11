# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Flutter app used by a school ("Collège Privé La Vallée du Centre") staff member to look up a student by matricule (registration number), capture an ID-style photo with guided face detection, and upload it to a backend API. French-language UI throughout.

## Commands

```bash
flutter pub get                        # install dependencies
flutter run                            # run on a connected device/emulator
flutter analyze                        # static analysis (flutter_lints)
flutter test                           # run all tests
flutter test test/widget_test.dart     # run a single test file
dart run build_runner build --delete-conflicting-outputs   # regenerate *.freezed.dart / *.g.dart after editing models
dart run build_runner watch --delete-conflicting-outputs   # regenerate on save during model iteration
```

There is no CI config in this repo; `flutter analyze` and `flutter test` are the checks to run before considering a change done.

### Pinned dependency versions — do not casually `pub upgrade`

`freezed`/`json_serializable` (which need an older `analyzer`) and `riverpod_generator` (which needs a specific `analyzer` too) only overlap in a narrow, non-latest version band. `pubspec.yaml` pins exact versions for this reason: `flutter_riverpod: 3.2.1`, `riverpod_annotation: 4.0.2`, `riverpod_generator: 4.0.3`, `json_serializable: 6.13.0`, `json_annotation: 4.11.0`. `flutter pub outdated` will show all of these as behind latest — that's expected, not drift to fix. Bumping any one of them without re-checking the whole `analyzer` compatibility chain will break `build_runner`.

## Architecture

MVVM with Riverpod, using `@riverpod` codegen (`riverpod_generator`) for every viewmodel — no hand-written `NotifierProvider`/`AsyncNotifierProvider` declarations. Layers, in `lib/`:

- `models/` — Freezed/json_serializable data classes. `Student.fromApiJson` normalizes inconsistent backend field names (handles both English and French keys, e.g. `first_name`/`prenom`, `last_name`/`nom`) — this is the tolerant boundary against an API whose payload shape isn't fully fixed. After changing any `@freezed` model or any `@riverpod` viewmodel, regenerate with `build_runner` (see Commands).
- `repositories/` — thin Dio wrappers per resource (`AuthRepository`, `StudentRepository`). No business logic; just HTTP calls and response shaping.
- `viewmodels/` — `@riverpod` classes/functions holding UI state and orchestrating repository calls (`AuthTokenNotifier`, `PhotoCaptureViewModel`, `FaceDetectorViewModel`, `CameraViewModel`, `LoginViewModel`). Each `.dart` file has a matching generated `.g.dart` part (`part 'x_viewmodel.g.dart';`) — never edit `.g.dart` files by hand.
  - `@Riverpod(keepAlive: true)` is used on providers that must survive across screens for the app's lifetime (`AuthTokenNotifier`, `apiClient`, `authRepository`, `secureStorage`, `PhotoCaptureViewModel`, `FaceDetectorViewModel`). Providers scoped to a single screen's lifecycle use plain `@riverpod` (autoDispose by default): `CameraViewModel`, `LoginViewModel`.
  - Provider names are derived automatically from the annotated function/class name (lowerCamelCase + `Provider` suffix); classes ending in `Notifier` have that suffix stripped (e.g. `AuthTokenNotifier` → `authTokenProvider`). Don't rename a viewmodel class without checking what the generated provider name becomes.
- `views/` — screens (`ConsumerStatefulWidget`/`ConsumerWidget`) and `views/widgets/` for shared pieces like `CameraOverlay`.

### Auth flow

- `authTokenProvider` (`lib/viewmodels/auth_viewmodel.dart`) gates the whole app: `main.dart`'s `_AuthGate` shows `LoginScreen` or `PhotoCaptureScreen` based on `authTokenProvider`'s state.
- On startup the notifier restores a JWT from `flutter_secure_storage`, decoding the JWT payload locally to check `exp` before trusting it — no server round-trip for this check.
- `apiClientProvider` builds the shared `Dio` instance: an interceptor attaches `Authorization: Bearer <token>` from `authTokenProvider` to every request, and clears the token (logging the user out) on any `401` response.
- API base URL is compile-time configurable: `String.fromEnvironment('API_BASE_URL', ...)`, i.e. pass `--dart-define=API_BASE_URL=...` at build/run time to point at a different backend; defaults to a hardcoded IP in `auth_viewmodel.dart`.
- Login (`LoginViewModel.login`) calls `AuthRepository.login` then `AuthTokenNotifier.setToken`, catching `DioException`/`SocketException`/`FormatException` and rethrowing as `AuthException` with a French message; `LoginScreen` just reads `loginViewModelProvider`'s `.error`/`.isLoading` — it has no try/catch of its own.

### Photo capture flow

`PhotoCaptureScreen` (student lookup + camera) → `PhotoValidationScreen` (review/retake/confirm) → upload:

1. User enters a matricule; `PhotoCaptureViewModel.searchStudent` calls `StudentRepository.getStudentByMatricule`.
2. On success, `CameraViewModel.initialize` starts the camera (`camera` package), preferring the back lens (staff photographs the student, not themselves). On Android the image stream format is forced to `ImageFormatGroup.nv21` (vs. `bgra8888` on iOS) — ML Kit's face detector expects a single-plane NV21 buffer on Android; leaving CameraX's default `YUV_420_888` causes a native "Getting Image failed" error. Don't change this platform branch without re-verifying against `google_mlkit_face_detection`.
3. While the camera streams, `FaceDetectorViewModel.processCameraImage` runs ML Kit face detection per frame (dropping frames while a previous one is still processing) and reports one of `FaceDetectionStatus` (`noFace`, `faceDetected`, `tooManyFaces`, `searching`, `error`). `CameraOverlay` reflects this status visually as an oval guide over the preview.
4. Two capture modes exist: "guided" (viewfinder overlay, capture blocked unless exactly one face is detected) and "native" (no gating). Toggled in `PhotoCaptureScreen`.
5. `CameraViewModel.takePicture` stops the image stream and captures, returning `null` on failure instead of throwing — `PhotoCaptureScreen` branches on that rather than catching an exception.
6. After capture, `PhotoValidationScreen` lets the user confirm or retake; confirming calls `PhotoCaptureViewModel.uploadPhoto`, which posts the file via `StudentRepository.uploadPhoto` (multipart) keyed by the student's matricule.

### State/error conventions

- Async viewmodel state uses `AsyncValue`/`AsyncValue.guard` (see `PhotoCaptureViewModel`, `CameraViewModel`, `LoginViewModel`) rather than manual try/catch + loading flags in views. Views should read `AsyncValue.isLoading`/`.value`/`.error` and react declaratively; if you find yourself adding a `try`/`catch` inside a `views/` file, that logic almost certainly belongs in a viewmodel instead.
- User-facing error messages are French, built inside the viewmodel (e.g. `AuthException` in `auth_viewmodel.dart`) and just displayed by the view — not mapped from exception type at the call site in the view.

## Code style

- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no project-specific rule overrides — standard flutter_lints rules apply.
