// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//   final supabase = Supabase.instance.client;

//   factory NotificationService() {
//     return _instance;
//   }

//   NotificationService._internal();

//   Future<void> initialize() async {
//     // Initialize local notifications
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
    
//     const DarwinInitializationSettings initializationSettingsIOS =
//         DarwinInitializationSettings();
    
//     const InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );
    
//     await _flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//     );

//     // Set up Supabase realtime subscriptions
//     await _setupRealtimeSubscriptions();
//   }

//   Future<void> _setupRealtimeSubscriptions() async {
//     final currentUser = supabase.auth.currentUser;
//     if (currentUser == null) return;

//     // Check if the user is a hostel owner
//     final userHostels = await supabase
//         .from('hostels')
//         .select('id')
//         .eq('owner_id', currentUser.id);
    
//     final isHostelOwner = userHostels != null && (userHostels as List).isNotEmpty;

//     // Subscribe to bookings channel
//     supabase
//       .channel('bookings_channel')
//       .on(
//         RealtimeListenTypes.postgresChanges,
//         ChannelFilter(
//           event: 'INSERT',
//           schema: 'public',
//           table: 'bookings',
//         ),
//         (payload, [ref]) {
//           _handleNewBooking(payload, isHostelOwner);
//         },
//       )
//       .on(
//         RealtimeListenTypes.postgresChanges,
//         ChannelFilter(
//           event: 'UPDATE',
//           schema: 'public',
//           table: 'bookings',
//         ),
//         (payload, [ref]) {
//           _handleBookingUpdate(payload, isHostelOwner, currentUser.id);
//         },
//       )
//       .subscribe();
//   }

//   Future<void> _handleNewBooking(Map<String, dynamic> payload, bool isHostelOwner) async {
//     final newBooking = payload['new'];
//     final currentUser = supabase.auth.currentUser;
    
//     if (isHostelOwner) {
//       // Check if the booking is for one of the owner's hostels
//       final hostelId = newBooking['hostel_id'];
//       final userHostels = await supabase
//           .from('hostels')
//           .select('id')
//           .eq('owner_id', currentUser?.id)
//           .eq('id', hostelId);
      
//       if (userHostels != null && (userHostels as List).isNotEmpty) {
//         // Get hostel and room details
//         final hostelData = await supabase
//             .from('hostels')
//             .select('name')
//             .eq('id', hostelId)
//             .single();
        
//         final roomData = await supabase
//             .from('rooms')
//             .select('name')
//             .eq('id', newBooking['room_id'])
//             .single();
        
//         // Get guest details
//         final guestData = await supabase
//             .from('profiles')
//             .select('first_name, last_name')
//             .eq('id', newBooking['user_id'])
//             .single();
        
//         final hostelName = hostelData['name'];
//         final roomName = roomData['name'];
//         final guestName = '${guestData['first_name']} ${guestData['last_name']}';
        
//         // Show notification to hostel owner
//         await _showNotification(
//           'New Booking Request',
//           'Room $roomName at $hostelName has been booked by $guestName',
//         );
//       }
//     }
//   }

//   Future<void> _handleBookingUpdate(Map<String, dynamic> payload, bool isHostelOwner, String userId) async {
//     final oldBooking = payload['old'];
//     final updatedBooking = payload['new'];
    
//     // Check if status was updated
//     if (oldBooking['status'] != updatedBooking['status']) {
//       if (isHostelOwner) {
//         // For hostel owners
//         if (updatedBooking['status'] == 'confirmed') {
//           // If you want owners to be notified when they confirm a booking (optional)
//           final bookingDetails = await _getBookingDetails(updatedBooking['id']);
//           await _showNotification(
//             'Booking Confirmed',
//             'You confirmed the booking for ${bookingDetails['room_name']} at ${bookingDetails['hostel_name']}',
//           );
//         }
//       } else if (updatedBooking['user_id'] == userId) {
//         // For regular users when their booking status changes
//         final bookingDetails = await _getBookingDetails(updatedBooking['id']);
        
//         String title;
//         String body;
        
//         switch (updatedBooking['status']) {
//           case 'confirmed':
//             title = 'Booking Confirmed';
//             body = 'Your booking for ${bookingDetails['room_name']} at ${bookingDetails['hostel_name']} has been confirmed';
//             break;
//           case 'rejected':
//             title = 'Booking Rejected';
//             body = 'Your booking for ${bookingDetails['room_name']} at ${bookingDetails['hostel_name']} has been rejected';
//             break;
//           case 'cancelled':
//             title = 'Booking Cancelled';
//             body = 'Your booking for ${bookingDetails['room_name']} at ${bookingDetails['hostel_name']} has been cancelled';
//             break;
//           default:
//             title = 'Booking Update';
//             body = 'Your booking status has been updated to ${updatedBooking['status']}';
//         }
        
//         await _showNotification(title, body);
//       }
//     }
//   }

//   Future<Map<String, dynamic>> _getBookingDetails(int bookingId) async {
//     final booking = await supabase
//       .from('bookings')
//       .select('''
//         *,
//         hostels:hostel_id(name),
//         rooms:room_id(name)
//       ''')
//       .eq('id', bookingId)
//       .single();
    
//     return {
//       'hostel_name': booking['hostels']['name'],
//       'room_name': booking['rooms']['name'],
//     };
//   }

//   Future<void> _showNotification(String title, String body) async {
//     const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       'hostel_connect_channel',
//       'Hostel Connect Notifications',
//       channelDescription: 'Notifications for Hostel Connect app',
//       importance: Importance.max,
//       priority: Priority.high,
//       showWhen: true,
//     );
    
//     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );
    
//     const NotificationDetails notificationDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );
    
//     await _flutterLocalNotificationsPlugin.show(
//       DateTime.now().millisecond,
//       title,
//       body,
//       notificationDetails,
//     );
//   }
// }