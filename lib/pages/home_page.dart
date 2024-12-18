import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/music.dart';
import '../permisson/permisson_provider.dart';
import '../player/player_provider.dart';
import '../theme/theme_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Box<Music>? musicBox;
  List<Music> _allMusic = [];
  List<Music> _filteredMusic = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadMusic();
  }

  Future<void> _requestPermissionAndLoadMusic() async {
    final permissionProvider = Provider.of<PermissionProvider>(
        context, listen: false);
    await permissionProvider.requestStoragePermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    musicBox = Hive.box<Music>('music');
    _loadMusicList();
  }

  void _loadMusicList() {
    if (musicBox != null) {
      _allMusic = musicBox!.values.toList();
      _applySearchFilter();
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredMusic = _allMusic;
    } else {
      _filteredMusic = _allMusic.where((music) {
        return music.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  Future<void> _refreshMusicList() async {
    _loadMusicList();
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applySearchFilter();
    });
  }

  Future<void> _showEditMetadataDialog(Music song) async {
    TextEditingController titleController = TextEditingController(text: song.title);
    TextEditingController artistsController = TextEditingController(text: song.artists.join(', '));
    TextEditingController albumController = TextEditingController(text: song.album);
    TextEditingController lyricsPlainController = TextEditingController(text: song.lyricsPlain);
    TextEditingController lyricsSyncedController = TextEditingController(text: song.lyricsSynced);

    final result = await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Редактировать метаданные'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Название трека'),
                ),
                TextField(
                  controller: artistsController,
                  decoration: InputDecoration(labelText: 'Исполнители (через запятую)'),
                ),
                TextField(
                  controller: albumController,
                  decoration: InputDecoration(labelText: 'Альбом'),
                ),
                TextField(
                  controller: lyricsPlainController,
                  decoration: InputDecoration(labelText: 'Обычный текст песни'),
                  maxLines: 3,
                ),
                TextField(
                  controller: lyricsSyncedController,
                  decoration: InputDecoration(labelText: 'Синхронизированный текст'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                String newTitle = titleController.text.trim();
                String newArtistsStr = artistsController.text.trim();
                if (newTitle.isEmpty || newArtistsStr.isEmpty) {
                  // Название и исполнители обязательны
                  return;
                }
                List<String> newArtists = newArtistsStr.split(',').map((e) => e.trim()).toList();
                Navigator.pop(ctx, {
                  'title': newTitle,
                  'artists': newArtists,
                  'album': albumController.text.trim(),
                  'lyricsPlain': lyricsPlainController.text,
                  'lyricsSynced': lyricsSyncedController.text,
                });
              },
              child: Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      // Обновляем данные трека
      song.title = result['title'];
      song.artists = result['artists'];
      song.album = result['album'];
      song.lyricsPlain = result['lyricsPlain'];
      song.lyricsSynced = result['lyricsSynced'];
      await song.save();
      _loadMusicList(); // обновляем список
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refreshMusicList,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: _updateSearch,
                decoration: InputDecoration(
                  labelText: 'Поиск по названию трека',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ListView.builder(
                  itemCount: _filteredMusic.length,
                  itemBuilder: (context, index) {
                    Music song = _filteredMusic[index];
                    return Dismissible(
                      key: Key(song.id),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        // Добавляем в очередь
                        final player = Provider.of<PlayerProvider>(context, listen: false);
                        if (player.queue.isEmpty) {
                          // Если очередь пуста, просто ставим эту песню и сразу play
                          await player.setQueue([song]);
                        } else {
                          // Если есть очередь, добавляем в конец
                          player.addToQueue(song);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Трек "${song.title}" добавлен в очередь.'))
                        );
                        return false; // возвращаем false, чтобы не удалять элемент из списка
                      },
                      background: Container(color: Colors.green, child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.queue))),
                      secondaryBackground: Container(color: Colors.blue, child: Align(alignment: Alignment.centerRight, child: Icon(Icons.queue))),
                      child: GestureDetector(
                        onLongPress: () {
                          _showEditMetadataDialog(song);
                        },
                        child: ListTile(
                          leading: Icon(Icons.music_note),
                          title: Text(song.title),
                          subtitle: Text(song.artists.join(', ')),
                          onTap: () {
                            final player = Provider.of<PlayerProvider>(context, listen: false);
                            player.setQueue(_filteredMusic, startIndex: index);
                          },
                        ),
                      ),
                    );
                  },
                )

              ),
            ),
          ],
        ),
      ),
    );
  }
}
