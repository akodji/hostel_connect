// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:hostel_connect/services/notification_service.dart';
// import './notification_screen.dart';

// class NotificationBadge extends StatefulWidget {
//   final Color? color;
//   final double size;
  
//   const NotificationBadge({
//     Key? key, 
//     this.color,
//     this.size = 24.0,
//   }) : super(key: key);

//   @override
//   _NotificationBadgeState createState() => _NotificationBadgeState();
// }

// class _NotificationBadgeState extends State<NotificationBadge> {
//   final supabase = Supabase.instance.client;
//   int _unreadCount = 0;
//   bool _isLoading = true;
//   Stream<List<Map<String, dynamic>>>? _notificationStream;

//   @override
//   void initState() {
//     super.initState();
//     _loadUnreadCount();
//     _setupRealtimeSubscription();
//   }

//   @override
//   void dispose() {
//     _removeRealtimeSubscription();
//     super.dispose();
//   }

//   Future<void> _loadUnreadCount() async {
//     try {
//       final userId = supabase.auth.currentUser?.id;
//       if (userId == null) return;

//       final unreadCount = await NotificationService.getUnreadCount(userId);
      
//       if (mounted) {
//         setState(() {
//           _unreadCount = unreadCount;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error loading unread count: $e');
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _setupRealtimeSubscription() {
//     final userId = supabase.auth.currentUser?.id;
//     if (userId == null) return;

//     // Subscribe to notifications table changes for the current user
//     supabase
//         .channel('public:notifications')
//         .onPostgresChanges(
//           event: PostgresChangeEvent.insert,
//           schema: 'public',
//           table: 'notifications',
//           filter: PostgresChangeFilter(
//             type: PostgresChangeFilterType.eq,
//             column: 'user_id',
//             value: userId,
//           ),
//         )
//         .onPostgresChanges(
//           event: PostgresChangeEvent.update,
//           schema: 'public',
//           table: 'notifications',
//           filter: PostgresChangeFilter(
//             type: PostgresChangeFilterType.eq,
//             column: 'user_id',
//             value: userId,
//           ),
//         )
//         .subscribe((payload) {
//           // Reload the unread count when notifications change
//           _loadUnreadCount();
//         });
//   }

//   void _removeRealtimeSubscription() {
//     // Remove the subscription when the widget is disposed
//     supabase.channel('public:notifications').unsubscribe();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         IconButton(
//           icon: Icon(
//             Icons.notifications_outlined,
//             color: widget.color ?? Theme.of(context).iconTheme.color,
//             size: widget.size,
//           ),
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => const NotificationScreen(),
//               ),
//             ).then((_) {
//               // Reload the unread count when returning from the notification screen
//               _loadUnreadCount();
//             });
//           },
//         ),
//         if (_unreadCount > 0)
//           Positioned(
//             right: 8,
//             top: 8,
//             child: Container(
//               padding: const EdgeInsets.all(2),
//               decoration: BoxDecoration(
//                 color: Colors.red,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               constraints: const BoxConstraints(
//                 minWidth: 16,
//                 minHeight: 16,
//               ),
//               child: Text(
//                 _unreadCount > 9 ? '9+' : _unreadCount.toString(),
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 10,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }