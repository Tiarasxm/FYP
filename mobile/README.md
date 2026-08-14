# ShapeRush Mobile

Flutter frontend for ShapeRush. Currently UI-only with mock data.

## Getting started

```bash
cd mobile
flutter create .
flutter pub get
flutter doctor
```

## Running

```bash
flutter run -d chrome     # web
flutter run -d macos      # desktop
flutter run               # android emulator
```

## Structure

```
lib/
  main.dart
  theme/app_theme.dart
  data/mock_data.dart
  models/
  screens/
  widgets/
```

All data is hardcoded in mock_data.dart for now. Social and Profile tabs are placeholders.
