import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final supabase = Supabase.instance.client;

  // Create a notification in the database
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String? relatedId,
    String? type,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'is_read': false,
        'related_id': relatedId,
        'type': type ?? 'booking',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating notification: $e');
      rethrow;
    }
  }

  // Mark a notification as read
  static Future<void> markAsRead(int notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } catch (e) {
      print('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // Get all notifications for a user
  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching notifications: $e');
      rethrow;
    }
  }

  // Get unread notification count for a user
  static Future<int> getUnreadCount(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      
      return (response as List).length;
    } catch (e) {
      print('Error fetching unread count: $e');
      return 0;
    }
  }

  // Delete a notification
  static Future<void> deleteNotification(int notificationId) async {
    try {
      await supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }
  
  // Create booking notification for hostel owner
  static Future<void> notifyHostelOwner(Map<String, dynamic> booking, String actionType) async {
    try {
      final hostelId = booking['hostel_id'];
      
      // Get the owner ID for this hostel
      final hostelResponse = await supabase
          .from('hostels')
          .select('owner_id')
          .eq('id', hostelId)
          .single();
      
      final ownerId = hostelResponse['owner_id'];
      if (ownerId == null) return;
      
      // Get hostel and user details for the notification message
      final hostelName = (booking['hostels'] as Map<String, dynamic>)['name'] ?? 'your hostel';
      final userName = booking['profiles'] != null 
          ? '${(booking['profiles'] as Map<String, dynamic>)['first_name']} ${(booking['profiles'] as Map<String, dynamic>)['last_name']}' 
          : 'A user';
      
      String title;
      String message;
      
      switch (actionType) {
        case 'new_booking':
          title = 'New Booking Request';
          message = '$userName has requested a booking for $hostelName.';
          break;
        case 'cancelled':
          title = 'Booking Cancelled';
          message = '$userName has cancelled their booking request for $hostelName.';
          break;
        default:
          title = 'Booking Update';
          message = 'There has been an update to a booking for $hostelName.';
      }
      
      await createNotification(
        userId: ownerId,
        title: title,
        message: message,
        relatedId: booking['id'].toString(),
        type: 'booking',
      );
    } catch (e) {
      print('Error notifying hostel owner: $e');
    }
  }

  // Create booking notification for student
  static Future<void> notifyStudent(Map<String, dynamic> booking, String newStatus) async {
    try {
      final userId = booking['user_id'];
      if (userId == null) return;
      
      final hostelName = (booking['hostels'] as Map<String, dynamic>)['name'] ?? 'the hostel';
      
      String title;
      String message;
      
      switch (newStatus) {
        case 'confirmed':
          title = 'Booking Confirmed';
          message = 'Your booking request for $hostelName has been confirmed.';
          break;
        case 'rejected':
          title = 'Booking Rejected';
          message = 'Your booking request for $hostelName has been rejected.';
          break;
        case 'active':
          title = 'Booking Now Active';
          message = 'Your booking at $hostelName is now active.';
          break;
        case 'completed':
          title = 'Booking Completed';
          message = 'Your booking at $hostelName has been marked as completed.';
          break;
        default:
          title = 'Booking Status Update';
          message = 'Your booking for $hostelName has been updated to: $newStatus.';
      }
      
      await createNotification(
        userId: userId,
        title: title,
        message: message,
        relatedId: booking['id'].toString(),
        type: 'booking',
      );
    } catch (e) {
      print('Error notifying student: $e');
    }
  }
}