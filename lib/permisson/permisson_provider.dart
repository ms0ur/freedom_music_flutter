import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionProvider extends ChangeNotifier {
  bool _storagePermissionGranted = false;
  bool _notificationPermissionGranted = false;

  bool get storagePermissionGranted => _storagePermissionGranted;

  bool get notificationPermissionGranted => _notificationPermissionGranted;

  Future<void> requestStoragePermission() async {
    var status = await Permission.storage.status;
    var status1 = await Permission.audio.status;
    if (!status.isGranted && !status1.isGranted) {
      status = await Permission.storage.request();
      status1 = await Permission.audio.request();
    }
    _storagePermissionGranted = status.isGranted || status1.isGranted;
    notifyListeners();

    var status2 = await Permission.manageExternalStorage.status;
    if (!status2.isGranted) {
      status2 = await Permission.manageExternalStorage.request();
    }
    _storagePermissionGranted = status.isGranted || (status1.isGranted && status2.isGranted);
    notifyListeners();
  }

  Future<void> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }
    _notificationPermissionGranted = status.isGranted;
    notifyListeners();
  }
}
