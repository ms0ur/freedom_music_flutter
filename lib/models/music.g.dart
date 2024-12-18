// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MusicAdapter extends TypeAdapter<Music> {
  @override
  final int typeId = 0;

  @override
  Music read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Music()
      ..id = fields[0] as String
      ..title = fields[1] as String
      ..artists = (fields[2] as List).cast<String>()
      ..album = fields[3] as String
      ..location = fields[4] as String
      ..lyricsSynced = fields[5] as String
      ..lyricsPlain = fields[6] as String
      ..fileHash = fields[7] as String;
  }

  @override
  void write(BinaryWriter writer, Music obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artists)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.lyricsSynced)
      ..writeByte(6)
      ..write(obj.lyricsPlain)
      ..writeByte(7)
      ..write(obj.fileHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
