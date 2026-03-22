# Wallpaper Changer

A Flutter app for managing wallpaper albums and automatically rotating wallpapers on a schedule.
Because I don't trust AppStore apps
Totally vibe code.


## Features

- **Albums** — Create and manage collections of wallpaper images (add, remove, rename, delete)
- **Trigger Strategies** — Define automatic wallpaper rotation schedules with configurable intervals
- **Wallpaper Targets** — Apply wallpapers to home screen, lock screen, or both
- **Background Execution** — WorkManager keeps rotating wallpapers even when the app is closed
- **Manual Trigger** — "Set Wallpaper Now" button for immediate wallpaper changes
- **Image Viewer** — Swipeable fullscreen viewer with pinch-to-zoom

## Architecture

```
lib/
├── main.dart                     # App entry point, WorkManager callback
├── models/
│   └── app_state.dart            # Album, TriggerStrategy, AppState models
├── providers/
│   └── wallpaper_provider.dart   # ChangeNotifier state management
├── screens/
│   ├── albums_screen.dart        # Album grid & detail dialog
│   └── trigger_screen.dart       # Strategy list & configuration
└── services/
    ├── storage_service.dart      # SharedPreferences persistence
    └── wallpaper_service.dart    # Native wallpaper API & background task
```

## Tech Stack

| Package | Purpose |
|---------|---------|
| provider | State management |
| shared_preferences | Local persistence (JSON) |
| workmanager | Background periodic tasks |
| wallpaper_manager_flutter | Native wallpaper setting |
| image_picker | Gallery image selection |
| path_provider | App file system access |
| uuid | Unique ID generation |

## Getting Started

1. **Clone & install dependencies**
   ```bash
   flutter pub get
   ```

2. **Run on Android**
   ```bash
   flutter run
   ```

3. **Build release APK**
   ```bash
   flutter build apk
   ```

## Requirements

- Flutter SDK (Dart ^3.11.3)
- Android minSdk 21+
