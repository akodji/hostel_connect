// hostel_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class HostelService {
  static final supabase = Supabase.instance.client;
  
  // Get all hostels
  static Future<List<Map<String, dynamic>>> getAllHostels() async {
    // First get all hostels
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

    return hostels;
  }

  // Get available rooms for a hostel
  static Future<List<Map<String, dynamic>>> getAvailableHostelRooms(int hostelId) async {
    final response = await supabase
        .from('rooms')
        .select()
        .eq('hostel_id', hostelId)
        .eq('available', true)
        .order('room_number');
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  // Get hostels by location
  static Future<List<Map<String, dynamic>>> getHostelsByLocation(String location) async {
    try {
      final response = await supabase
          .from('hostels')
          .select('*, hostel_amenities(amenity)')
          .eq('location', location)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting hostels by location: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getHostelRooms(int hostelId) async {
    final response = await supabase
        .from('rooms')
        .select()
        .eq('hostel_id', hostelId)
        .order('room_number');
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  // Get hostel by ID
  
  // Get single hostel details
  static Future<Map<String, dynamic>> getHostelById(int hostelId) async {
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
    
    return hostel;
  }
  
  // Search hostels
  static Future<List<Map<String, dynamic>>> searchHostels(String query) async {
    try {
      final response = await supabase
          .from('hostels')
          .select('*, hostel_amenities(amenity)')
          .or('name.ilike.%$query%, description.ilike.%$query%')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching hostels: $e');
      return [];
    }
  }
  
  // Create a booking
  static Future<bool> createBooking(Map<String, dynamic> bookingData) async {
    try {
      await supabase.from('bookings').insert(bookingData);
      return true;
    } catch (e) {
      print('Error creating booking: $e');
      return false;
    }
  }
  
  // Get user bookings
  static Future<List<Map<String, dynamic>>> getUserBookings(String userId) async {
    try {
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
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user bookings: $e');
      throw e;
    }
  }
  
  static Future<void> cancelBooking(dynamic bookingId) async {
    try {
      await supabase
        .from('bookings')
        .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', bookingId);
    } catch (e) {
      print('Error cancelling booking: $e');
      throw e;
    }
  }

   // Get booking details by ID
  static Future<Map<String, dynamic>?> getBookingById(int bookingId) async {
    try {
      final response = await supabase
          .from('bookings')
          .select('''
            *,
            hostel:hostel_id(id, name, location, image_url, amenities, description),
            room:room_id(id, name, capacity, features, price, availability)
          ''')
          .eq('id', bookingId)
          .single();
      
      return response as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to fetch booking details: $e');
    }
  }

  // Get user bookings with hostel and room details
  // static Future<List<Map<String, dynamic>>> getUserBookings(String userId) async {
  //   try {
  //     final response = await supabase
  //         .from('bookings')
  //         .select('''
  //           *,
  //           hostel:hostel_id(id, name, location, image_url),
  //           room:room_id(id, name, capacity, price)
  //         ''')
  //         .eq('user_id', userId)
  //         .order('created_at', ascending: false);

  //     // Check if response is a List
  //     if (response is! List) {
  //       throw Exception('Unexpected response format');
  //     }

  //     // Convert each item to Map<String, dynamic>
  //     return List<Map<String, dynamic>>.from(response);
  //   } catch (e) {
  //     print('Error getting user bookings: $e');
  //     throw Exception('Failed to load bookings: $e');
  //   }
  // }

  // // Cancel a booking
  // static Future<void> cancelBooking(dynamic bookingId) async {
  //   try {
  //     await supabase
  //         .from('bookings')
  //         .update({'status': 'cancelled'})
  //         .eq('id', bookingId);
  //   } catch (e) {
  //     print('Error cancelling booking: $e');
  //     throw Exception('Failed to cancel booking: $e');
  //   }
  // }

}