import 'package:provider/provider.dart';
import '../pages/player_page.dart';
import '../player/player_provider.dart';
import 'package:flutter/material.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  void _showFullPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlayerPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    if (player.currentTrack == null) {
      return SizedBox.shrink();
    }

    final track = player.currentTrack!;
    final cover = player.currentCover;
    final totalSeconds = player.duration.inSeconds;
    final currentSeconds = player.position.inSeconds.clamp(0, totalSeconds > 0 ? totalSeconds : 1);

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < 0) {
          _showFullPlayer(context);
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < 0) {
            player.next();
          } else if (details.primaryVelocity! > 0) {
            player.previous();
          }
        }
      },
      child: Container(
        color: Colors.grey[900],
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            cover != null
                ? Image.memory(cover, width: 60, height: 60, fit: BoxFit.cover)
                : Icon(Icons.music_note, color: Colors.white, size: 60),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: TextStyle(color: Colors.white)),
                  Text(track.artists.join(', '), style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Slider(
                    value: currentSeconds.toDouble(),
                    min: 0,
                    max: totalSeconds.toDouble() > 0 ? totalSeconds.toDouble() : 1.0,
                    onChanged: (value) {
                      player.seek(Duration(seconds: value.toInt()));
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                  )
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.replay_10, color: Colors.white),
              onPressed: player.skipBackward10s,
            ),
            IconButton(
              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
              onPressed: () {
                if (player.isPlaying) {
                  player.pause();
                } else {
                  player.play();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.forward_10, color: Colors.white),
              onPressed: player.skipForward10s,
            ),
          ],
        ),
      ),
    );
  }
}
