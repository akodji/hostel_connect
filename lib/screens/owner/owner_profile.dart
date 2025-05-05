import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      // First, get all hostels owned by the user
      final hostelsResponse = await supabase
          .from('hostels')
          .select('id')
          .eq('owner_id', userId);
      
      final hostelIds = (hostelsResponse as List).map((hostel) => hostel['id']).toList();
      
      if (hostelIds.isNotEmpty) {
        // Get all bookings for these hostels with hostel and user information
        final bookingsResponse = await supabase
          .from('bookings')
          .select('''
            *,
            hostels:hostel_id(id, name, location, image_url),
            profiles:user_id(id, first_name, last_name, email, phone)
          ''')
          .eq('hostel_id', hostelIds)
          .order('created_at', ascending: false);
            
        setState(() {
          _bookings = bookingsResponse as List<Map<String, dynamic>>;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBookingStatus(int bookingId, String newStatus) async {
    try {
      await supabase
          .from('bookings')
          .update({'status': newStatus})
          .eq('id', bookingId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadBookings();
    } catch (e) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Refresh bookings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A6FE3),
          unselectedLabelColor: const Color(0xFF666666),
          indicatorColor: const Color(0xFF4A6FE3),
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Pending"),
            Tab(text: "Active"),
            Tab(text: "Completed"),
          ],
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
        final hostel = booking['hostels'] as Map<String, dynamic>;
        final guest = booking['profiles'] as Map<String, dynamic>;
        final bookingDate = DateTime.parse(booking['created_at'] ?? booking['booking_date']);
        final checkInDate = DateTime.parse(booking['check_in_date'] ?? booking['move_in_date']);
        final checkOutDate = booking['check_out_date'] != null 
            ? DateTime.parse(booking['check_out_date'])
            : null;
        
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
                                DateFormat('MMM dd, yyyy').format(bookingDate),
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
                                DateFormat('MMM dd, yyyy').format(checkInDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF324054),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (checkOutDate != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Move-out Date",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(checkOutDate),
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
                          "₦${booking['price']?.toStringAsFixed(2) ?? booking['amount']?.toStringAsFixed(2) ?? '0.00'}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A6FE3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: booking['payment_status'] == 'paid'
                                ? const Color(0xFF2DCE89).withOpacity(0.1)
                                : const Color(0xFFFFA726).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            booking['payment_status']?.toUpperCase() ?? 'PENDING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: booking['payment_status'] == 'paid'
                                  ? const Color(0xFF2DCE89)
                                  : const Color(0xFFFFA726),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Notes if available
                    if (booking['notes'] != null && booking['notes'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Notes",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                booking['notes'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    if (booking['status'] == 'pending')
                      Row(
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
                              onPressed: () => _updateBookingStatus(booking['id'], 'cancelled'),
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
                      ),
                    if (booking['status'] == 'confirmed')
                      SizedBox(
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
                      ),
                    if (booking['status'] == 'active')
                      SizedBox(
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
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}