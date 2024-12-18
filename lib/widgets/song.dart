import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:audiotags/audiotags.dart';

import '../models/music.dart'; // For metadata extraction

class SongTile extends StatelessWidget {
  final String id;
  final bool isPlaying;

  const SongTile({
    super.key,
    required this.id,
    required this.isPlaying,
  });

  Future<Map<String, dynamic>> _getTrackInfo(String id) async {
    final box = Hive.box<Music>('music');
    Music? music = await box.get(id);
    if (music != null) {
      final tags = await AudioTags.read(music.location);

      Uint8List? coverData = tags!.pictures.isNotEmpty ? tags.pictures.first.bytes : null;

      return {
        'title': music.title,
        'artist': music.artists.join(', '),
        'album': music.album,
        'duration': tags?.duration.toString() ?? '',
        'cover': coverData,
        'isContainLyrics': music.lyricsSynced != '',
        'location': music.location,
      };
    }

    return {
      'title': '',
      'artist': '',
      'album': '',
      'duration': '',
      'cover': '',
      'isContainLyrics': false,
      'location': '',
    };

  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getTrackInfo(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final trackInfo = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            children: [
              // Cover image with fallback
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: trackInfo['cover'] != null
                        ? Image.memory(trackInfo['cover'], height: 60, width: 60, fit: BoxFit.cover)
                        : Icon(Icons.music_note, size: 60),
                  ),
                  if (isPlaying)
                    const Positioned.fill(
                      child: AnimatedBars(),
                    ),
                ],
              ),
              const SizedBox(width: 16.0),
              // Track details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trackInfo['title'],
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: isPlaying
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.inverseSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '${trackInfo['artist']} - ${trackInfo['album']}',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Theme.of(context).colorScheme.inverseSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trackInfo['duration'],
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Theme.of(context).colorScheme.inverseSurface,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  if (trackInfo['isContainLyrics'])
                    Icon(
                      Icons.lyrics,
                      color: Theme.of(context).colorScheme.inverseSurface,
                      size: 16.0,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Animated bars for the playing track
class AnimatedBars extends StatefulWidget {
  const AnimatedBars({super.key});

  @override
  State<AnimatedBars> createState() => _AnimatedBarsState();
}

class _AnimatedBarsState extends State<AnimatedBars> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _heights = List.generate(3, (_) => Random().nextDouble());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
            (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Container(
                  width: 4.0,
                  height: 20 + _heights[index] * 30 * _controller.value,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
