import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';

class StorageService {
  static const _keyAppState = 'app_state_v2';

  static const validExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};

  static Future<AppState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyAppState);
    if (json == null) return AppState.defaults();
    try {
      return AppState.fromJson(json);
    } catch (_) {
      return AppState.defaults();
    }
  }

  static Future<void> saveState(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppState, state.toJson());
  }

  /// Validates image paths: checks file existence, valid extension, non-zero size.
  static Future<List<String>> validateAndCleanPaths(List<String> paths) async {
    final validPaths = <String>[];
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        final ext = path.split('.').last.toLowerCase();
        if (validExtensions.contains(ext)) {
          final stat = await file.stat();
          if (stat.size > 0) {
            validPaths.add(path);
          }
        }
      }
    }
    return validPaths;
  }

  /// Validate all albums' image paths and prune invalid ones.
  /// Returns true if any changes were made.
  static Future<bool> validateAlbums(AppState state) async {
    bool changed = false;
    for (final album in state.albums) {
      final valid = await validateAndCleanPaths(album.imagePaths);
      if (valid.length != album.imagePaths.length) {
        album.imagePaths = valid;
        changed = true;
      }
    }
    return changed;
  }
}
