import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:freedom_music_dart/pages/playlists_page.dart';
import 'package:provider/provider.dart';

import '../permisson/permisson_provider.dart';
import '../theme/theme_provider.dart';
import '../widgets/song.dart';


class HomePage extends StatefulWidget{
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadMusic();
  }

  Future<void> _requestPermissionAndLoadMusic() async {
    final permissionProvider = Provider.of<PermissionProvider>(
        context, listen: false);

    // Запрашиваем разрешение
    await permissionProvider.requestStoragePermission();

    // Проверяем, если разрешение предоставлено
    if (permissionProvider.storagePermissionGranted) {
      // Импортируем файлы музыки
      print('succcess');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      body: Center(child: ListView(
        children: [
          SongTile(
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            duration: "3:20",
            cover: "https://placehold.co/400.png",
            isContainLyrics: true,
            isPlaying: true,
          ),
          ],
      )),
    );
  }
}