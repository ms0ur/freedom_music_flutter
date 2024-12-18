// settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../models/settings.dart';
import '../theme/theme_provider.dart';
import '../permisson/permisson_provider.dart';
import '../models/history.dart';
import '../models/music.dart';
import '../models/queue.dart';
import 'dart:io';

class SettingsPage extends StatefulWidget {
  final VoidCallback onReturn;

  const SettingsPage({super.key, required this.onReturn});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool onlineFeatures = false;
  String lastfmKey = '';

  @override
  void initState() {
    super.initState();
    final settingsBox = Hive.box<Settings>('settings');
    if (settingsBox.isNotEmpty) {
      final s = settingsBox.values.first;
      onlineFeatures = s.setting['onlineFeatures'] ?? false;
      lastfmKey = s.setting['lastfmApiKey'] ?? '';
    }
  }

  void _saveSettings() {
    final settingsBox = Hive.box<Settings>('settings');
    if (settingsBox.isNotEmpty) {
      final s = settingsBox.values.first;
      s.setting['onlineFeatures'] = onlineFeatures;
      s.setting['lastfmApiKey'] = lastfmKey;
      settingsBox.putAt(0, s);
    } else {
      final s = Settings();
      s.setting['onlineFeatures'] = onlineFeatures;
      s.setting['lastfmApiKey'] = lastfmKey;
      try {
        settingsBox.add(s);
      } catch (e) {
        print(e);
    }
    }
  }

  void _dropDatabase() async {
    Box<Music> box1 = Hive.box<Music>('music');
    await box1.clear();

    Box<History> box2 = Hive.box<History>('history');
    await box2.clear();

    Box<Queue> box3 = Hive.box<Queue>('queue');
    await box3.clear();
  }

  void _deleteTracks() {
    final dir = Directory('storage/emulated/0/FreedomMusic');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          automaticallyImplyLeading: true,
        ),
        body: SingleChildScrollView(
          child: Center(
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
                          : const Text('Granted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),),
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
                        : const Text('Granted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),),
                  ],
                ),
                const SizedBox(height: 20,),
                const Text('Online features', style: TextStyle(fontSize: 24),),
                Row(
                  children: [
                    SizedBox(width: 20,),
                    const Text('Enable online features'),
                    SizedBox(width: 10,),
                    Switch(
                      value: onlineFeatures,
                      onChanged: (val) {
                        setState(() {
                          onlineFeatures = val;
                        });
                        _saveSettings();
                      },
                    ),
                  ],
                ),
                if (onlineFeatures) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal:20, vertical:10),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'LastFM API Key',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        lastfmKey = val;
                        _saveSettings();
                      },
                      controller: TextEditingController(text: lastfmKey),
                    ),
                  ),
                ],
                const SizedBox(height: 20,),
                const Text('Database', style: TextStyle(fontSize: 24),),
                Row(
                    children: [
                      SizedBox(width: 20,),
                      const Text('Clear ALL data'),
                      SizedBox(width: 10,),
                      ElevatedButton(
                          onPressed: () {
                            _dropDatabase();
                            _deleteTracks();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            shadowColor: Theme.of(context).colorScheme.inverseSurface,
                          ),
                          child: Text('Clear')
                      ),
                    ]
                ),
              ],
            ),
          ),
        )
    );
  }
}
