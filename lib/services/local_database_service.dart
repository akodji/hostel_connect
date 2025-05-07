import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hostel_connect/services/hive_models.dart';
import 'package:hostel_connect/services/sync_service.dart';

class LocalDatabaseService {
  // Singleton pattern
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  // Box names
  static const String _hostelsBoxName = 'hostels';
  static const String _roomsBoxName = 'rooms';
  static const String _bookingsBoxName = 'bookings';
  static const String _favoritesBoxName = 'favorites';

  // Box references
  late Box<HostelModel> _hostelsBox;
  late Box<RoomModel> _roomsBox;
  late Box<BookingModel> _bookingsBox;
  late Box<FavoriteModel> _favoritesBox;

  // Initialize flag
  bool _isInitialized = false;

  // Initialize Hive
  Future<void> initializeHive() async {
    if (_isInitialized) {
      return;
    }

    try {
      // Initialize Hive
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);

      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HostelModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RoomModelAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(FavoriteModelAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(BookingModelAdapter());
      }

      // Open boxes
      _hostelsBox = await Hive.openBox<HostelModel>(_hostelsBoxName);
      _roomsBox = await Hive.openBox<RoomModel>(_roomsBoxName);
      _bookingsBox = await Hive.openBox<BookingModel>(_bookingsBoxName);
      _favoritesBox = await Hive.openBox<FavoriteModel>(_favoritesBoxName);

      _isInitialized = true;
    } catch (e) {
      print('Error initializing Hive: $e');
      throw Exception('Failed to initialize local database: $e');
    }
  }

  // Ensure boxes are open before operations
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeHive();
    }
    
    // Double check that boxes are actually open
    if (!_hostelsBox.isOpen) {
      _hostelsBox = await Hive.openBox<HostelModel>(_hostelsBoxName);
    }
    if (!_roomsBox.isOpen) {
      _roomsBox = await Hive.openBox<RoomModel>(_roomsBoxName);
    }
    if (!_bookingsBox.isOpen) {
      _bookingsBox = await Hive.openBox<BookingModel>(_bookingsBoxName);
    }
    if (!_favoritesBox.isOpen) {
      _favoritesBox = await Hive.openBox<FavoriteModel>(_favoritesBoxName);
    }
  }

  // HOSTEL OPERATIONS
  
  // Save a list of hostels
  Future<void> saveHostels(List<HostelModel> hostels) async {
    await _ensureInitialized();
    await _hostelsBox.clear();
    final hostelMap = {for (var hostel in hostels) hostel.id: hostel};
    await _hostelsBox.putAll(hostelMap);
  }

  // Get all hostels
  List<HostelModel> getAllHostels() {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    return _hostelsBox.values.toList();
  }

  // Get a specific hostel by ID
  HostelModel? getHostelById(int id) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    return _hostelsBox.get(id);
  }

  // Search hostels by name or description
  List<HostelModel> searchHostels(String query) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    final lowercaseQuery = query.toLowerCase();
    return _hostelsBox.values.where((hostel) {
      return hostel.name.toLowerCase().contains(lowercaseQuery) ||
          hostel.description.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // ROOM OPERATIONS
  
  // Save a list of rooms
  Future<void> saveRooms(List<RoomModel> rooms) async {
    await _ensureInitialized();
    final roomMap = {for (var room in rooms) room.id: room};
    await _roomsBox.putAll(roomMap);
  }

  // Get all rooms for a hostel
  List<RoomModel> getRoomsForHostel(int hostelId) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _roomsBox.values
        .where((room) => room.hostelId == hostelId)
        .toList();
  }

  // Get available rooms for a hostel
  List<RoomModel> getAvailableRoomsForHostel(int hostelId) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _roomsBox.values
        .where((room) => room.hostelId == hostelId && room.available)
        .toList();
  }

  // Get a specific room by ID
  RoomModel? getRoomById(int id) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _roomsBox.get(id);
  }

  // BOOKING OPERATIONS
  
  // Save a list of bookings
  Future<void> saveBookings(List<BookingModel> bookings) async {
    await _ensureInitialized();
    final bookingMap = {for (var booking in bookings) booking.id: booking};
    await _bookingsBox.putAll(bookingMap);
  }

  // Create a new offline booking
  Future<BookingModel> createOfflineBooking({
    required String userId,
    required int hostelId,
    required int roomId,
    required DateTime moveInDate,
    required double price,
    String? notes,
  }) async {
    await _ensureInitialized();
    
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

  // Get all bookings for a user
  List<BookingModel> getBookingsForUser(String userId) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _bookingsBox.values
        .where((booking) => booking.userId == userId)
        .toList();
  }

  // Get only offline (unsynced) bookings for a user
  List<BookingModel> getOfflineBookingsForUser(String userId) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _bookingsBox.values
        .where((booking) => booking.userId == userId && booking.syncStatus == 'pending')
        .toList();
  }

  // Get all unsynced bookings
  List<BookingModel> getUnsyncedBookings() {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _bookingsBox.values
        .where((booking) => booking.syncStatus == 'pending')
        .toList();
  }

  // Get a specific booking by ID
  BookingModel? getBookingById(String id) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    // Convert string ID to int if necessary
    final numId = int.tryParse(id);
    if (numId != null) {
      return _bookingsBox.get(numId);
    }
    return null;
  }

  // Mark a booking as synced
  Future<void> markBookingAsSynced(int bookingId) async {
    await _ensureInitialized();
    
    final booking = _bookingsBox.get(bookingId);
    if (booking != null) {
      booking.syncStatus = 'synced';
      await booking.save();
    }
  }

  // Update booking sync status
  Future<void> updateBookingSyncStatus(String bookingId, String status) async {
    await _ensureInitialized();
    
    final numId = int.tryParse(bookingId);
    if (numId != null) {
      final booking = _bookingsBox.get(numId);
      if (booking != null) {
        booking.syncStatus = status;
        await booking.save();
      }
    }
  }

  // Replace an offline booking with server data
  Future<void> replaceOfflineBooking(String offlineId, BookingModel serverBooking) async {
    await _ensureInitialized();
    
    final numId = int.tryParse(offlineId);
    if (numId != null) {
      await _bookingsBox.delete(numId);
      await _bookingsBox.put(serverBooking.id, serverBooking);
    }
  }

  // FAVORITE OPERATIONS
  
  // Add a favorite
  Future<void> addFavorite(FavoriteModel favorite) async {
    await _ensureInitialized();
    await _favoritesBox.put(favorite.id, favorite);
  }

  // Remove a favorite
  Future<void> removeFavorite(String id) async {
    await _ensureInitialized();
    await _favoritesBox.delete(id);
  }

  // Get favorites for a user
  List<FavoriteModel> getFavoritesForUser(String userId) {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _favoritesBox.values
        .where((favorite) => favorite.userId == userId)
        .toList();
  }

  // Get pending sync favorites
  List<FavoriteModel> getPendingSyncFavorites() {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initializeHive() first.');
    }
    
    return _favoritesBox.values
        .where((favorite) => favorite.pendingSync)
        .toList();
  }

  // Mark a favorite as synced
  Future<void> markFavoriteSynced(String id) async {
    await _ensureInitialized();
    
    final favorite = _favoritesBox.get(id);
    if (favorite != null) {
      favorite.pendingSync = false;
      await favorite.save();
    }
  }

  // CLEANUP OPERATIONS
  
  // Clear all local data
  Future<void> clearAllData() async {
    await _ensureInitialized();
    
    await _hostelsBox.clear();
    await _roomsBox.clear();
    await _bookingsBox.clear();
    await _favoritesBox.clear();
  }
  
  // Close Hive boxes
  Future<void> closeBoxes() async {
    if (_isInitialized) {
      await _hostelsBox.close();
      await _roomsBox.close();
      await _bookingsBox.close();
      await _favoritesBox.close();
      _isInitialized = false;
    }
  }
   List<BookingModel> getPendingSyncBookings() {
    return _bookingsBox.values
        .where((booking) => 
            booking.isOfflineBooking && booking.syncStatus == 'pending')
        .toList();
  }
  Future<List<FavoriteModel>> getUnsyncedFavorites() async {
  final box = await Hive.openBox<FavoriteModel>('favorites');
  return box.values.where((fav) => !fav.synced).toList();
}

Future<void> markFavoriteAsSynced(String id) async {
  final box = await Hive.openBox<FavoriteModel>('favorites');

  FavoriteModel? fav;
  try {
    fav = box.values.firstWhere((fav) => fav.id == id);
  } catch (e) {
    fav = null;
  }

  if (fav != null) {
    fav.synced = true;
    await fav.save();
  }
}

static Future<void> _ensureBoxOpen(String boxName) async {
  if (!Hive.isBoxOpen(boxName)) {
    await Hive.openBox(boxName);
  }
}



}