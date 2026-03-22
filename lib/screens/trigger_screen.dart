import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../providers/wallpaper_provider.dart';

class TriggerScreen extends StatelessWidget {
  const TriggerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WallpaperProvider>(
      builder: (context, provider, _) {
        if (provider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(provider.error!)),
            );
            provider.clearError();
          });
        }

        final strategies = provider.strategies;

        if (strategies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No trigger strategies yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showCreateStrategyDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Strategy'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            // Set Now button at top if there's an active strategy
            if (provider.activeStrategy != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _setNow(context, provider),
                  icon: const Icon(Icons.wallpaper),
                  label: const Text('Set Wallpaper Now'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...strategies
                .map((s) => _StrategyCard(strategy: s)),
          ],
        );
      },
    );
  }

  void _setNow(BuildContext context, WallpaperProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    await provider.setWallpaperNow();
    if (provider.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.error!)));
      provider.clearError();
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Wallpaper set successfully!')));
    }
  }

  static void _showCreateStrategyDialog(
      BuildContext context, WallpaperProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Strategy'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Strategy name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                provider.createStrategy(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Exposed for use from AppBar add button.
void showCreateStrategyDialog(BuildContext context) {
  final provider = context.read<WallpaperProvider>();
  TriggerScreen._showCreateStrategyDialog(context, provider);
}

class _StrategyCard extends StatelessWidget {
  final TriggerStrategy strategy;
  const _StrategyCard({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WallpaperProvider>();
    final albums = provider.albums;
    final isActive = strategy.enabled;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isActive ? Colors.green.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: Colors.green.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(strategy.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ACTIVE',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    switch (val) {
                      case 'rename':
                        _showRenameDialog(context, provider);
                        break;
                      case 'delete':
                        _confirmDelete(context, provider);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const Divider(),

            // Current / Next image preview
            Builder(builder: (_) {
              final images = provider.state.collectImages(strategy.albumIds);
              if (images.isEmpty) return const SizedBox.shrink();
              final nextIdx = strategy.currentIndex % images.length;
              final currentIdx =
                  (strategy.currentIndex - 1 + images.length) % images.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _PreviewTile(
                        label: 'Current',
                        path: images[currentIdx],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PreviewTile(
                        label: 'Next',
                        path: images[nextIdx],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Album selection
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Albums'),
              subtitle: Text(_albumSummary(albums)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAlbumPicker(context, provider, albums),
            ),

            // Interval
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Interval'),
              subtitle: Text(_formatInterval(strategy.intervalMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showIntervalPicker(context, provider),
            ),

            // Wallpaper location
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply To'),
              subtitle: Text(_locationLabel(strategy.wallpaperLocation)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLocationPicker(context, provider),
            ),

            const SizedBox(height: 8),

            // Enable / Disable toggle
            SizedBox(
              width: double.infinity,
              child: isActive
                  ? OutlinedButton(
                      onPressed: () =>
                          provider.disableStrategy(strategy.id),
                      child: const Text('Disable'),
                    )
                  : FilledButton(
                      onPressed: () =>
                          provider.enableStrategy(strategy.id),
                      child: const Text('Enable'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _albumSummary(List<Album> allAlbums) {
    if (strategy.albumIds.isEmpty) return 'None selected';
    final names = allAlbums
        .where((a) => strategy.albumIds.contains(a.id))
        .map((a) => a.name);
    return names.isEmpty ? 'None selected' : names.join(', ');
  }

  String _formatInterval(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hour${hours > 1 ? "s" : ""}';
    return '${hours}h ${mins}m';
  }

  String _locationLabel(String loc) {
    switch (loc) {
      case 'lockScreen':
        return 'Lock Screen';
      case 'both':
        return 'Home & Lock Screen';
      default:
        return 'Home Screen';
    }
  }

  void _showAlbumPicker(
      BuildContext context, WallpaperProvider provider, List<Album> albums) {
    if (albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create an album first')));
      return;
    }

    final selected = Set<String>.from(strategy.albumIds);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Select Albums'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: albums.map((album) {
                return CheckboxListTile(
                  value: selected.contains(album.id),
                  title: Text(album.name),
                  subtitle: Text('${album.imagePaths.length} images'),
                  onChanged: (val) {
                    setLocalState(() {
                      if (val == true) {
                        selected.add(album.id);
                      } else {
                        selected.remove(album.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                provider.setStrategyAlbums(
                    strategy.id, selected.toList());
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIntervalPicker(
      BuildContext context, WallpaperProvider provider) {
    final intervals = [
      15,
      30,
      60,
      120,
      240,
      480,
      720,
      1440,
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Interval'),
        children: intervals
            .map(
              (m) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx);
                  provider.setStrategyInterval(strategy.id, m);
                },
                child: Text(
                  _formatInterval(m),
                  style: TextStyle(
                    fontWeight: strategy.intervalMinutes == m
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showLocationPicker(
      BuildContext context, WallpaperProvider provider) {
    const locations = {
      'homeScreen': 'Home Screen',
      'lockScreen': 'Lock Screen',
      'both': 'Home & Lock Screen',
    };
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Apply Wallpaper To'),
        children: locations.entries
            .map(
              (e) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx);
                  provider.setStrategyLocation(strategy.id, e.key);
                },
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: strategy.wallpaperLocation == e.key
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WallpaperProvider provider) {
    final controller = TextEditingController(text: strategy.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Strategy'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                provider.renameStrategy(strategy.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WallpaperProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Strategy'),
        content: Text('Delete "${strategy.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteStrategy(strategy.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final String label;
  final String path;

  const _PreviewTile({required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.grey)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
