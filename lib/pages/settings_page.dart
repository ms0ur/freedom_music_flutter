

import 'package:flutter/material.dart';
import 'package:freedom_music_dart/theme/theme_provider.dart';
import 'package:provider/provider.dart';

import '../permisson/permisson_provider.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onReturn;


  const SettingsPage({super.key, required this.onReturn});




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: true, // Включает стрелку назад
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text('Styling', style: TextStyle(fontSize: 24),),
            Row(
              children: [
                SizedBox(width: 10,),
                const Text('Dark mode', style: TextStyle(fontSize: 20),),
                SizedBox(width: 10,),
                Switch(
                  value: Provider.of<ThemeProvider>(context).isDarkMode,
                  onChanged: (value) {
                    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                    themeProvider.toggleTheme();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20,),
            const Text('Permissions', style: TextStyle(fontSize: 24),),
            Row(
              children: [
                SizedBox(width: 20,),
                const Text('Storage'),
                SizedBox(width: 10,),
                !Provider.of<PermissionProvider>(context, listen: true).storagePermissionGranted
                    ? ElevatedButton(
                    onPressed: () {
                      Provider.of<PermissionProvider>(context, listen: false).requestStoragePermission();
                    },
                    child: Text('Request')
                )
                    : const Text('Granted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),), // or any other widget you want to display when the permission is granted
              ]
            ),
            Row(
              children: [
                SizedBox(width: 20,),
                const Text('Notifications'),
                SizedBox(width: 10,),
                !Provider.of<PermissionProvider>(context, listen: true).notificationPermissionGranted
                    ? ElevatedButton(
                    onPressed: () {
                      Provider.of<PermissionProvider>(context, listen: false).requestNotificationPermission();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shadowColor: Theme.of(context).colorScheme.inverseSurface,
                    ),
                    child: Text('Request')
                )
                    : const Text('Granted'), // or any other widget you want to display when the permission is granted
              ],
            ),
          ],
        ),

      )
    );
  }
}
