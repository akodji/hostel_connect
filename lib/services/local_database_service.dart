import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:hostel_connect/services/hive_models.dart';

class LocalDatabaseService {
  // Singleton pattern
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  // Hive box names
  static const String _hostelsBoxName = 'hostels';
  static const String _roomsBoxName = 'rooms';
  static const String _favoritesBoxName = 'favorites';
  static const String _bookingsBoxName = 'bookings';
  static const String _syncInfoBoxName = 'sync_info';

  // Hive boxes
  late Box<HostelModel> _hostelsBox;
  late Box<RoomModel> _roomsBox;
  late Box<FavoriteModel> _favoritesBox;
  late Box<BookingModel> _bookingsBox;
  late Box<dynamic> _syncInfoBox;

  // Initialize Hive
  Future<void> initialize() async {
    // Initialize Hive
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    // Register adapters
    Hive.registerAdapter(HostelModelAdapter());
    Hive.registerAdapter(RoomModelAdapter());
    Hive.registerAdapter(FavoriteModelAdapter());
    Hive.registerAdapter(BookingModelAdapter());

    // Open boxes
    _hostelsBox = await Hive.openBox<HostelModel>(_hostelsBoxName);
    _roomsBox = await Hive.openBox<RoomModel>(_roomsBoxName);
    _favoritesBox = await Hive.openBox<FavoriteModel>(_favoritesBoxName);
    _bookingsBox = await Hive.openBox<BookingModel>(_bookingsBoxName);
    _syncInfoBox = await Hive.openBox<dynamic>(_syncInfoBoxName);
  }

  // HOSTEL METHODS

  // Save hostels to local storage
  Future<void> saveHostels(List<HostelModel> hostels) async {
    await _hostelsBox.clear(); // Clear existing hostels
    
    final Map<dynamic, HostelModel> entries = {};
    for (var hostel in hostels) {
      entries[hostel.id] = hostel;
    }
    
    await _hostelsBox.putAll(entries);
    await _updateLastSyncTime();
  }

  Future<void> markBookingAsSynced(int bookingId) async {
  final box = await Hive.openBox<BookingModel>('bookings');
  final booking = box.get(bookingId);
  if (booking != null) {
    booking.syncStatus = 'synced';
    booking.save();
  }
}



Future<List<BookingModel>> getUnsyncedBookings() async {
  final box = await Hive.openBox<BookingModel>('bookings');
  return box.values.where((booking) => booking.syncStatus == 'pending').toList();
}

  // Get all hostels from local storage
  List<HostelModel> getAllHostels() {
    return _hostelsBox.values.toList();
  }

  // Get a hostel by ID
  HostelModel? getHostelById(int id) {
    return _hostelsBox.get(id);
  }

