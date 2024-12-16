

import 'package:flutter/material.dart';
import 'package:freedom_music_dart/theme/theme_provider.dart';
import 'package:freedom_music_dart/permisson/permisson_provider.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/history.dart';
import 'models/music.dart';
import 'models/queue.dart';
import 'models/settings.dart';
import 'pages/home_page.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/app_bar.dart';
import 'pages/playlists_page.dart';
import 'pages/artists_page.dart';
import 'pages/albums_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';


import 'package:permission_handler/permission_handler.dart';




void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(SettingsAdapter());
  Hive.openBox<Settings>('settings');
  Box<Settings> settingsBox = Hive.box<Settings>('settings');

  Hive.registerAdapter(MusicAdapter());
  Hive.registerAdapter(HistoryAdapter());
  Hive.registerAdapter(QueueAdapter());
  await Hive.openLazyBox<Music>('music');
  await Hive.openLazyBox<History>('history');
  await Hive.openLazyBox<Queue>('queue');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ThemeProvider themeProvider, child) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FreedomMusic Demo',
        theme: themeProvider.themeData,
        home: const MainPage(),
      );
    });
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const PlaylistsPage(),
    const ArtistsPage(),
    const AlbumsPage(),
    const ProfilePage(),
  ];

  void _navigateToSettingsPage() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onReturn: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarC(onSettingsTap: _navigateToSettingsPage),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
