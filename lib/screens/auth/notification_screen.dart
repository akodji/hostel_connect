import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hostel_connect/services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final notifications = await NotificationService.getUserNotifications(userId);
      final unreadCount = await NotificationService.getUnreadCount(userId);

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await NotificationService.markAllAsRead(userId);
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark notifications as read: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      await _loadNotifications();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      await NotificationService.deleteNotification(notificationId);
      await _loadNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all as read',
                style: TextStyle(
                  color: Color(0xFF4A6FE3),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final bool isRead = notification['is_read'] ?? false;
                      final DateTime createdAt = DateTime.parse(notification['created_at']);
                      
                      return Dismissible(
                        key: Key(notification['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          _deleteNotification(notification['id']);
                        },
                        child: GestureDetector(
                          onTap: () {
                            if (!isRead) {
                              _markAsRead(notification['id']);
                            }
                            
                            // If this notification relates to a booking, we could navigate to booking details
                            if (notification['related_id'] != null && notification['type'] == 'booking') {
                              // TODO: Navigate to booking details screen
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.white : const Color(0xFFEDF3FF),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A6FE3).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getNotificationIcon(notification['type']),
                                  color: const Color(0xFF4A6FE3),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                notification['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  color: const Color(0xFF324054),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    notification['message'] ?? '',
                                    style: TextStyle(
                                      color: const Color(0xFF324054).withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF324054).withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: !isRead
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4A6FE3),
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: const Color(0xFF324054).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when there\'s an update',
            style: TextStyle(
              color: const Color(0xFF324054).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'booking':
        return Icons.book_online;
      case 'payment':
        return Icons.payment;
      case 'system':
        return Icons.system_update;
      default:
        return Icons.notifications;
    }
  }
}