import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../providers/wallpaper_provider.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

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

        final albums = provider.albums;

        if (albums.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No albums yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateAlbumDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Album'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return _AlbumGridItem(
              album: album,
              onTap: () => _openAlbumDialog(context, album),
            );
          },
        );
      },
    );
  }

  static void _showCreateAlbumDialog(
      BuildContext context, WallpaperProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Album'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Album name'),
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
                provider.createAlbum(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openAlbumDialog(BuildContext context, Album album) {
    showDialog(
      context: context,
      builder: (_) => _AlbumDetailDialog(albumId: album.id),
    );
  }
}

/// Exposed for use from AppBar action.
void showCreateAlbumDialog(BuildContext context) {
  final provider = context.read<WallpaperProvider>();
  AlbumsScreen._showCreateAlbumDialog(context, provider);
}

// ── Grid item (square album card) ──

class _AlbumGridItem extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumGridItem({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image or placeholder
            if (album.imagePaths.isNotEmpty)
              Image.file(
                File(album.imagePaths.first),
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 40),
                ),
              )
            else
              Container(
                color: Colors.grey[200],
                child: const Icon(Icons.photo_album, size: 40, color: Colors.grey),
              ),
            // Bottom gradient + label
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(album.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text('${album.imagePaths.length} images',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Album detail dialog (stateful for edit mode) ──

class _AlbumDetailDialog extends StatefulWidget {
  final String albumId;
  const _AlbumDetailDialog({required this.albumId});

  @override
  State<_AlbumDetailDialog> createState() => _AlbumDetailDialogState();
}

class _AlbumDetailDialogState extends State<_AlbumDetailDialog> {
  bool _editing = false;
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<WallpaperProvider>(
      builder: (context, provider, _) {
        final album = provider.albums
            .cast<Album?>()
            .firstWhere((a) => a!.id == widget.albumId, orElse: () => null);
        if (album == null) {
          // Album was deleted while dialog was open
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.of(context).pop());
          return const SizedBox.shrink();
        }

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          album.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Rename',
                        onPressed: () => _showRenameDialog(context, provider, album),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Delete album',
                        onPressed: () =>
                            _confirmDeleteAlbum(context, provider, album),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── Image grid ──
                Flexible(
                  child: album.imagePaths.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No images yet',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: album.imagePaths.length,
                          itemBuilder: (context, index) {
                            final path = album.imagePaths[index];
                            final isSelected = _selected.contains(index);
                            return GestureDetector(
                              onTap: () {
                                if (_editing) {
                                  setState(() {
                                    if (isSelected) {
                                      _selected.remove(index);
                                    } else {
                                      _selected.add(index);
                                    }
                                  });
                                } else {
                                  _viewImage(context, album.imagePaths, index);
                                }
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      cacheWidth: 200,
                                      errorBuilder: (_, _, _) => Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                  if (_editing)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.black38,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const Divider(height: 1),

                // ── Bottom buttons ──
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _editing
                            ? OutlinedButton(
                                onPressed: () => setState(() {
                                  _editing = false;
                                  _selected.clear();
                                }),
                                child: const Text('Cancel'),
                              )
                            : OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _editing = true),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _editing
                            ? FilledButton.icon(
                                onPressed: _selected.isEmpty
                                    ? null
                                    : () => _deleteSelected(provider, album),
                                icon: const Icon(Icons.delete, size: 18),
                                label: Text('Delete (${_selected.length})'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: () =>
                                    provider.addImagesToAlbum(album.id),
                                icon: const Icon(Icons.add_photo_alternate,
                                    size: 18),
                                label: const Text('Add Images'),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteSelected(WallpaperProvider provider, Album album) {
    // Remove in reverse order to keep indices valid
    final sorted = _selected.toList()..sort((a, b) => b.compareTo(a));
    for (final index in sorted) {
      provider.removeImageFromAlbum(album.id, index);
    }
    setState(() {
      _selected.clear();
      _editing = false;
    });
  }

  void _viewImage(BuildContext context, List<String> paths, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => _ImageViewerDialog(paths: paths, initialIndex: initialIndex),
    );
  }

  void _showRenameDialog(
      BuildContext context, WallpaperProvider provider, Album album) {
    final controller = TextEditingController(text: album.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Album'),
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
                provider.renameAlbum(album.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAlbum(
      BuildContext context, WallpaperProvider provider, Album album) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Album'),
        content: Text(
            'Delete "${album.name}" and its ${album.imagePaths.length} images?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // close confirm
              Navigator.pop(context); // close detail dialog
              provider.deleteAlbum(album.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ImageViewerDialog extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _ImageViewerDialog({required this.paths, required this.initialIndex});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Swipeable pages
          PageView.builder(
            controller: _pageController,
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Center(
                  child: Image.file(
                    File(widget.paths[index]),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 64),
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Counter
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.paths.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),

          // Left arrow
          if (_currentIndex > 0)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white70, size: 36),
                  onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut),
                ),
              ),
            ),

          // Right arrow
          if (_currentIndex < widget.paths.length - 1)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: Colors.white70, size: 36),
                  onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
