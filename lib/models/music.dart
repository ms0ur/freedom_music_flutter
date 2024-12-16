import 'package:hive/hive.dart';

part 'music.g.dart';

@HiveType(typeId: 0)
class Music extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  List<String> artists;

  @HiveField(3)
  String album;

  @HiveField(4)
  String location;

  @HiveField(5)
  String lyrics;

}