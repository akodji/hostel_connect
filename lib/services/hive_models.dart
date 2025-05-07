import 'package:hive/hive.dart';

part 'hive_models.g.dart';

@HiveType(typeId: 0)
class HostelModel extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  String address;

  @HiveField(4)
  String campusLocation;

  @HiveField(5)
  int price;

  @HiveField(6)
  int availableRooms;

  @HiveField(7)
  String? imageUrl;

  @HiveField(8)
  String ownerId;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  String location;

  @HiveField(12)
  String? email;

  @HiveField(13)
  String? phone;

  HostelModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.campusLocation,
    required this.price,
    required this.availableRooms,
    this.imageUrl,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.location,
    this.email,
    this.phone,
  });
}

@HiveType(typeId: 1)
class RoomModel extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int hostelId;

  @HiveField(2)
  String name;

  @HiveField(3)
  int roomNumber;

  @HiveField(4)
  double price;

  @HiveField(5)
  int capacity;

  @HiveField(6)
  String? description;

  @HiveField(7)
  bool available;

  @HiveField(8)
  String? imageUrl;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  RoomModel({
    required this.id,
    required this.hostelId,
    required this.name,
    required this.roomNumber,
    required this.price,
    required this.capacity,
    this.description,
    required this.available,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });
}

@HiveType(typeId: 2)
class FavoriteModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  int hostelId;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  bool synced;

  @HiveField(5)
  bool pendingSync;

   @HiveField(6)
  bool toBeDeleted;

  FavoriteModel({
    required this.id,
    required this.userId,
    required this.hostelId,
    required this.createdAt,
    this.synced = false,           // ✅ Add this
    this.pendingSync = false,
    this.toBeDeleted = false,
    
  });
}


@HiveType(typeId: 3)
class BookingModel extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  int hostelId;

  @HiveField(3)
  int roomId;

  @HiveField(4)
  DateTime moveInDate;

  @HiveField(5)
  String status;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  double price;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  String syncStatus;

  BookingModel({
    required this.id,
    required this.userId,
    required this.hostelId,
    required this.roomId,
    required this.moveInDate,
    required this.status,
    this.notes,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  bool get isOfflineBooking => syncStatus == 'pending';

  factory BookingModel.createOfflineBooking({
    required String userId,
    required int hostelId,
    required int roomId,
    required DateTime moveInDate,
    required double price,
    String? notes,
  }) {
    final now = DateTime.now();
    return BookingModel(
      id: now.millisecondsSinceEpoch,
      userId: userId,
      hostelId: hostelId,
      roomId: roomId,
      moveInDate: moveInDate,
      status: 'pending',
      notes: notes,
      price: price,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
  }
}
