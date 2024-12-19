// import_music.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:audiotags/audiotags.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import '../models/music.dart';
import '../models/settings.dart';
import 'package:http/http.dart' as http;
import '../permisson/permisson_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

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
      type: FileType.audio,
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

      String path = file.path!;
      String extension = p.extension(path);


      File mp3File = File(path);



      final Tag? tag = await AudioTags.read(mp3File.path);

      if (tag == null) {
        throw Exception('Error reading metadata');
      }


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

      if (tag == null) {
        setState(() {
          _statusMessage = 'Ошибка чтения метаданных';
        });
        continue;
      }

      // Извлекаем встроенную обложку, если есть
      Uint8List? embeddedCover = tag!.pictures.isNotEmpty ? tag.pictures.first.bytes : null;

      Map<String, dynamic>? editedData = await _showEditDialog(
        context,
        title: title,
        artists: artistsList,
        album: album,
        embeddedCover: embeddedCover,
        trackArtist: artist,
      );

      if (editedData == null) {
        continue;
      }

      String finalTitle = editedData['title'];
      List<String> finalArtists = editedData['artists'];
      String finalAlbum = editedData['album'];
      Uint8List? finalCoverBytes = editedData['coverBytes']; // конечная обложка

      String artistFileName = finalArtists.join('_');
      String newFileName = '$artistFileName -- $finalTitle.$extension';

      try {
        String newPath = 'storage/emulated/0/FreedomMusic/$newFileName';

        Directory('storage/emulated/0/FreedomMusic').createSync(recursive: true);
        File newAudio = await mp3File.copy(newPath);

        String fileHash = await _computeFileHash(newAudio);
        int? durationSec = tag.duration;

        Map<String, dynamic>? lyricsData = await _fetchLyrics(
          artistName: finalArtists.join(' '),
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
          ..location = newPath
          ..lyricsSynced = syncedLyrics
          ..lyricsPlain = plainLyrics
          ..fileHash = fileHash;

        // Можно было бы сохранать обложку в отдельное поле или файл. Для примера пропустим.
        // Если нужно, можно сохранить base64 обложки:
        // music.coverBase64 = finalCoverBytes != null ? base64Encode(finalCoverBytes) : '';

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

  Future<Map<String, dynamic>?> _showEditDialog(
      BuildContext context,
      {required String title,
        required List<String> artists,
        required String album,
        Uint8List? embeddedCover,
        required String trackArtist,
      }) async {

    final settingsBox = Hive.box<Settings>('settings');
    final s = settingsBox.values.first;
    bool onlineFeatures = s.setting['onlineFeatures'] ?? false;
    String lastfmApiKey = s.setting['lastfmApiKey'] ?? '';

    TextEditingController titleController = TextEditingController(text: title);
    TextEditingController artistsController = TextEditingController(text: artists.join('_'));
    TextEditingController albumController = TextEditingController(text: album);
    TextEditingController coverUrlController = TextEditingController();

    bool autoCover = false; // авто получение обложки с LastFM
    Uint8List? coverBytes = embeddedCover; // текущая обложка
    // Если нет встроенной обложки, coverBytes = null

    Future<void> updateCoverPreview() async {
      // Обновляет coverBytes в зависимости от режима
      if (autoCover && onlineFeatures && lastfmApiKey.isNotEmpty) {
        // Авто получить обложку
        final c = await fetchAlbumCover(trackArtist, title, lastfmApiKey);
        if (c != null) {
          // Загрузим картинку как bytes
          final imgResp = await http.get(Uri.parse(c));
          if (imgResp.statusCode == 200) {
            coverBytes = imgResp.bodyBytes;
          }
        } else {
          // Не получилось
          coverBytes = null;
        }
      } else if (!autoCover && coverUrlController.text.isNotEmpty) {
        // Получить обложку по URL
        final url = coverUrlController.text.trim();
        final imgResp = await http.get(Uri.parse(url));
        if (imgResp.statusCode == 200) {
          coverBytes = imgResp.bodyBytes;
        } else {
          coverBytes = null;
        }
      } else if (!autoCover && coverUrlController.text.isEmpty && embeddedCover != null) {
        // Вернуться к исходной, если была
        coverBytes = embeddedCover;
      } else if (!autoCover && coverUrlController.text.isEmpty && embeddedCover == null) {
        // нет обложки
        coverBytes = null;
      }
    }

    return showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setStateDialog) {
            Future<void> refreshPreview() async {
              await updateCoverPreview();
              setStateDialog(() {});
            }

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

                    // Раздел для обложки
                    SizedBox(height: 20),
                    if (onlineFeatures && lastfmApiKey.isNotEmpty)
                      Row(
                        children: [
                          Checkbox(
                            value: autoCover,
                            onChanged: (val) {
                              setStateDialog(() {
                                autoCover = val ?? false;
                              });
                              refreshPreview();
                            },
                          ),
                          Text('Авто получить обложку'),
                        ],
                      ),

                    TextField(
                      controller: coverUrlController,
                      enabled: !autoCover, // если авто включено, поле для url неактивно
                      decoration: InputDecoration(labelText: 'Cover URL'),
                      onChanged: (val) {
                        refreshPreview();
                      },
                    ),

                    SizedBox(height: 20),
                    // Превью обложки
                    if (coverBytes != null)
                      Stack(
                        children: [
                          Image.memory(coverBytes!, height: 200),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  coverBytes = null;
                                  coverUrlController.clear();
                                  autoCover = false;
                                });
                              },
                              child: Container(
                                color: Colors.black54,
                                child: Icon(Icons.close, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      )
                    else
                      Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(child: Text('Нет обложки')),
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
                    String finalArtistsStr = artistsController.text.trim();
                    if (finalTitle.isEmpty || finalArtistsStr.isEmpty) {
                      return;
                    }
                    List<String> finalArtistsList = finalArtistsStr.split('_').map((e) => e.trim()).toList();

                    Navigator.pop(ctx, {
                      'title': finalTitle,
                      'artists': finalArtistsList,
                      'album': albumController.text.trim(),
                      'coverBytes': coverBytes
                    });
                  },
                  child: Text('Сохранить'),
                ),
              ],
            );
          });
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

  // Функция получения обложки из LastFM
  Future<String?> fetchAlbumCover(String artist, String track, String apiKey) async {
    final trackInfoUrl =
        'http://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=$apiKey&artist=${Uri.encodeComponent(artist)}&track=${Uri.encodeComponent(track)}&format=json';

    final trackResponse = await http.get(Uri.parse(trackInfoUrl));
    if (trackResponse.statusCode == 200) {
      final trackData = json.decode(trackResponse.body);
      if (trackData['track'] == null || trackData['track']['album'] == null) {
        return null;
      }
      final albumName = trackData['track']['album']['title'];

      final albumInfoUrl =
          'http://ws.audioscrobbler.com/2.0/?method=album.getInfo&api_key=$apiKey&artist=${Uri.encodeComponent(artist)}&album=${Uri.encodeComponent(albumName)}&format=json';

      final albumResponse = await http.get(Uri.parse(albumInfoUrl));
      if (albumResponse.statusCode == 200) {
        final albumData = json.decode(albumResponse.body);
        final images = albumData['album']['image'];
        if (images != null && images is List && images.isNotEmpty) {
          final imageUrl = images.last['#text'];
          return imageUrl.isNotEmpty ? imageUrl : null;
        }
      }
    }
    return null;
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
