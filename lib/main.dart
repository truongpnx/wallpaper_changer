import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'providers/wallpaper_provider.dart';
import 'screens/albums_screen.dart';
import 'screens/trigger_screen.dart';
import 'services/wallpaper_service.dart';

const _wallpaperTaskName = 'wallpaperChangeTask';

/// Top-level callback for WorkManager — runs even if the app is killed.
/// No Provider dependency; reads state directly from SharedPreferences.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _wallpaperTaskName) {
      await WallpaperService.changeToNextWallpaper();
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  runApp(const WallpaperApp());
}

class WallpaperApp extends StatelessWidget {
  const WallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WallpaperProvider()..initialize(),
      child: MaterialApp(
        title: 'Wallpaper Changer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  static const _screens = [AlbumsScreen(), TriggerScreen()];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WallpaperProvider>();

    return Scaffold(
      body: SafeArea(
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _screens[_tabIndex],
      ),
      floatingActionButton: provider.isLoading
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_tabIndex == 0) {
                  showCreateAlbumDialog(context);
                } else {
                  showCreateStrategyDialog(context);
                }
              },
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.photo_library), label: 'Albums'),
          BottomNavigationBarItem(
              icon: Icon(Icons.timer), label: 'Trigger'),
        ],
      ),
    );
  }
}
