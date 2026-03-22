import 'dart:convert';

class Album {
  final String id;
  String name;
  List<String> imagePaths;

  Album({required this.id, required this.name, List<String>? imagePaths})
      : imagePaths = imagePaths ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePaths': imagePaths,
      };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
        id: json['id'] as String,
        name: json['name'] as String,
        imagePaths: List<String>.from(json['imagePaths'] as List),
      );
}

class TriggerStrategy {
  final String id;
  String name;
  List<String> albumIds; // selected album IDs
  int intervalMinutes;
  String wallpaperLocation; // 'homeScreen', 'lockScreen', 'both'
  bool enabled;
  int currentIndex;

  TriggerStrategy({
    required this.id,
    required this.name,
    List<String>? albumIds,
    this.intervalMinutes = 15,
    this.wallpaperLocation = 'homeScreen',
    this.enabled = false,
    this.currentIndex = 0,
  }) : albumIds = albumIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'albumIds': albumIds,
        'intervalMinutes': intervalMinutes,
        'wallpaperLocation': wallpaperLocation,
        'enabled': enabled,
        'currentIndex': currentIndex,
      };

  factory TriggerStrategy.fromJson(Map<String, dynamic> json) =>
      TriggerStrategy(
        id: json['id'] as String,
        name: json['name'] as String,
        albumIds: List<String>.from(json['albumIds'] as List),
        intervalMinutes: json['intervalMinutes'] as int,
        wallpaperLocation: json['wallpaperLocation'] as String,
        enabled: json['enabled'] as bool,
        currentIndex: json['currentIndex'] as int? ?? 0,
      );
}

class AppState {
  List<Album> albums;
  List<TriggerStrategy> strategies;

  AppState({List<Album>? albums, List<TriggerStrategy>? strategies})
      : albums = albums ?? [],
        strategies = strategies ?? [];

  factory AppState.defaults() => AppState();

  /// Collect all image paths from the given album IDs.
  List<String> collectImages(List<String> albumIds) {
    final paths = <String>[];
    for (final album in albums) {
      if (albumIds.contains(album.id)) {
        paths.addAll(album.imagePaths);
      }
    }
    return paths;
  }

  /// Find the single enabled strategy, or null.
  TriggerStrategy? get activeStrategy {
    for (final s in strategies) {
      if (s.enabled) return s;
    }
    return null;
  }

  String toJson() => jsonEncode({
        'albums': albums.map((a) => a.toJson()).toList(),
        'strategies': strategies.map((s) => s.toJson()).toList(),
      });

  factory AppState.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AppState(
      albums: (map['albums'] as List).map((e) => Album.fromJson(e)).toList(),
      strategies: (map['strategies'] as List)
          .map((e) => TriggerStrategy.fromJson(e))
          .toList(),
    );
  }
}
