import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 3)
class Settings {
  @HiveField(0)
  late Map<String, dynamic> setting;

}