  // Search hostels by name
  List<HostelModel> searchHostels(String query) {
    if (query.isEmpty) return getAllHostels();
    
    final lowercaseQuery = query.toLowerCase();
    return _hostelsBox.values.where((hostel) {
      return hostel.name.toLowerCase().contains(lowercaseQuery) ||
             hostel.location.toLowerCase().contains(lowercaseQuery) ||
             hostel.description.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // ROOM METHODS

  // Save rooms to local storage
  Future<void> saveRooms(List<RoomModel> rooms) async {
    await _roomsBox.clear(); // Clear existing rooms
    
    final Map<dynamic, RoomModel> entries = {};
    for (var room in rooms) {
      entries[room.id] = room;
    }
    
    await _roomsBox.putAll(entries);
  }

  // Get all rooms for a hostel
  List<RoomModel> getRoomsForHostel(int hostelId) {
    return _roomsBox.values
        .where((room) => room.hostelId == hostelId)
        .toList();
  }

  // Get a room by ID
  RoomModel? getRoomById(int id) {
    return _roomsBox.get(id);
  }

  // Get available rooms for a hostel
  List<RoomModel> getAvailableRoomsForHostel(int hostelId) {
    return _roomsBox.values
        .where((room) => room.hostelId == hostelId && room.available)
        .toList();
  }

  // FAVORITE METHODS

  // Save favorites to local storage
  Future<void> saveFavorites(List<FavoriteModel> favorites) async {
    await _favoritesBox.clear(); // Clear existing favorites
    
    final Map<dynamic, FavoriteModel> entries = {};
    for (var favorite in favorites) {
      entries[favorite.id] = favorite;
    }
    
    await _favoritesBox.putAll(entries);
  }

  // Get all favorites for a user
  List<FavoriteModel> getFavoritesForUser(String userId) {
    return _favoritesBox.values
        .where((favorite) => favorite.userId == userId)
        .toList();
  }

  // Add a favorite (offline capable)
  Future<FavoriteModel> addFavorite(String userId, int hostelId) async {
    final uuid = const Uuid().v4();
    final now = DateTime.now();
    
    final favorite = FavoriteModel(
      id: uuid,
      userId: userId,
      hostelId: hostelId,
      createdAt: now,
      pendingSync: true,
    );
    
    await _favoritesBox.put(uuid, favorite);
    return favorite;
  }

  // Remove a favorite
  Future<void> removeFavorite(String favoriteId) async {
    await _favoritesBox.delete(favoriteId);
  }

  // Check if a hostel is favorited by a user
  bool isHostelFavorited(String userId, int hostelId) {
    return _favoritesBox.values.any((favorite) => 
        favorite.userId == userId && favorite.hostelId == hostelId);
  }

  // Get favorite ID if exists
  String? getFavoriteId(String userId, int hostelId) {
    final favorite = _favoritesBox.values.firstWhere(
      (fav) => fav.userId == userId && fav.hostelId == hostelId,
      orElse: () => FavoriteModel(
        id: '', userId: '', hostelId: -1, createdAt: DateTime.now(),
      ),
    );
    return favorite.id.isNotEmpty ? favorite.id : null;
  }

  // Get pending sync favorites
  List<FavoriteModel> getPendingSyncFavorites() {
    return _favoritesBox.values
        .where((favorite) => favorite.pendingSync)
        .toList();
  }

  // Mark favorite as synced
  Future<void> markFavoriteSynced(String favoriteId) async {
    final favorite = _favoritesBox.get(favoriteId);
    if (favorite != null) {
      favorite.pendingSync = false;
      await favorite.save();
    }
  }

  // BOOKING METHODS

  // Save bookings to local storage
  Future<void> saveBookings(List<BookingModel> bookings) async {
    // Don't clear all bookings, as we might have offline bookings
    // Instead, only replace the ones from the server
    
    // First, get all offline bookings
    final offlineBookings = _bookingsBox.values
        .where((booking) => booking.isOfflineBooking)
        .toList();
    
    // Clear box and add all bookings
    await _bookingsBox.clear();
    
    final Map<dynamic, BookingModel> entries = {};
    
    // Add server bookings
    for (var booking in bookings) {
      entries[booking.id] = booking;
    }
    
    // Add back offline bookings
    for (var booking in offlineBookings) {
      entries[booking.id] = booking;
    }
    
    await _bookingsBox.putAll(entries);
  }

  // Get all bookings for a user
  List<BookingModel> getBookingsForUser(String userId) {
    return _bookingsBox.values
        .where((booking) => booking.userId == userId)
        .toList();
  }

  // Get offline bookings for a user
  List<BookingModel> getOfflineBookingsForUser(String userId) {
    return _bookingsBox.values
        .where((booking) => 
            booking.userId == userId && booking.isOfflineBooking)
        .toList();
  }

  // Create an offline booking
  Future<BookingModel> createOfflineBooking({
    required String userId,
    required int hostelId,
    required int roomId,
    required DateTime moveInDate,
    required double price,
    String? notes,
  }) async {
    final booking = BookingModel.createOfflineBooking(
      userId: userId,
      hostelId: hostelId,
      roomId: roomId,
      moveInDate: moveInDate,
      price: price,
      notes: notes,
    );
    
    await _bookingsBox.put(booking.id, booking);
    return booking;
  }

  // Get a booking by ID
  BookingModel? getBookingById(String id) {
    return _bookingsBox.get(id);
  }

  // Delete a booking
  Future<void> deleteBooking(String id) async {
    await _bookingsBox.delete(id);
  }

  // Get pending sync bookings
  List<BookingModel> getPendingSyncBookings() {
    return _bookingsBox.values
        .where((booking) => 
            booking.isOfflineBooking && booking.syncStatus == 'pending')
        .toList();
  }

  // Update booking sync status
  Future<void> updateBookingSyncStatus(String id, String status) async {
    final booking = _bookingsBox.get(id);
    if (booking != null) {
      booking.syncStatus = status;
      await booking.save();
    }
  }

  // Replace offline booking with server booking
  Future<void> replaceOfflineBooking(String offlineId, BookingModel serverBooking) async {
    await _bookingsBox.delete(offlineId);
    await _bookingsBox.put(serverBooking.id, serverBooking);
  }

  // SYNC INFO METHODS

  // Update last sync time
  Future<void> _updateLastSyncTime() async {
    await _syncInfoBox.put('last_sync_time', DateTime.now().toIso8601String());
  }

  // Get last sync time
  DateTime? getLastSyncTime() {
    final lastSyncString = _syncInfoBox.get('last_sync_time');
    return lastSyncString != null ? DateTime.parse(lastSyncString) : null;
  }

  // Close all boxes
  Future<void> closeBoxes() async {
    await _hostelsBox.close();
    await _roomsBox.close();
    await _favoritesBox.close();
    await _bookingsBox.close();
    await _syncInfoBox.close();
  }
}