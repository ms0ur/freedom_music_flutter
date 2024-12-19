import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../player/player_provider.dart';
import '../models/music.dart';
import '../models/history.dart';
import 'package:hive/hive.dart';

class _LyricLine {
  Duration time;
  String text;
  bool isCurrent;
  _LyricLine({required this.time, required this.text, this.isCurrent=false});
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({Key? key}) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _showLyrics = false;
  List<_LyricLine> syncedLyrics = [];
  ScrollController lyricsScrollController = ScrollController();
  final double lineHeight = 50.0;

  PlayerProvider? _player;
  Music? _lastTrack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _player = Provider.of<PlayerProvider>(context, listen: false);
      _loadForTrack(_player!.currentTrack);
      _player!.addListener(_onPlayerChanged);
    });
  }

  void _onPlayerChanged() {
    if (!mounted || _player == null) return;
    final current = _player!.currentTrack;
    if (current == null) {
      Navigator.pop(context);
      return;
    }

    // При смене трека закрываем текст, чтобы он принудительно обновился
    _showLyrics = false;
    _loadForTrack(current);
    setState(() {});
  }

  void _loadForTrack(Music? track) {
    _lastTrack = track;
    syncedLyrics.clear();
    if (track != null && track.lyricsSynced.isNotEmpty) {
      syncedLyrics = _parseSyncedLyrics(track.lyricsSynced);
    }
    lyricsScrollController.jumpTo(0);
    setState(() {});
  }

  @override
  void dispose() {
    if (_player != null) {
      _player!.removeListener(_onPlayerChanged);
    }
    lyricsScrollController.dispose();
    super.dispose();
  }

  List<_LyricLine> _parseSyncedLyrics(String text) {
    final lines = text.split('\n');
    final result = <_LyricLine>[];
    final reg = RegExp(r'\[(\d{2}):(\d{2}\.\d{2})\]\s*(.*)');
    for (var line in lines) {
      final match = reg.firstMatch(line);
      if (match != null) {
        int mm = int.parse(match.group(1)!);
        double ss = double.parse(match.group(2)!);
        final seconds = mm * 60 + ss;
        final content = match.group(3)!;
        result.add(_LyricLine(
            time: Duration(milliseconds: (seconds * 1000).toInt()),
            text: content
        ));
      } else {
        result.add(_LyricLine(time: Duration.zero, text: line));
      }
    }
    return result;
  }

  void _updateHighlight() {
    if (!mounted || _player == null || syncedLyrics.isEmpty) return;
    Duration pos = _player!.position;
    int currentIndex = 0;
    for (int i = 0; i < syncedLyrics.length; i++) {
      if (pos >= syncedLyrics[i].time) {
        currentIndex = i;
      } else {
        break;
      }
    }
    bool changed = false;
    for (int i = 0; i < syncedLyrics.length; i++) {
      bool shouldBeCurrent = (i == currentIndex);
      if (syncedLyrics[i].isCurrent != shouldBeCurrent) {
        syncedLyrics[i].isCurrent = shouldBeCurrent;
        changed = true;
      }
    }
    if (changed) {
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!lyricsScrollController.hasClients) return;
      final viewportHeight = lyricsScrollController.position.viewportDimension;
      double targetOffset = (currentIndex * lineHeight) - (viewportHeight / 2) + (lineHeight / 2);
      final maxScroll = lyricsScrollController.position.maxScrollExtent;
      if (targetOffset > maxScroll) targetOffset = maxScroll;
      if (targetOffset < 0) targetOffset = 0;
      lyricsScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _toggleLyrics() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  void _showHistory() async {
    final historyBox = Hive.box<History>('history');
    final histories = historyBox.values.toList().cast<History>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            itemCount: histories.length,
            itemBuilder: (context, index) {
              final h = histories[index];
              return ListTile(
                title: Text('Song ID: ${h.songId}'),
                subtitle: Text('Played at: ${h.timePlayed}'),
              );
            },
          ),
        );
      },
    );
  }

  void _showQueue() {
    if (_player == null) return;
    final q = _player!.queue;
    final currentIdx = _player!.currentIndex;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            itemCount: q.length,
            itemBuilder: (context, index) {
              final song = q[index];
              return ListTile(
                leading: Icon(index == currentIdx ? Icons.play_arrow : Icons.music_note),
                title: Text(song.title),
                subtitle: Text(song.artists.join(', ')),
              );
            },
          ),
        );
      },
    );
  }

  void _onTapLyricsArea(TapDownDetails details) {
    if (!_showLyrics) return;
    final dy = details.localPosition.dy;
    final actualIndex = ((dy + lyricsScrollController.offset) / lineHeight).floor();
    if (syncedLyrics.isEmpty || actualIndex < 0 || actualIndex >= syncedLyrics.length) {
      _toggleLyrics();
    } else {
      final line = syncedLyrics[actualIndex];
      if (_player != null && line.time <= _player!.duration) {
        _player!.seek(line.time);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final track = player.currentTrack;
    if (track == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return SizedBox.shrink();
    }

    final bgColor = Theme.of(context).colorScheme.surface;
    final onBgColor = Theme.of(context).colorScheme.inverseSurface;

    _updateHighlight();

    Uint8List? cover = player.currentCover;

    return SafeArea(
      minimum: EdgeInsets.only(top: 40),
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 10) {
            Navigator.pop(context);
          }
        },
        onTapDown: _onTapLyricsArea,
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            title: Text(track.title, style: TextStyle(color: onBgColor)),
            iconTheme: IconThemeData(color: onBgColor),
            actions: [
              IconButton(
                icon: Icon(Icons.text_fields, color: onBgColor),
                onPressed: _toggleLyrics,
              ),
              IconButton(
                icon: Icon(Icons.history, color: onBgColor),
                onPressed: _showHistory,
              ),
              IconButton(
                icon: Icon(Icons.queue_music, color: onBgColor),
                onPressed: _showQueue,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: cover != null
                          ? Image.memory(cover, fit: BoxFit.cover)
                          : Icon(Icons.music_note, size: 200, color: Colors.grey),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ Theme.of(context).colorScheme.surface.withAlpha(50), Theme.of(context).colorScheme.surface ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      key: ValueKey('${track.id}-${_showLyrics ? "lyrics" : "cover"}'),
                      duration: Duration(milliseconds: 300),
                      child: _showLyrics
                          ? _buildLyricsView(player, track, onBgColor)
                          : _buildCoverText(track, onBgColor),
                    ),
                  ],
                ),
              ),
              _buildControlPanel(player, onBgColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverText(Music track, Color onBgColor) {
    return Container(
      key: ValueKey('cover-${track.id}'),
      alignment: Alignment.center,
      child: Text(
        '${track.title}\n${track.artists.join(', ')}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLyricsView(PlayerProvider player, Music track, Color onBgColor) {
    if (syncedLyrics.isNotEmpty) {
      return Container(
        key: ValueKey('lyrics-${track.id}'),
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: ListView.builder(
          controller: lyricsScrollController,
          physics: ClampingScrollPhysics(),
          itemCount: syncedLyrics.length,
          itemBuilder: (context, index) {
            final line = syncedLyrics[index];
            return Container(
              height: lineHeight,
              alignment: Alignment.center,
              child: Text(
                line.text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: line.isCurrent ? 20 : 16,
                  fontWeight: line.isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      );
    } else if (track.lyricsPlain.isNotEmpty) {
      return Container(
        key: ValueKey('plain-${track.id}'),
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              track.lyricsPlain,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      return Container(
        key: ValueKey('none-${track.id}'),
        alignment: Alignment.center,
        child: Text('Нет слов', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
      );
    }
  }

  Widget _buildControlPanel(PlayerProvider player, Color onBgColor) {
    final pos = player.position;
    final dur = player.duration;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(player.isRepeat ? Icons.repeat_on : Icons.repeat, color: onBgColor),
                onPressed: player.toggleRepeat,
              ),
              IconButton(icon: Icon(Icons.skip_previous, color: onBgColor), onPressed: player.previous),
              IconButton(icon: Icon(Icons.replay_10, color: onBgColor), onPressed: player.skipBackward10s),
              IconButton(
                icon: Icon(player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: onBgColor, size: 48),
                onPressed: () {
                  if (player.isPlaying) player.pause(); else player.play();
                },
              ),
              IconButton(icon: Icon(Icons.forward_10, color: onBgColor), onPressed: player.skipForward10s),
              IconButton(icon: Icon(Icons.skip_next, color: onBgColor), onPressed: player.next),
              IconButton(
                icon: Icon(player.isShuffle ? Icons.shuffle_on : Icons.shuffle, color: onBgColor),
                onPressed: player.shuffleQueue,
              ),
            ],
          ),
          Slider(
            value: pos.inSeconds.toDouble(),
            min: 0,
            max: dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1,
            onChanged: (value) {
              player.seek(Duration(seconds: value.toInt()));
            },
            activeColor: onBgColor,
            inactiveColor: onBgColor.withOpacity(0.3),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(pos), style: TextStyle(color: onBgColor)),
              Text(_formatDuration(dur), style: TextStyle(color: onBgColor)),
            ],
          )
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    int mm = d.inMinutes;
    int ss = d.inSeconds % 60;
    return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }
}
