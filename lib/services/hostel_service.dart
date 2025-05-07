import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostel_connect/services/connectivity_service.dart';
import 'package:hostel_connect/services/local_database_service.dart';
import 'package:hostel_connect/services/hive_models.dart';

class HostelService {
  static final supabase = Supabase.instance.client;
  static final LocalDatabaseService _localDb = LocalDatabaseService();
  static final ConnectivityService _connectivityService = ConnectivityService();
  
  // Get all hostels with offline support
  static Future<List<Map<String, dynamic>>> getAllHostels() async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
            .from('hostels')
            .select('''
              *,
              hostel_amenities:hostel_amenities(amenity)
            ''')
            .order('created_at', ascending: false);
    
        // Convert to list of maps
        List<Map<String, dynamic>> hostels = List<Map<String, dynamic>>.from(response);
        
        // For each hostel, query the actual available rooms count
        for (var hostel in hostels) {
          final int hostelId = hostel['id'];
          
          // Count available rooms for this hostel
          final roomsResponse = await supabase
              .from('rooms')
              .select('id')
              .eq('hostel_id', hostelId)
              .eq('available', true);
          
          // Add the actual available rooms count
          hostel['actual_available_rooms'] = roomsResponse.length;
        }

        // Cache hostels in local database
        await _saveHostelsToLocalCache(hostels);
        
