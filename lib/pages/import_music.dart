import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audiotags/audiotags.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import '../models/music.dart';
import 'package:http/http.dart' as http;
import '../permisson/permisson_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';

class MusicImportPage extends StatefulWidget {
  final VoidCallback onReturn;
  const MusicImportPage({super.key, required this.onReturn});

  @override
  State<MusicImportPage> createState() => _MusicImportState();
}

class _MusicImportState extends State<MusicImportPage> {
  bool _isImporting = false;
  String? _statusMessage;

  Future<void> _pickAndImport() async {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
    if (!permissionProvider.storagePermissionGranted) {
      await permissionProvider.requestStoragePermission();
      if (!permissionProvider.storagePermissionGranted) {
        setState(() {
          _statusMessage = 'Нет доступа к хранилищу!';
        });
        return;
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isImporting = true;
      _statusMessage = 'Импортируем...';
    });

    for (var file in result.files) {
      if (file.path == null) continue;

      File mp3File = File(file.path!);
      final tag = await AudioTags.read(mp3File.path);

      String? title = tag?.title?.trim();
      String? artist = tag?.trackArtist?.trim();
      String? album = tag?.album?.trim();

      if (title == null || title.isEmpty || artist == null || artist.isEmpty) {
        String fileName = p.basenameWithoutExtension(mp3File.path);
        fileName = _removeUrls(fileName);
        List<String> parts = fileName.split('-');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join('-').trim();
        } else {
          artist = artist ?? '';
          title = title ?? fileName;
        }
      }

      album = album ?? '';
      List<String> artistsList = artist!.split(' and ').map((e) => e.trim()).toList();

      Map<String, dynamic>? editedData = await _showEditDialog(
        context,
        title: title!,
        artists: artistsList,
        album: album,
      );

      if (editedData == null) {
        continue;
      }

      String finalTitle = editedData['title'];
      List<String> finalArtists = editedData['artists'];
      String finalAlbum = editedData['album'];

      String artistFileName = finalArtists.join('_');
      String newFileName = '$artistFileName-$finalTitle.mp3';

      final mediaStorePlugin = MediaStore();

      try {
        final tempFilePath = mp3File.path;
        await MediaStore.ensureInitialized();
        MediaStore.appFolder = "FreedomMusic";

        final saveInfo = await mediaStorePlugin.saveFile(
          tempFilePath: tempFilePath,
          dirType: DirType.audio,
          dirName: DirName.music,
        );

        if (saveInfo == null) {
          setState(() {
            _statusMessage = 'Ошибка сохранения файла $newFileName';
          });
          continue;
        }

        final savedFile = File(saveInfo.uri.toFilePath());
        final renamedFile = savedFile.renameSync(p.join(savedFile.parent.path, newFileName));

        String fileHash = await _computeFileHash(savedFile);
        int? durationSec = tag?.duration;

        Map<String, dynamic>? lyricsData = await _fetchLyrics(
          artistName: finalArtists.join(' and '),
          trackName: finalTitle,
          albumName: finalAlbum,
          duration: durationSec,
        );

        String plainLyrics = lyricsData?['plainLyrics'] ?? '';
        String syncedLyrics = lyricsData?['syncedLyrics'] ?? '';

        Box<Music> musicBox = Hive.box<Music>('music');
        Music music = Music()
          ..id = fileHash
          ..title = finalTitle
          ..artists = finalArtists
          ..album = finalAlbum
          ..location = renamedFile.path
          ..lyricsSynced = syncedLyrics
          ..lyricsPlain = plainLyrics
          ..fileHash = fileHash;

        await musicBox.add(music);
      } catch (e) {
        setState(() {
          _statusMessage = 'Ошибка: $e';
        });
      }
    }

    setState(() {
      _isImporting = false;
      _statusMessage = 'Импорт завершен!';
    });
  }

  String _removeUrls(String input) {
    return input.replaceAll(RegExp(r'https?:\/\/\S+'), '').replaceAll(RegExp(r'\.ru|\.net|\.com'), '').trim();
  }

  Future<Map<String, dynamic>?> _showEditDialog(BuildContext context, {required String title, required List<String> artists, required String album}) async {
    TextEditingController titleController = TextEditingController(text: title);
    TextEditingController artistsController = TextEditingController(text: artists.join('_'));
    TextEditingController albumController = TextEditingController(text: album);

    return showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Редактирование метаданных'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'Название *'),
                  ),
                  TextField(
                    controller: artistsController,
                    decoration: InputDecoration(labelText: 'Исполнители (через нижнее подчеркивание) *'),
                  ),
                  TextField(
                    controller: albumController,
                    decoration: InputDecoration(labelText: 'Альбом'),
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
                  String finalTitle = titleController.text.trim();
                  String finalArtists = artistsController.text.trim();
                  if (finalTitle.isEmpty || finalArtists.isEmpty) {
                    return;
                  }
                  List<String> finalArtistsList = finalArtists.split('_').map((e) => e.trim()).toList();
                  Navigator.pop(ctx, {
                    'title': finalTitle,
                    'artists': finalArtistsList,
                    'album': albumController.text.trim(),
                  });
                },
                child: Text('Сохранить'),
              ),
            ],
          );
        });
  }

  Future<String> _computeFileHash(File file) async {
    List<int> bytes = await file.readAsBytes();
    var digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> _fetchLyrics({required String artistName, required String trackName, required String albumName, int? duration}) async {
    Uri uri = Uri.https('lrclib.net', '/api/get', {
      'artist_name': artistName,
      'track_name': trackName,
      'album_name': albumName,
      if (duration != null) 'duration': duration.toString(),
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'plainLyrics': data['plainLyrics'] ?? '',
        'syncedLyrics': data['syncedLyrics'] ?? '',
      };
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: _isImporting
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickAndImport,
              child: Text('Выбрать и импортировать MP3'),
            ),
            if (_statusMessage != null) ...[
              SizedBox(height: 20),
              Text(_statusMessage!),
            ]
          ],
        ),
      ),
    );
  }
}
