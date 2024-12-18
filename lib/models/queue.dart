import 'package:hive/hive.dart';

part 'queue.g.dart';

@HiveType(typeId: 1)
class Queue extends HiveObject {
  @HiveField(0)
  late Map<String, dynamic> currentSong;

  @HiveField(1)
  late List<String> queue;
}