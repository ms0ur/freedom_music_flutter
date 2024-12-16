import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.music_albums), label: 'Library'),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.music_albums), label: 'Playlists'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Artists'),
        BottomNavigationBarItem(icon: Icon(Icons.library_music_outlined), label: 'Albums'),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: 'Profile'),
      ],
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.white60,
      selectedItemColor: Colors.white,
    );
  }
}
