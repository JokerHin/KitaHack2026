# Flutter app scaffold

This folder contains a minimal Flutter app example that demonstrates running a local TFLite model.

Quick start:

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. From `mobile/flutter` run:

```bash
flutter pub get
flutter run -d chrome   # or an emulator/device
```

Place your `model.tflite` in `mobile/flutter/assets/` (the `pubspec.yaml` includes `assets/model.tflite`).

Notes:

- Ensure the TFLite input shape and preprocessing match what your Python retraining pipeline exported.
- For production, consider hosting new TFLite models in Firebase Storage and implementing an update/download flow.
- For Android/iOS you must add Firebase config files (`google-services.json` / `GoogleService-Info.plist`). See Firebase console > Project settings > Add app.
- On Windows run the provided script from repo root:

```bat
mobile\run_frontend.bat
```

Troubleshooting:

- If you see Firebase errors, add `google-services.json` into `android/app/` and follow the Firebase Flutter setup docs.
- If the TFLite model input shape doesn't match, re-export the model or update the Dart preprocessing.
