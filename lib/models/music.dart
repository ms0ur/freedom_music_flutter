import 'package:hive/hive.dart';

part 'music.g.dart';

@HiveType(typeId: 0)
class Music extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late List<String> artists;

  @HiveField(3)
  late String album;

  @HiveField(4)
  late String location;

  @HiveField(5)
  late String lyricsSynced;

  @HiveField(6)
  late String lyricsPlain;

  @HiveField(7)
  late String fileHash;

}