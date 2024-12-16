import 'package:flutter/material.dart';
import 'dart:math';

class SongTile extends StatelessWidget {
  final String title;
  final String artist;
  final String album;
  final String duration;
  final String cover;
  final bool isContainLyrics;
  final bool isPlaying;

  const SongTile({
    super.key,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.cover,
    required this.isContainLyrics,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          // Обложка песни с анимацией
          Stack(
            alignment: Alignment.center,
            children: [
              // Обложка
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  cover,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              // Анимированные столбики
              if (isPlaying)
                Positioned.fill(
                  child: AnimatedBars(),
                ),
            ],
          ),
          const SizedBox(width: 16.0),
          // Основная информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: isPlaying ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.inverseSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4.0),
                Text(
                  artist,
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
          // Длительность и дополнительные иконки
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                duration,
                style: TextStyle(
                  fontSize: 12.0,
                  color: Theme.of(context).colorScheme.inverseSurface,
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Иконка для текста песни
                  if (isContainLyrics)
                    Icon(
                      Icons.lyrics,
                      color: Theme.of(context).colorScheme.inverseSurface,
                      size: 16.0,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Анимированные столбики
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
