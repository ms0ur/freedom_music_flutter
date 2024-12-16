import 'package:hive/hive.dart';

part 'history.g.dart';

@HiveType(typeId: 2)
class History extends HiveObject {
  @HiveField(0)
  String songId;

  @HiveField(1)
  String timePlayed;
}