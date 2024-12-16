import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppBarC extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSettingsTap;
  const AppBarC({
    super.key,
    required this.onSettingsTap,
  });


  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: const [
          Icon(CupertinoIcons.music_note_2),
          SizedBox(width: 10),
          Text('FreedomMusic'),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            onSettingsTap();
          },
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // Обработчик нажатия кнопки поиска
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
