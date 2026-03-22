import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

import '../models/app_state.dart';
import '../services/storage_service.dart';
import '../services/wallpaper_service.dart';

class WallpaperProvider extends ChangeNotifier {
  AppState _state = AppState.defaults();
  bool _isLoading = true;
  String? _error;

  static const _uuid = Uuid();
  static const _taskName = 'wallpaperChangeTask';
  static const _taskTag = 'wallpaperChanger';

  AppState get state => _state;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Album> get albums => _state.albums;
  List<TriggerStrategy> get strategies => _state.strategies;
  TriggerStrategy? get activeStrategy => _state.activeStrategy;

  // ── Initialization ──

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _state = await StorageService.loadState();
      final changed = await StorageService.validateAlbums(_state);
      if (changed) await StorageService.saveState(_state);
    } catch (e) {
      _error = 'Failed to load state: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Album CRUD ──

  Future<void> createAlbum(String name) async {
    final album = Album(id: _uuid.v4(), name: name);
    _state.albums.add(album);
    await _save();
  }

  Future<void> renameAlbum(String albumId, String newName) async {
    final album = _findAlbum(albumId);
    if (album == null) return;
    album.name = newName;
    await _save();
  }

  Future<void> deleteAlbum(String albumId) async {
    // Delete cached files
    final album = _findAlbum(albumId);
    if (album == null) return;
    for (final path in album.imagePaths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _state.albums.removeWhere((a) => a.id == albumId);
    // Remove album from any strategy that references it
    for (final s in _state.strategies) {
      s.albumIds.remove(albumId);
    }
    await _save();
  }

  Future<void> addImagesToAlbum(String albumId) async {
    final album = _findAlbum(albumId);
    if (album == null) return;

    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) {
        await wallpaperDir.create(recursive: true);
      }

      for (final xFile in pickedFiles) {
        final ext = xFile.path.split('.').last.toLowerCase();
        if (!StorageService.validExtensions.contains(ext)) continue;

        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}';
        final destPath = '${wallpaperDir.path}/$fileName';
        await File(xFile.path).copy(destPath);
        album.imagePaths.add(destPath);
      }

      await _save();
    } catch (e) {
      _error = 'Failed to add images: $e';
      notifyListeners();
    }
  }

  Future<void> removeImageFromAlbum(String albumId, int index) async {
    final album = _findAlbum(albumId);
    if (album == null || index < 0 || index >= album.imagePaths.length) return;

    try {
      final file = File(album.imagePaths[index]);
      if (await file.exists()) await file.delete();
      album.imagePaths.removeAt(index);
      await _save();
    } catch (e) {
      _error = 'Failed to remove image: $e';
      notifyListeners();
    }
  }

  // ── Trigger Strategy CRUD ──

  Future<void> createStrategy(String name) async {
    final strategy = TriggerStrategy(id: _uuid.v4(), name: name);
    _state.strategies.add(strategy);
    await _save();
  }

  Future<void> deleteStrategy(String strategyId) async {
    final strategy = _findStrategy(strategyId);
    if (strategy != null && strategy.enabled) {
      await Workmanager().cancelByTag(_taskTag);
    }
    _state.strategies.removeWhere((s) => s.id == strategyId);
    await _save();
  }

  Future<void> renameStrategy(String strategyId, String newName) async {
    final strategy = _findStrategy(strategyId);
    if (strategy == null) return;
    strategy.name = newName;
    await _save();
  }

  Future<void> setStrategyAlbums(
      String strategyId, List<String> albumIds) async {
    final strategy = _findStrategy(strategyId);
    if (strategy == null) return;
    strategy.albumIds = albumIds;
    strategy.currentIndex = 0;
    await _save();
  }

  Future<void> setStrategyInterval(String strategyId, int minutes) async {
    final strategy = _findStrategy(strategyId);
    if (strategy == null) return;
    strategy.intervalMinutes = minutes < 15 ? 15 : minutes;
    await _save();
    if (strategy.enabled) await _registerPeriodicTask(strategy);
  }

  Future<void> setStrategyLocation(
      String strategyId, String location) async {
    final strategy = _findStrategy(strategyId);
    if (strategy == null) return;
    strategy.wallpaperLocation = location;
    await _save();
  }

  /// Enable a strategy. Disables any other currently enabled strategy first.
  Future<void> enableStrategy(String strategyId) async {
    // Disable any currently active strategy
    for (final s in _state.strategies) {
      s.enabled = false;
    }
    final strategy = _findStrategy(strategyId);
    if (strategy == null) return;

    // Check that it has albums with images
    final images = _state.collectImages(strategy.albumIds);
    if (images.isEmpty) {
      _error = 'No images in selected albums';
      notifyListeners();
      return;
    }

    strategy.enabled = true;
    await _save();
    await _registerPeriodicTask(strategy);
  }

  Future<void> disableStrategy(String strategyId) async {
    final strategy = _findStrategy(strategyId);
    if (strategy == null) return;
    strategy.enabled = false;
    await Workmanager().cancelByTag(_taskTag);
    await _save();
  }

  /// Manually set wallpaper using the active strategy right now.
  Future<void> setWallpaperNow() async {
    final strategy = _state.activeStrategy;
    if (strategy == null) {
      _error = 'No active strategy';
      notifyListeners();
      return;
    }

    final allPaths = _state.collectImages(strategy.albumIds);
    if (allPaths.isEmpty) {
      _error = 'No images in selected albums';
      notifyListeners();
      return;
    }

    try {
      final validPaths = await StorageService.validateAndCleanPaths(allPaths);
      if (validPaths.isEmpty) {
        _error = 'No valid images found';
        notifyListeners();
        return;
      }

      final index = strategy.currentIndex % validPaths.length;
      final location = parseWallpaperLocation(strategy.wallpaperLocation);
      final success =
          await WallpaperService.setWallpaper(validPaths[index], location: location);

      if (success) {
        strategy.currentIndex = (index + 1) % validPaths.length;
        await _save();
        _error = null;
      } else {
        _error = 'Failed to set wallpaper';
      }
    } catch (e) {
      _error = 'Failed to set wallpaper: $e';
    }
    notifyListeners();
  }

  // ── Helpers ──

  Album? _findAlbum(String id) {
    for (final a in _state.albums) {
      if (a.id == id) return a;
    }
    return null;
  }

  TriggerStrategy? _findStrategy(String id) {
    for (final s in _state.strategies) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _save() async {
    await StorageService.saveState(_state);
    notifyListeners();
  }

  Future<void> _registerPeriodicTask(TriggerStrategy strategy) async {
    await Workmanager().cancelByTag(_taskTag);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: Duration(minutes: strategy.intervalMinutes),
      tag: _taskTag,
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