        return hostels;
      } else {
        // Offline: Get from local storage
        return _getHostelsFromLocalCache();
      }
    } catch (e) {
      // If any error occurs, try to get from local cache
      try {
        return _getHostelsFromLocalCache();
      } catch (cacheError) {
        // Both remote and local data retrieval failed
        throw Exception('Failed to get hostels: $e, Cache error: $cacheError');
      }
    }
  }

  // Get available rooms for a hostel with offline support
  static Future<List<Map<String, dynamic>>> getAvailableHostelRooms(int hostelId) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
            .from('rooms')
            .select()
            .eq('hostel_id', hostelId)
            .eq('available', true)
            .order('room_number');
        
        List<Map<String, dynamic>> rooms = List<Map<String, dynamic>>.from(response);
        
        // Cache rooms in local database
        await _saveRoomsToLocalCache(rooms);
        
        return rooms;
      } else {
        // Offline: Get from local storage
        return _getAvailableRoomsFromLocalCache(hostelId);
      }
    } catch (e) {
      // If any error occurs, try to get from local cache
      try {
        return _getAvailableRoomsFromLocalCache(hostelId);
      } catch (cacheError) {
        throw Exception('Failed to get available rooms: $e, Cache error: $cacheError');
      }
    }
  }
  
  // Get hostels by location with offline support
  static Future<List<Map<String, dynamic>>> getHostelsByLocation(String location) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
            .from('hostels')
            .select('*, hostel_amenities(amenity)')
            .eq('location', location)
            .order('created_at', ascending: false);
        
        List<Map<String, dynamic>> hostels = List<Map<String, dynamic>>.from(response);
        
        // Cache hostels in local database
        await _saveHostelsToLocalCache(hostels);
        
        return hostels;
      } else {
        // Offline: Filter from local storage
        return _getHostelsByLocationFromLocalCache(location);
      }
    } catch (e) {
      // If any error occurs, try to get from local cache
      try {
        return _getHostelsByLocationFromLocalCache(location);
      } catch (cacheError) {
        return [];
      }
    }
  }

  // Get all rooms for a hostel with offline support
  static Future<List<Map<String, dynamic>>> getHostelRooms(int hostelId) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
            .from('rooms')
            .select()
            .eq('hostel_id', hostelId)
            .order('room_number');
        
        List<Map<String, dynamic>> rooms = List<Map<String, dynamic>>.from(response);
        
        // Cache rooms in local database
        await _saveRoomsToLocalCache(rooms);
        
        return rooms;
      } else {
        // Offline: Get from local storage
        return _getRoomsFromLocalCache(hostelId);
      }
    } catch (e) {
      // If any error occurs, try to get from local cache
      try {
        return _getRoomsFromLocalCache(hostelId);
      } catch (cacheError) {
        throw Exception('Failed to get rooms: $e, Cache error: $cacheError');
      }
    }
  }
  
  // Get single hostel details with offline support
  static Future<Map<String, dynamic>> getHostelById(int hostelId) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
            .from('hostels')
            .select('''
              *,
              hostel_amenities:hostel_amenities(amenity),
              hostel_rules:hostel_rules(rule)
            ''')
            .eq('id', hostelId)
            .single();
        
        // Get actual available rooms count
        final roomsResponse = await supabase
            .from('rooms')
            .select('id')
            .eq('hostel_id', hostelId)
            .eq('available', true);
        
        // Add the actual available rooms count
        Map<String, dynamic> hostel = response;
        hostel['actual_available_rooms'] = roomsResponse.length;
        
        // Cache this hostel in local database
        await _saveHostelToLocalCache(hostel);
        
        return hostel;
      } else {
        // Offline: Get from local storage
        return _getHostelByIdFromLocalCache(hostelId);
      }
    } catch (e) {
      // If any error occurs, try to get from local cache
      try {
        return _getHostelByIdFromLocalCache(hostelId);
      } catch (cacheError) {
        throw Exception('Failed to get hostel: $e, Cache error: $cacheError');
      }
    }
  }
  
  // Search hostels with offline support
  static Future<List<Map<String, dynamic>>> searchHostels(String query) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
            .from('hostels')
            .select('*, hostel_amenities(amenity)')
            .or('name.ilike.%$query%, description.ilike.%$query%')
            .order('created_at', ascending: false);
        
        return List<Map<String, dynamic>>.from(response);
      } else {
        // Offline: Search in local storage
        return _searchHostelsInLocalCache(query);
      }
    } catch (e) {
      // If any error occurs, try to search in local cache
      try {
        return _searchHostelsInLocalCache(query);
      } catch (cacheError) {
        return [];
      }
    }
  }
  
  // Create a booking with offline support
  static Future<bool> createBooking(Map<String, dynamic> bookingData) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Create on Supabase
        await supabase.from('bookings').insert(bookingData);
        return true;
      } else {
        // Offline: Create locally
        await _localDb.createOfflineBooking(
          userId: bookingData['user_id'],
          hostelId: bookingData['hostel_id'],
          roomId: bookingData['room_id'],
          moveInDate: DateTime.parse(bookingData['move_in_date']),
          price: bookingData['price'].toDouble(),
          notes: bookingData['notes'],
        );
        return true;
      }
    } catch (e) {
      print('Error creating booking: $e');
      return false;
    }
  }
  
  // Get user bookings with offline support
  static Future<List<Map<String, dynamic>>> getUserBookings(String userId) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
          .from('bookings')
          .select('''
            *,
            hostel:hostel_id(id, name, location, image_url),
            room:room_id(id, name)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
        
        if (response == null) return [];
        
        List<Map<String, dynamic>> bookings = List<Map<String, dynamic>>.from(response);
        
        // Cache bookings in local database
        await _saveBookingsToLocalCache(bookings, userId);
        
        // Merge with any offline bookings
        final offlineBookings = await _getOfflineBookingsFromLocalCache(userId);
        
        return [...bookings, ...offlineBookings];
      } else {
        // Offline: Get from local storage
        return _getUserBookingsFromLocalCache(userId);
      }
    } catch (e) {
      // If any error occurs, try to get from local cache
      try {
        return _getUserBookingsFromLocalCache(userId);
      } catch (cacheError) {
        throw Exception('Failed to get bookings: $e, Cache error: $cacheError');
      }
    }
  }
  
  // Cancel a booking with offline support
  static Future<void> cancelBooking(dynamic bookingId) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Cancel on Supabase
        await supabase
          .from('bookings')
          .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', bookingId);
      } else {
        // Offline: Mark for cancellation when back online
        // This would require additional logic in your local database service
        // For now, we'll throw an exception
        throw Exception('Cannot cancel booking while offline');
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      throw e;
    }
  }

  // Get booking details by ID with offline support
  static Future<Map<String, dynamic>?> getBookingById(int bookingId) async {
    try {
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        // Online: Fetch from Supabase
        final response = await supabase
            .from('bookings')
            .select('''
              *,
              hostel:hostel_id(id, name, location, image_url, amenities, description),
              room:room_id(id, name, capacity, features, price, availability)
            ''')
            .eq('id', bookingId)
            .single();
        
        Map<String, dynamic> booking = response as Map<String, dynamic>;
        
        // Cache this booking
        await _saveBookingToLocalCache(booking);
        
        return booking;
      } else {
        // Offline: Get from local storage
        return _getBookingByIdFromLocalCache(bookingId);
      }
    } catch (e) {
      // If any error occurs, try to get from local cache
      try {
        return _getBookingByIdFromLocalCache(bookingId);
      } catch (cacheError) {
        throw Exception('Failed to fetch booking details: $e, Cache error: $cacheError');
      }
    }
  }
  
  // Sync all offline data with the server
  static Future<void> syncOfflineData() async {
    // Check connectivity
    final bool isConnected = await _connectivityService.checkConnectivity();
    if (!isConnected) return;
    
    try {
      // Sync bookings
      final unsyncedBookings = await _localDb.getPendingSyncBookings();
      
      for (var booking in unsyncedBookings) {
        try {
          // Send to server
          final response = await supabase.from('bookings').insert({
            'user_id': booking.userId,
            'hostel_id': booking.hostelId,
            'room_id': booking.roomId,
            'move_in_date': booking.moveInDate.toIso8601String(),
            'status': booking.status,
            'notes': booking.notes,
            'price': booking.price,
            'created_at': booking.createdAt.toIso8601String(),
          }).select().single();
          
          // Mark as synced
          await _localDb.updateBookingSyncStatus(booking.id.toString(), 'synced');
          
          // Replace with server booking
          await _localDb.replaceOfflineBooking(booking.id.toString(), 
            BookingModel(
              id: response['id'],
              userId: response['user_id'],
              hostelId: response['hostel_id'],
              roomId: response['room_id'],
              moveInDate: DateTime.parse(response['move_in_date']),
              status: response['status'],
              notes: response['notes'],
              price: response['price'].toDouble(),
              createdAt: DateTime.parse(response['created_at']),
              updatedAt: DateTime.parse(response['updated_at']),
              syncStatus: 'synced',
            )
          );
        } catch (e) {
          print('Failed to sync booking ${booking.id}: $e');
        }
      }
      
      // Sync favorites if you have them
      final pendingSyncFavorites = _localDb.getPendingSyncFavorites();
      
      for (var favorite in pendingSyncFavorites) {
        try {
          await supabase.from('favorites').insert({
            'user_id': favorite.userId,
            'hostel_id': favorite.hostelId,
            'created_at': favorite.createdAt.toIso8601String(),
          });
          
          // Mark as synced
          await _localDb.markFavoriteSynced(favorite.id);
        } catch (e) {
          print('Failed to sync favorite ${favorite.id}: $e');
        }
      }
    } catch (e) {
      print('Error during sync: $e');
    }
  }

  // HELPER METHODS FOR LOCAL CACHE

  // Save hostels to local cache
  static Future<void> _saveHostelsToLocalCache(List<Map<String, dynamic>> hostels) async {
    final List<HostelModel> hostelModels = hostels.map((hostel) {
      return HostelModel(
        id: hostel['id'],
        name: hostel['name'] ?? '',
        description: hostel['description'] ?? '',
        address: hostel['address'] ?? '',
        campusLocation: hostel['campus_location'] ?? 'Unknown',
        price: hostel['price'] ?? 0,
        availableRooms: hostel['actual_available_rooms'] ?? 0,
        imageUrl: hostel['image_url'],
        ownerId: hostel['owner_id'] ?? '',
        createdAt: DateTime.parse(hostel['created_at'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(hostel['updated_at'] ?? DateTime.now().toIso8601String()),
        location: hostel['location'] ?? '',
        email: hostel['email'],
        phone: hostel['phone'],
      );
    }).toList();
    
    await _localDb.saveHostels(hostelModels);
  }

  // Save a single hostel to local cache
  static Future<void> _saveHostelToLocalCache(Map<String, dynamic> hostel) async {
    final hostelModel = HostelModel(
      id: hostel['id'],
      name: hostel['name'] ?? '',
      description: hostel['description'] ?? '',
      address: hostel['address'] ?? '',
      campusLocation: hostel['campus_location'] ?? 'Unknown',
      price: hostel['price'] ?? 0,
      availableRooms: hostel['actual_available_rooms'] ?? 0,
      imageUrl: hostel['image_url'],
      ownerId: hostel['owner_id'] ?? '',
      createdAt: DateTime.parse(hostel['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(hostel['updated_at'] ?? DateTime.now().toIso8601String()),
      location: hostel['location'] ?? '',
      email: hostel['email'],
      phone: hostel['phone'],
    );
    
    final hostels = _localDb.getAllHostels();
    final existingIndex = hostels.indexWhere((h) => h.id == hostelModel.id);
    
    if (existingIndex != -1) {
      hostels[existingIndex] = hostelModel;
    } else {
      hostels.add(hostelModel);
    }
    
    await _localDb.saveHostels(hostels);
  }

  // Save rooms to local cache
  static Future<void> _saveRoomsToLocalCache(List<Map<String, dynamic>> rooms) async {
    final List<RoomModel> roomModels = rooms.map((room) {
      return RoomModel(
        id: room['id'],
        hostelId: room['hostel_id'],
        name: room['name'] ?? '',
        roomNumber: room['room_number'] ?? 0,
        price: (room['price'] ?? 0).toDouble(),
        capacity: room['capacity'] ?? 1,
        description: room['description'],
        available: room['available'] ?? false,
        imageUrl: room['image_url'],
        createdAt: DateTime.parse(room['created_at'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(room['updated_at'] ?? DateTime.now().toIso8601String()),
      );
    }).toList();
    
    await _localDb.saveRooms(roomModels);
  }

  // Save bookings to local cache
  static Future<void> _saveBookingsToLocalCache(List<Map<String, dynamic>> bookings, String userId) async {
    final List<BookingModel> bookingModels = bookings.map((booking) {
      return BookingModel(
        id: booking['id'],
        userId: booking['user_id'],
        hostelId: booking['hostel_id'],
        roomId: booking['room_id'],
        moveInDate: DateTime.parse(booking['move_in_date']),
        status: booking['status'] ?? 'pending',
        notes: booking['notes'],
        price: (booking['price'] ?? 0).toDouble(),
        createdAt: DateTime.parse(booking['created_at'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(booking['updated_at'] ?? DateTime.now().toIso8601String()),
        syncStatus: 'synced', // Already synced with server
      );
    }).toList();
    
    // Get existing offline bookings
    final existingBookings = _localDb.getBookingsForUser(userId);
    final offlineBookings = existingBookings.where((b) => b.isOfflineBooking).toList();
    
    // Add offline bookings to the list
    bookingModels.addAll(offlineBookings);
    
    await _localDb.saveBookings(bookingModels);
  }

  // Save a single booking to local cache
  static Future<void> _saveBookingToLocalCache(Map<String, dynamic> booking) async {
    final bookingModel = BookingModel(
      id: booking['id'],
      userId: booking['user_id'],
      hostelId: booking['hostel_id'],
      roomId: booking['room_id'],
      moveInDate: DateTime.parse(booking['move_in_date']),
      status: booking['status'] ?? 'pending',
      notes: booking['notes'],
      price: (booking['price'] ?? 0).toDouble(),
      createdAt: DateTime.parse(booking['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(booking['updated_at'] ?? DateTime.now().toIso8601String()),
      syncStatus: 'synced', // Already synced with server
    );
    
    final bookings = _localDb.getBookingsForUser(booking['user_id']);
    final existingIndex = bookings.indexWhere((b) => b.id == bookingModel.id);
    
    if (existingIndex != -1) {
      bookings[existingIndex] = bookingModel;
    } else {
      bookings.add(bookingModel);
    }
    
    await _localDb.saveBookings(bookings);
  }

  // Get hostels from local cache
  static List<Map<String, dynamic>> _getHostelsFromLocalCache() {
    final hostels = _localDb.getAllHostels();
    return hostels.map((hostel) => _hostelModelToMap(hostel)).toList();
  }

  // Get hostels by location from local cache
  static List<Map<String, dynamic>> _getHostelsByLocationFromLocalCache(String location) {
    final hostels = _localDb.getAllHostels();
    return hostels
        .where((hostel) => hostel.location.toLowerCase() == location.toLowerCase())
        .map((hostel) => _hostelModelToMap(hostel))
        .toList();
  }

  // Get a hostel by ID from local cache
  static Map<String, dynamic> _getHostelByIdFromLocalCache(int hostelId) {
    final hostel = _localDb.getHostelById(hostelId);
    if (hostel == null) {
      throw Exception('Hostel not found in local cache');
    }
    return _hostelModelToMap(hostel);
  }

  // Get rooms for a hostel from local cache
  static List<Map<String, dynamic>> _getRoomsFromLocalCache(int hostelId) {
    final rooms = _localDb.getRoomsForHostel(hostelId);
    return rooms.map((room) => _roomModelToMap(room)).toList();
  }

  // Get available rooms for a hostel from local cache
  static List<Map<String, dynamic>> _getAvailableRoomsFromLocalCache(int hostelId) {
    final rooms = _localDb.getAvailableRoomsForHostel(hostelId);
    return rooms.map((room) => _roomModelToMap(room)).toList();
  }

  // Search hostels in local cache
  static List<Map<String, dynamic>> _searchHostelsInLocalCache(String query) {
    final hostels = _localDb.searchHostels(query);
    return hostels.map((hostel) => _hostelModelToMap(hostel)).toList();
  }

  // Get user bookings from local cache
  static List<Map<String, dynamic>> _getUserBookingsFromLocalCache(String userId) {
    final bookings = _localDb.getBookingsForUser(userId);
    return bookings.map((booking) => _bookingModelToMap(booking)).toList();
  }

  // Get offline bookings from local cache
  static List<Map<String, dynamic>> _getOfflineBookingsFromLocalCache(String userId) {
    final bookings = _localDb.getOfflineBookingsForUser(userId);
    return bookings.map((booking) => _bookingModelToMap(booking)).toList();
  }

  // Get a booking by ID from local cache
  static Map<String, dynamic>? _getBookingByIdFromLocalCache(int bookingId) {
    final booking = _localDb.getBookingById(bookingId.toString());
    if (booking == null) {
      return null;
    }
    return _bookingModelToMap(booking);
  }

  // Convert HostelModel to Map
  static Map<String, dynamic> _hostelModelToMap(HostelModel hostel) {
    return {
      'id': hostel.id,
      'name': hostel.name,
      'description': hostel.description,
      'address': hostel.address,
      'campus_location': hostel.campusLocation,
      'price': hostel.price,
      'actual_available_rooms': hostel.availableRooms,
      'image_url': hostel.imageUrl,
      'owner_id': hostel.ownerId,
      'created_at': hostel.createdAt.toIso8601String(),
      'updated_at': hostel.updatedAt.toIso8601String(),
      'location': hostel.location,
      'email': hostel.email,
      'phone': hostel.phone,
      'hostel_amenities': [], // We don't store amenities in Hive model yet
    };
  }

  // Convert RoomModel to Map
  static Map<String, dynamic> _roomModelToMap(RoomModel room) {
    return {
      'id': room.id,
      'hostel_id': room.hostelId,
      'name': room.name,
      'room_number': room.roomNumber,
      'price': room.price,
      'capacity': room.capacity,
      'description': room.description,
      'available': room.available,
      'image_url': room.imageUrl,
      'created_at': room.createdAt.toIso8601String(),
      'updated_at': room.updatedAt.toIso8601String(),
    };
  }

  // Convert BookingModel to Map
  static Map<String, dynamic> _bookingModelToMap(BookingModel booking) {
    // Try to get the associated hostel and room
    final hostel = _localDb.getHostelById(booking.hostelId);
    final room = _localDb.getRoomById(booking.roomId);
    
    return {
      'id': booking.id,
      'user_id': booking.userId,
      'hostel_id': booking.hostelId,
      'room_id': booking.roomId,
      'move_in_date': booking.moveInDate.toIso8601String(),
      'status': booking.status,
      'notes': booking.notes,
      'price': booking.price,
      'created_at': booking.createdAt.toIso8601String(),
      'updated_at': booking.updatedAt.toIso8601String(),
      'sync_status': booking.syncStatus,
      'is_offline_booking': booking.isOfflineBooking,
      // Include hostel and room information
      'hostel': hostel != null ? {
        'id': hostel.id,
        'name': hostel.name,
        'location': hostel.location,
        'image_url': hostel.imageUrl,
      } : null,
      'room': room != null ? {
        'id': room.id,
        'name': room.name,
      } : null,
    };
  }
}