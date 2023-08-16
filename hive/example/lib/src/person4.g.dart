// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person4.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class Person4Adapter extends TypeAdapter<Person4> {
  @override
  final int typeId = 979999950;

  @override
  Person4 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Person4(
      name: fields[0] as String,
      age: fields[1] as int,
      friends: (fields[2] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Person4 obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.friends);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person4Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
