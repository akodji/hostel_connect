import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import './hostel_room_screen.dart';

final supabase = Supabase.instance.client;

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({Key? key}) : super(key: key);

  @override
  _OwnerBookingsScreenState createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  late TabController _tabController;
  
  final Map<String, Color> _statusColors = {
    'pending': const Color(0xFFFFA726),
    'confirmed': const Color(0xFF2DCE89),
    'active': const Color(0xFF4A6FE3),
    'completed': const Color(0xFF6C63FF),
    'cancelled': const Color(0xFFF75676),
    'rejected': const Color(0xFFF75676), // Added rejected status
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<void> _loadBookings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get all hostels owned by the current user
      final hostelsResponse = await supabase
          .from('hostels')
          .select('id')
          .eq('owner_id', userId);
      
      if (hostelsResponse == null || (hostelsResponse as List).isEmpty) {
        setState(() {
          _bookings = [];
          _isLoading = false;
        });
        return;
      }
      
      final hostelIds = hostelsResponse.map((hostel) => hostel['id']).toList();
      
      // Get all bookings for the hostels owned by the current user
      // Fix: Using a simpler query without trying to join the auth.users table
      final bookingsResponse = await supabase
        .from('bookings')
        .select('''
          *,
          hostels:hostel_id(id, name, location, image_url),
          rooms:room_id(id, name, capacity, price)
        ''')
        .inFilter('hostel_id', hostelIds)
        .order('created_at', ascending: false);
      
      // Fetch additional profile information separately
      List<Map<String, dynamic>> bookingsWithProfiles = [];
      for (var booking in bookingsResponse) {
        if (booking['user_id'] != null) {
          // Get profile data for the user from profiles table
          try {
            final profileResponse = await supabase
                .from('profiles') // Your profiles table
                .select('first_name, last_name, phone, email')
                .eq('id', booking['user_id'])
                .maybeSingle();
            
            // Create a profiles object with the data we have
            booking['profiles'] = {
              'id': booking['user_id'],
              'email': profileResponse?['email'] ?? 'No email',
              'first_name': profileResponse?['first_name'] ?? 'Unknown',
              'last_name': profileResponse?['last_name'] ?? 'Guest',
              'phone': profileResponse?['phone'] ?? '',
            };
          } catch (e) {
            print('Error fetching profile for user ${booking['user_id']}: $e');
            // Create a default profiles object
            booking['profiles'] = {
              'id': booking['user_id'],
              'email': 'No email',
              'first_name': 'Unknown',
              'last_name': 'Guest',
              'phone': '',
            };
          }
        } else {
          // Handle case where user_id is null
          booking['profiles'] = {
            'id': 'unknown',
            'email': 'No email',
            'first_name': 'Unknown',
            'last_name': 'Guest', 
            'phone': '',
          };
        }
        
        bookingsWithProfiles.add(booking);
      }
        
      setState(() {
        _bookings = bookingsWithProfiles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load bookings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBookingStatus(int bookingId, String newStatus) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // First, fetch the current booking to check its status
    final currentBooking = await supabase
        .from('bookings')
        .select('status')
        .eq('id', bookingId)
        .single();
        
    // If the booking status is already what we're trying to set it to, just return
    if (currentBooking['status'] == newStatus) {
      // Close loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking is already in this status'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Use RPC function to update booking status
    await supabase.rpc(
      'update_booking_status',
      params: {
        'booking_id': bookingId,
        'new_status': newStatus
      },
    );
    
    // Close loading dialog
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking status updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Reload bookings to reflect changes
    _loadBookings();
  } catch (e) {
    // Close loading dialog if still open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('Error updating booking status: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to update booking status: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  List<Map<String, dynamic>> _getFilteredBookings(String status) {
    if (status == 'all') {
      return _bookings;
    }
    return _bookings.where((booking) => booking['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          "Manage Bookings",
          style: TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF324054)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A6FE3),
          unselectedLabelColor: const Color(0xFF666666),
          indicatorColor: const Color(0xFF4A6FE3),
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Pending"),
            Tab(text: "Confirmed"),
            Tab(text: "Active"),
            Tab(text: "Completed"),
          ],
          isScrollable: true,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBookingsList('all'),
                  _buildBookingsList('pending'),
                  _buildBookingsList('confirmed'),
                  _buildBookingsList('active'),
                  _buildBookingsList('completed'),
                ],
              ),
            ),
    );
  }

  Widget _buildBookingsList(String status) {
    final filteredBookings = _getFilteredBookings(status);
    
    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.book_online,
              size: 80,
              color: Color(0xFFCCCCCC),
            ),
            const SizedBox(height: 16),
            Text(
              status == 'all' ? "No bookings found" : "No $status bookings",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF324054),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBookings.length,
      itemBuilder: (context, index) {
        final booking = filteredBookings[index];
        
        // Safely access nested objects with null checks - this is the key fix
        final hostel = booking['hostels'] != null 
            ? booking['hostels'] as Map<String, dynamic> 
            : {'name': 'Unknown Hostel', 'location': 'Unknown Location'};
            
        final room = booking['rooms'] != null 
            ? booking['rooms'] as Map<String, dynamic> 
            : {'name': 'Unknown Room', 'capacity': 'N/A', 'price': 0.0};
            
        final guest = booking['profiles'] != null 
            ? booking['profiles'] as Map<String, dynamic> 
            : {'first_name': 'Unknown', 'last_name': 'Guest', 'email': '', 'phone': ''};
        
        // Safely parse dates with null checks
        final moveInDate = booking['move_in_date'] != null 
            ? DateTime.parse(booking['move_in_date']) 
            : DateTime.now();
            
        final createdAt = booking['created_at'] != null 
            ? DateTime.parse(booking['created_at']) 
            : DateTime.now();
            
        // Safely parse price with null checks
        final price = booking['price'] is String 
            ? double.tryParse(booking['price']) ?? 0.0 
            : (booking['price'] as num?)?.toDouble() ?? 0.0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with hostel name and booking status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6FE3).withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hostel['name'] ?? 'Unknown Hostel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_statusColors[booking['status']] ?? Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        booking['status']?.toUpperCase() ?? 'UNKNOWN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _statusColors[booking['status']] ?? Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Booking details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room info
                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 16,
                          color: Color(0xFF666666),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Room: ${room['name'] ?? 'Unknown'} (Capacity: ${room['capacity'] ?? 'N/A'})",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF324054),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Guest info
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Color(0xFF666666),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF324054),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Contact info
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Color(0xFF666666),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            guest['email'] ?? 'No email',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (guest['phone'] != null && guest['phone'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: Color(0xFF666666),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              guest['phone'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    
                    // Notes if available
                    if (booking['notes'] != null && booking['notes'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Notes:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                booking['notes'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF324054),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Divider
                    const Divider(),
                    const SizedBox(height: 12),
                    
                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Booking Date",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy').format(createdAt),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF324054),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Move-in Date",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy').format(moveInDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF324054),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Payment info
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 16,
                          color: Color(0xFF666666),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "₵${price.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A6FE3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Action buttons based on booking status
                    _buildActionButtons(booking),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? '';
    
    switch (status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateBookingStatus(booking['id'], 'confirmed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DCE89),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Confirm"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateBookingStatus(booking['id'], 'rejected'), // Changed to 'rejected'
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF75676),
                  side: const BorderSide(color: Color(0xFFF75676)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Reject"),
              ),
            ),
          ],
        );
      case 'confirmed':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _updateBookingStatus(booking['id'], 'active'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6FE3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Mark as Active"),
          ),
        );
      case 'active':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _updateBookingStatus(booking['id'], 'completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Mark as Completed"),
          ),
        );
      case 'completed':
        return const Center(
          child: Text(
            "This booking has been completed",
            style: TextStyle(
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'cancelled':
        return const Center(
          child: Text(
            "This booking has been cancelled",
            style: TextStyle(
              color: Color(0xFFF75676),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'rejected':
        return const Center(
          child: Text(
            "This booking has been rejected",
            style: TextStyle(
              color: Color(0xFFF75676),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}