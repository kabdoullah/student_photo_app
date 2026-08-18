# Photo d'identité

Application Flutter destinée au personnel du Collège Privé La Vallée du Centre pour rechercher un élève par matricule, capturer une photo d'identité avec détection de visage guidée, et l'envoyer vers l'API du serveur. Interface entièrement en français.

## Fonctionnalités

- Recherche d'un élève par matricule
- Capture photo avec cadrage guidé (détection de visage en temps réel via ML Kit)
- Mode natif sans guidage, en alternative au mode guidé
- Contrôle qualité automatique de la photo (cadrage et luminosité) avant validation
- Envoi de la photo vers l'API backend

## Stack technique

- Flutter, architecture MVVM avec Riverpod (`@riverpod` codegen)
- `camera` pour la capture, `google_mlkit_face_detection` pour la détection de visage
- `freezed` / `json_serializable` pour les modèles de données
- `dio` pour les appels réseau, `flutter_secure_storage` pour le token JWT

## Prise en main

```bash
flutter pub get                        # installer les dépendances
flutter run                            # lancer sur un appareil/émulateur connecté
flutter analyze                        # analyse statique (flutter_lints)
flutter test                           # exécuter tous les tests
dart run build_runner build --delete-conflicting-outputs   # régénérer les *.freezed.dart / *.g.dart après modif des modèles
flutter build apk --release            # build APK release
```

Les builds pointent par défaut vers un serveur backend codé en dur. Pour cibler un autre serveur :

```bash
flutter run --dart-define=API_BASE_URL=https://mon-serveur.example.com
```

## Architecture

Architecture MVVM avec Riverpod, utilisant la génération de code `@riverpod` (`riverpod_generator`) pour chaque viewmodel. Le code source est organisé en couches dans `lib/` :

- `models/` — classes de données Freezed/json_serializable. `Student.fromApiJson` normalise les noms de champs incohérents renvoyés par le backend (clés anglaises et françaises, ex. `first_name`/`prenom`).
- `repositories/` — wrappers Dio légers par ressource (`AuthRepository`, `StudentRepository`), sans logique métier : uniquement des appels HTTP et la mise en forme des réponses.
- `viewmodels/` — classes/fonctions `@riverpod` qui détiennent l'état de l'UI et orchestrent les appels aux repositories (`AuthTokenNotifier`, `PhotoCaptureViewModel`, `FaceDetectorViewModel`, `CameraViewModel`, `PhotoQualityViewModel`, `LoginViewModel`).
- `views/` — écrans (`ConsumerStatefulWidget`/`ConsumerWidget`) et `views/widgets/` pour les éléments partagés comme `CameraOverlay`.

### Structure du projet

```text
lib/
├── main.dart                          # point d'entrée ; _AuthGate bascule Login/PhotoCapture selon authTokenProvider
│
├── models/                            # couche données (Freezed / json_serializable)
│   └── student.dart                   # classe Student ; fromApiJson normalise les champs FR/EN du backend
│
├── repositories/                      # wrappers Dio, un par ressource, sans logique métier
│   ├── auth_repository.dart           # appel /login
│   └── student_repository.dart        # recherche élève par matricule + upload photo (multipart)
│
├── viewmodels/                        # état UI + orchestration, tous en @riverpod (codegen)
│   ├── auth_viewmodel.dart            # AuthTokenNotifier : JWT, restauration/expiration, apiClient Dio
│   ├── camera_viewmodel.dart          # CameraViewModel : init caméra, takePicture, crop au format ID
│   ├── face_detector_viewmodel.dart   # FaceDetectorViewModel : détection de visage ML Kit par frame
│   ├── photo_capture_viewmodel.dart   # PhotoCaptureViewModel : recherche élève + upload photo
│   └── photo_quality_viewmodel.dart   # PhotoQualityViewModel : contrôle cadrage/luminosité post-capture
│
└── views/                             # écrans (ConsumerWidget / ConsumerStatefulWidget)
    ├── login_screen.dart              # écran de connexion
    ├── photo_capture_screen.dart      # recherche matricule + caméra (mode guidé/natif)
    ├── photo_validation_screen.dart   # révision qualité, reprise ou confirmation avant envoi
    └── widgets/
        └── camera_overlay.dart        # overlay caméra : IdPhotoGuidePainter (ovale + repères de cadrage)
```

Chaque fichier `viewmodels/*.dart` et `models/student.dart` a un fichier `.freezed.dart`/`.g.dart` généré associé (omis ci-dessus) — ne jamais les éditer à la main, les régénérer via `build_runner` après modification du fichier source.

### Flux d'authentification

`authTokenProvider` conditionne l'accès à toute l'application : `main.dart` affiche `LoginScreen` ou `PhotoCaptureScreen` selon son état. Au démarrage, le JWT est restauré depuis `flutter_secure_storage` et sa date d'expiration (`exp`) est vérifiée localement, sans aller-retour serveur. Un intercepteur Dio ajoute l'en-tête `Authorization` à chaque requête et déconnecte l'utilisateur sur toute réponse `401`.

### Flux de capture photo

`PhotoCaptureScreen` (recherche d'élève + caméra) → `PhotoValidationScreen` (contrôle qualité + révision/reprise/confirmation) → envoi :

1. Recherche d'un élève par matricule (`PhotoCaptureViewModel.searchStudent`).
2. Démarrage de la caméra arrière (`CameraViewModel.initialize`) ; le flux d'image est forcé en NV21 sur Android pour ML Kit.
3. Détection de visage en temps réel sur chaque frame (`FaceDetectorViewModel.processCameraImage`), reflétée visuellement par `CameraOverlay` et son gabarit `IdPhotoGuidePainter`.
4. Deux modes de capture : « guidé » (capture bloquée tant qu'un seul visage n'est pas détecté) et « natif » (sans contrainte).
5. La photo capturée est recadrée au format photo d'identité (`CameraViewModel.takePicture` / `_cropToIdPhotoFormat`).
6. `PhotoQualityViewModel.analyze` revérifie le cadrage et la luminosité ; la sauvegarde est bloquée tant que les deux ne sont pas jugés corrects. La confirmation envoie la photo au backend via `StudentRepository.uploadPhoto`.

## Documentation pour les contributeurs

Voir [CLAUDE.md](./CLAUDE.md) pour le détail complet de l'architecture, des conventions de code et des contraintes de versions figées des dépendances (`freezed`, `riverpod_generator`, etc.).
