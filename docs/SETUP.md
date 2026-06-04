# NeuroPOS — Setup

## Prerequisites

- Flutter SDK >= 3.22 (Dart >= 3.4)
- Windows: Visual Studio with "Desktop development with C++"
- Android: Android SDK / Android Studio

## 1. Generate platform runner folders

This repo intentionally commits only the cross-platform `lib/` code, `pubspec.yaml`, and
docs. The `android/` and `windows/` runner folders are environment-specific and are
generated locally. From the repo root:

```bash
flutter create . --platforms=windows,android --project-name neuropos
```

`flutter create .` is non-destructive to existing `lib/`, `pubspec.yaml`, and `test/`.

## 2. Dependencies & code generation

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

`build_runner` generates:
- `lib/data/local/database.g.dart` (drift)
- `*.g.dart` for Riverpod providers

These generated files are git-ignored and must be produced after every clone.

## 3. Configure the server connection

On first launch the app asks for:
- **Site URL** — e.g. `https://erp.ccj.example`
- **API key / API secret** (preferred) or username/password

Credentials are stored with `flutter_secure_storage`. The token is reused while offline.

## 4. Run

```bash
flutter run -d windows
# or
flutter devices && flutter run -d <android-device-id>
```

## 5. Tests

```bash
flutter test
```

The tax-engine parity harness (Phase 3) lives in `test/pricing/` and compares the Dart
`TaxEngine` output against the server's `compute_si_taxes` for a matrix of carts.
