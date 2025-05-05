// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HostelModelAdapter extends TypeAdapter<HostelModel> {
  @override
  final int typeId = 0;

  @override
  HostelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HostelModel(
      id: fields[0] as int,
      name: fields[1] as String,
      description: fields[2] as String,
      address: fields[3] as String,
      campusLocation: fields[4] as String,
      price: fields[5] as int,
      availableRooms: fields[6] as int,
      imageUrl: fields[7] as String?,
      ownerId: fields[8] as String,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      location: fields[11] as String,
      email: fields[12] as String?,
      phone: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HostelModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.campusLocation)
      ..writeByte(5)
      ..write(obj.price)
      ..writeByte(6)
      ..write(obj.availableRooms)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.ownerId)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.location)
      ..writeByte(12)
      ..write(obj.email)
      ..writeByte(13)
      ..write(obj.phone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoomModelAdapter extends TypeAdapter<RoomModel> {
  @override
  final int typeId = 1;

  @override
  RoomModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoomModel(
      id: fields[0] as int,
      hostelId: fields[1] as int,
      name: fields[2] as String,
      roomNumber: fields[3] as int,
      price: fields[4] as double,
      capacity: fields[5] as int,
      description: fields[6] as String?,
      available: fields[7] as bool,
      imageUrl: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RoomModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.hostelId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.roomNumber)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.capacity)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.available)
      ..writeByte(8)
      ..write(obj.imageUrl)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FavoriteModelAdapter extends TypeAdapter<FavoriteModel> {
  @override
  final int typeId = 2;

  @override
  FavoriteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      hostelId: fields[2] as int,
      createdAt: fields[3] as DateTime,
      pendingSync: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.hostelId)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.pendingSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookingModelAdapter extends TypeAdapter<BookingModel> {
  @override
  final int typeId = 3;

  @override
  BookingModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookingModel(
      id: fields[0] as int,
      userId: fields[1] as String,
      hostelId: fields[2] as int,
      roomId: fields[3] as int,
      moveInDate: fields[4] as DateTime,
      status: fields[5] as String,
      notes: fields[6] as String?,
      price: fields[7] as double,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
      syncStatus: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BookingModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.hostelId)
      ..writeByte(3)
      ..write(obj.roomId)
      ..writeByte(4)
      ..write(obj.moveInDate)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.price)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
