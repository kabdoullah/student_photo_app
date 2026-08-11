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
flutter build apk --release            # build a release APK (build/app/outputs/flutter-apk/app-release.apk)
```

There is no CI config in this repo; `flutter analyze` and `flutter test` are the checks to run before considering a change done.

Release builds point at the hardcoded default backend unless overridden: pass `--dart-define=API_BASE_URL=...` to `flutter run`/`flutter build apk` to target a different server (see Auth flow below).

### Pinned dependency versions — do not casually `pub upgrade`

`freezed`/`json_serializable` (which need an older `analyzer`) and `riverpod_generator` (which needs a specific `analyzer` too) only overlap in a narrow, non-latest version band. `pubspec.yaml` pins exact versions for this reason: `flutter_riverpod: 3.2.1`, `riverpod_annotation: 4.0.2`, `riverpod_generator: 4.0.3`, `json_serializable: 6.13.0`, `json_annotation: 4.11.0`. `flutter pub outdated` will show all of these as behind latest — that's expected, not drift to fix. Bumping any one of them without re-checking the whole `analyzer` compatibility chain will break `build_runner`. `flutter_launcher_icons` and `flutter_native_splash` are build/runtime tools outside this chain and can be upgraded independently.

### App icon & splash screen

The launcher icon and native splash both reuse the same source art and navy palette (`#002B48`, matching the login screen) so the app feels continuous from tap to first frame:

- `assets/icon/app_icon.png` — full 1024×1024 opaque icon (Android default/iOS/web).
- `assets/icon/app_icon_foreground.png` — transparent-background glyph, sized inside the Android adaptive-icon safe zone; also reused as the splash image.

Config lives in `pubspec.yaml` under the `flutter_launcher_icons:` and `flutter_native_splash:` keys. After editing either PNG, regenerate both:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

`main.dart` calls `FlutterNativeSplash.preserve()` before `runApp` and only calls `FlutterNativeSplash.remove()` once `authTokenProvider` finishes restoring the session (see `_AuthGate` in `main.dart`) — this keeps the native splash on screen through the async token-restore instead of flashing a generic loading spinner.

## Architecture

MVVM with Riverpod, using `@riverpod` codegen (`riverpod_generator`) for every viewmodel — no hand-written `NotifierProvider`/`AsyncNotifierProvider` declarations. Layers, in `lib/`:

- `models/` — Freezed/json_serializable data classes. `Student.fromApiJson` normalizes inconsistent backend field names (handles both English and French keys, e.g. `first_name`/`prenom`, `last_name`/`nom`) — this is the tolerant boundary against an API whose payload shape isn't fully fixed. After changing any `@freezed` model or any `@riverpod` viewmodel, regenerate with `build_runner` (see Commands).
- `repositories/` — thin Dio wrappers per resource (`AuthRepository`, `StudentRepository`). No business logic; just HTTP calls and response shaping. Their providers are declared inconsistently — `authRepositoryProvider` is `@Riverpod(keepAlive: true)` codegen living in `auth_viewmodel.dart`, while `studentRepositoryProvider` is a hand-written plain `Provider` inside `student_repository.dart` itself. Match whichever pattern the repository you're touching already uses.
- `viewmodels/` — `@riverpod` classes/functions holding UI state and orchestrating repository calls (`AuthTokenNotifier`, `PhotoCaptureViewModel`, `FaceDetectorViewModel`, `CameraViewModel`, `PhotoQualityViewModel`, `LoginViewModel`). Each `.dart` file has a matching generated `.g.dart` part (`part 'x_viewmodel.g.dart';`) — never edit `.g.dart` files by hand.
  - `@Riverpod(keepAlive: true)` is used on providers that must survive across screens for the app's lifetime (`AuthTokenNotifier`, `apiClient`, `authRepository`, `secureStorage`, `PhotoCaptureViewModel`, `FaceDetectorViewModel`). Providers scoped to a single screen's lifecycle use plain `@riverpod` (autoDispose by default): `CameraViewModel`, `LoginViewModel`, `PhotoQualityViewModel`.
  - Provider names are derived automatically from the annotated function/class name (lowerCamelCase + `Provider` suffix); classes ending in `Notifier` have that suffix stripped (e.g. `AuthTokenNotifier` → `authTokenProvider`). Don't rename a viewmodel class without checking what the generated provider name becomes.
- `views/` — screens (`ConsumerStatefulWidget`/`ConsumerWidget`) and `views/widgets/` for shared pieces like `CameraOverlay`.

