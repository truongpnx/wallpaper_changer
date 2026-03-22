import 'dart:io';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

import 'storage_service.dart';

enum WallpaperLocation { homeScreen, lockScreen, both }

WallpaperLocation parseWallpaperLocation(String value) {
  switch (value) {
    case 'lockScreen':
      return WallpaperLocation.lockScreen;
    case 'both':
      return WallpaperLocation.both;
    default:
      return WallpaperLocation.homeScreen;
  }
}

class WallpaperService {
  static final _manager = WallpaperManagerFlutter();

  /// Set wallpaper safely
  static Future<bool> setWallpaper(
    String filePath, {
    WallpaperLocation location = WallpaperLocation.homeScreen,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      int target;
      switch (location) {
        case WallpaperLocation.homeScreen:
          target = WallpaperManagerFlutter.homeScreen;
          break;
        case WallpaperLocation.lockScreen:
          target = WallpaperManagerFlutter.lockScreen;
          break;
        case WallpaperLocation.both:
          target = WallpaperManagerFlutter.bothScreens;
          break;
      }

      final result = await _manager.setWallpaper(file, target);
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Called from WorkManager — no Provider dependency.
  static Future<bool> changeToNextWallpaper() async {
    try {
      final state = await StorageService.loadState();
      final strategy = state.activeStrategy;
      if (strategy == null || !strategy.enabled) return true;

      // Collect images from selected albums
      final allPaths = state.collectImages(strategy.albumIds);
      if (allPaths.isEmpty) return true;

      // Validate
      final validPaths = await StorageService.validateAndCleanPaths(allPaths);
      if (validPaths.isEmpty) return true;

      // Safe index
      final index = strategy.currentIndex % validPaths.length;
      final imagePath = validPaths[index];
      final location = parseWallpaperLocation(strategy.wallpaperLocation);

      final success = await setWallpaper(imagePath, location: location);

      if (success) {
        strategy.currentIndex = (index + 1) % validPaths.length;
        await StorageService.saveState(state);
      }

      return success;
    } catch (_) {
      return false;
    }
  }
}
                