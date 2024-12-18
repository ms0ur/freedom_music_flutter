import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import '../models/history.dart';
import '../models/music.dart';
import 'package:audiotags/audiotags.dart';
import 'dart:typed_data';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<Music> _queue = [];
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _shuffle = false;
  bool _repeat = false;

  Uint8List? _currentCover;

  List<Music> get queue => _queue;
  Music? get currentTrack => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  Uint8List? get currentCover => _currentCover;

  bool get isShuffle => _shuffle;
  bool get isRepeat => _repeat;

  PlayerProvider() {
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;

      _isPlaying = playing && processingState != ProcessingState.completed;
      notifyListeners();

      if (processingState == ProcessingState.completed) {
        if (_repeat && currentTrack != null) {
          // Повтор трека
          seek(Duration.zero);
          play();
        } else {
          _nextTrack();
        }
      }
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
      }
      notifyListeners();
    });
  }

  Future<void> setQueue(List<Music> tracks, {int startIndex = 0}) async {
    _queue = tracks;
    _currentIndex = startIndex;
    await _loadCurrentTrack();
  }

  void addToQueue(Music track) {
    _queue.add(track);
    notifyListeners();
  }

  Future<void> _loadCurrentTrack() async {
    if (currentTrack == null) {
      _currentCover = null;
      return;
    }

    try {
      await _player.setFilePath(currentTrack!.location);
      _player.play();
      _addToHistory(currentTrack!);

      // Загрузим обложку
      final tags = await AudioTags.read(currentTrack!.location);
      if (tags?.pictures.isNotEmpty == true) {
        _currentCover = tags!.pictures.first.bytes;
      } else if (tags?.pictures.single.bytes != null) {
        _currentCover = tags!.pictures.single.bytes;
      } else {
        _currentCover = null;
      }

      notifyListeners();
    } catch (e) {
      print('Ошибка при воспроизведении: $e');
    }
  }

  Future<void> play() async {
    if (currentTrack == null && _queue.isNotEmpty) {
      _currentIndex = 0;
      await _loadCurrentTrack();
    } else {
      await _player.play();
      if (currentTrack != null) _addToHistory(currentTrack!);
    }
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _queue.clear();
    _currentIndex = 0;
    _position = Duration.zero;
    _duration = Duration.zero;
    _currentCover = null;
    notifyListeners();
  }

  Future<void> next() async {
    await _nextTrack();
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _loadCurrentTrack();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    if (currentTrack != null) _addToHistory(currentTrack!);
  }

  Future<void> _nextTrack() async {
    if (_repeat && currentTrack != null) {
      // Повтор трека
      seek(Duration.zero);
      play();
    } else {
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        await _loadCurrentTrack();
      } else {
        await stop();
      }
    }
  }

  void _addToHistory(Music song) {
    final historyBox = Hive.box<History>('history');
    final entry = History()
      ..songId = song.id
      ..timePlayed = DateTime.now().toIso8601String();
    historyBox.add(entry);
  }

  Future<void> skipForward10s() async {
    final newPos = _position + Duration(seconds: 10);
    await seek(newPos < _duration ? newPos : _duration);
  }

  Future<void> skipBackward10s() async {
    final newPos = _position - Duration(seconds: 10);
    await seek(newPos > Duration.zero ? newPos : Duration.zero);
  }

  void shuffleQueue() {
    if (_queue.isEmpty) return;

    _shuffle = !_shuffle;
    if (_shuffle) {
      // Перемешиваем очередь, оставляя текущий трек
      final current = currentTrack;
      if (current == null) return;
      _queue.removeAt(_currentIndex);
      _queue.shuffle();
      _queue.insert(0, current);
      _currentIndex = 0;
    } else {
      // Если выключаем shuffle, можно перезагрузить очередь из базы или оставить как есть.
      // Для простоты оставим как есть.
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _repeat = !_repeat;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