### Auth flow

- `authTokenProvider` (`lib/viewmodels/auth_viewmodel.dart`) gates the whole app: `main.dart`'s `_AuthGate` shows `LoginScreen` or `PhotoCaptureScreen` based on `authTokenProvider`'s state, and removes the native splash screen once that state stops loading (see App icon & splash screen above).
- On startup the notifier restores a JWT from `flutter_secure_storage`, decoding the JWT payload locally to check `exp` before trusting it — no server round-trip for this check.
- `apiClientProvider` builds the shared `Dio` instance: an interceptor attaches `Authorization: Bearer <token>` from `authTokenProvider` to every request, and clears the token (logging the user out) on any `401` response.
- API base URL is compile-time configurable: `String.fromEnvironment('API_BASE_URL', ...)`, i.e. pass `--dart-define=API_BASE_URL=...` at build/run time to point at a different backend; defaults to a hardcoded IP in `auth_viewmodel.dart`.
- Login (`LoginViewModel.login`) calls `AuthRepository.login` then `AuthTokenNotifier.setToken`, catching `DioException`/`SocketException`/`FormatException` and rethrowing as `AuthException` with a French message; `LoginScreen` just reads `loginViewModelProvider`'s `.error`/`.isLoading` — it has no try/catch of its own.

### Photo capture flow

`PhotoCaptureScreen` (student lookup + camera) → `PhotoValidationScreen` (quality check + review/retake/confirm) → upload:

1. User enters a matricule; `PhotoCaptureViewModel.searchStudent` calls `StudentRepository.getStudentByMatricule`.
2. On success, `CameraViewModel.initialize` starts the camera (`camera` package), preferring the back lens (staff photographs the student, not themselves). On Android the image stream format is forced to `ImageFormatGroup.nv21` (vs. `bgra8888` on iOS) — ML Kit's face detector expects a single-plane NV21 buffer on Android; leaving CameraX's default `YUV_420_888` causes a native "Getting Image failed" error. Don't change this platform branch without re-verifying against `google_mlkit_face_detection`.
3. While the camera streams, `FaceDetectorViewModel.processCameraImage` runs ML Kit face detection per frame (dropping frames while a previous one is still processing) and reports one of `FaceDetectionStatus` (`noFace`, `faceDetected`, `tooManyFaces`, `searching`, `error`). `CameraOverlay` reflects this status visually, painting `IdPhotoGuidePainter` (an oval + corner brackets measured directly off the school's reference ID photo — see the geometry comments in `views/widgets/camera_overlay.dart`) over the preview.
4. Two capture modes exist: "guided" (viewfinder overlay, capture blocked unless exactly one face is detected) and "native" (no gating). Toggled in `PhotoCaptureScreen`.
5. `CameraViewModel.takePicture` stops the image stream, captures, then `_cropToIdPhotoFormat` center-crops the result to `idPhotoAspectRatio` (424/480, the same constant used for the live preview frame and the validation-screen frame) and re-encodes it at a fixed width — so the file that gets uploaded always matches what the agent saw on screen, regardless of the device's sensor/resolution. Returns `null` on failure instead of throwing — `PhotoCaptureScreen` branches on that rather than catching an exception.
6. `PhotoValidationScreen` kicks off `PhotoQualityViewModel.analyze` on the captured file (re-running ML Kit face detection plus a sampled-pixel brightness check) and renders `IdPhotoGuidePainter` again over the still photo for the same expected-framing reference. Saving is blocked (`qualityBlocksSave`) until framing and brightness both come back `good` — this is a real automated check, not a static checklist. Confirming calls `PhotoCaptureViewModel.uploadPhoto`, which posts the file via `StudentRepository.uploadPhoto` (multipart) keyed by the student's matricule.

### State/error conventions

- Async viewmodel state uses `AsyncValue`/`AsyncValue.guard` (see `PhotoCaptureViewModel`, `CameraViewModel`, `PhotoQualityViewModel`, `LoginViewModel`) rather than manual try/catch + loading flags in views. Views should read `AsyncValue.isLoading`/`.value`/`.error` and react declaratively; if you find yourself adding a `try`/`catch` inside a `views/` file, that logic almost certainly belongs in a viewmodel instead.
- User-facing error messages are French, built inside the viewmodel (e.g. `AuthException` in `auth_viewmodel.dart`) and just displayed by the view — not mapped from exception type at the call site in the view.

## Code style

- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no project-specific rule overrides — standard flutter_lints rules apply.
