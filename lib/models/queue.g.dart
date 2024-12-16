// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QueueAdapter extends TypeAdapter<Queue> {
  @override
  final int typeId = 1;

  @override
  Queue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Queue()
      ..currentSong = (fields[0] as Map).cast<String, dynamic>()
      ..queue = (fields[1] as List).cast<String>();
  }

  @override
  void write(BinaryWriter writer, Queue obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.currentSong)
      ..writeByte(1)
      ..write(obj.queue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
