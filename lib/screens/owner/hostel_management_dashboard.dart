import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_edit_hostel_screen.dart';
import 'manage_hostels_screen.dart';
import 'owner_bookings_screen.dart';
import 'package:hostel_connect/screens/owner/reviews_page.dart';


final supabase = Supabase.instance.client;

class HostelOwnerDashboardScreen extends StatefulWidget {
  const HostelOwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  _HostelOwnerDashboardScreenState createState() => _HostelOwnerDashboardScreenState();
}

class _HostelOwnerDashboardScreenState extends State<HostelOwnerDashboardScreen> {
  bool _isLoading = true;
  int _totalHostels = 0;
  int _totalBookings = 0;
  int _pendingBookings = 0;
  int _confirmedBookings = 0;
  int _availableRooms = 0;
  int _onCampusHostels = 0;
  int _offCampusHostels = 0;
  

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get hostels count and details
      final hostelsResponse = await supabase
          .from('hostels')
          .select('id, name, location, campus_location')
          .eq('owner_id', userId);
      
      final hostels = hostelsResponse as List;
      if (hostels.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Get hostel IDs (they are integers in the database)
      final hostelIds = hostels.map((hostel) => hostel['id'] as int).toList();
      
      // Count hostels by campus location
      _onCampusHostels = hostels.where((hostel) => 
          hostel['campus_location'] == 'On Campus').length;
      _offCampusHostels = hostels.where((hostel) => 
          hostel['campus_location'] == 'Off Campus').length;
      
      // Get available rooms from rooms table
      final roomsResponse = await supabase
          .from('rooms')
          .select('id, hostel_id, available')
          .inFilter('hostel_id', hostelIds)
          .eq('available', true);
      
      final availableRooms = roomsResponse as List;
      
      // Get bookings
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id, price, status')
          .inFilter('hostel_id', hostelIds);
      
      final bookings = bookingsResponse as List;
      
      // Calculate pending and confirmed bookings
      final pendingBookings = bookings.where((booking) => 
          booking['status'] == 'pending').length;
      
      final confirmedBookings = bookings.where((booking) => 
          booking['status'] == 'confirmed').length;
      
      // Calculate total earnings from confirmed bookings
      
      
      setState(() {
        _totalHostels = hostels.length;
        _availableRooms = availableRooms.length;
        _totalBookings = bookings.length;
        _pendingBookings = pendingBookings;
        _confirmedBookings = confirmedBookings;
      
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          "Owner Dashboard",
          style: TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF324054)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Cards
                      Row(
                        children: [
                          _buildStatCard(
                            'Hostels',
                            _totalHostels.toString(),
                            Icons.apartment,
                            const Color(0xFF6C63FF),
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Available Rooms',
                            _availableRooms.toString(),
                            Icons.meeting_room,
                            const Color(0xFF2DCE89),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'Bookings',
                            _totalBookings.toString(),
                            Icons.book_online,
                            const Color(0xFFFFA726),
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Pending',
                            _pendingBookings.toString(),
                            Icons.pending_actions,
                            const Color(0xFFFF5630),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'Confirmed',
                            _confirmedBookings.toString(),
                            Icons.check_circle_outline,
                            const Color(0xFF36B37E),
                          ),
                          const SizedBox(width: 16),
                          
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'On Campus',
                            _onCampusHostels.toString(),
                            Icons.school,
                            const Color(0xFF6554C0),
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Off Campus',
                            _offCampusHostels.toString(),
                            Icons.home_work,
                            const Color(0xFF00875A),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Management Actions
                      const Text(
                        "Manage Your Business",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Add New Hostel Card
                      _buildActionCard(
                        'Add New Hostel',
                        'Create a new listing for your property',
                        Icons.add_business,
                        const Color(0xFF6C63FF),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddEditHostelScreen(),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Manage Hostels Card
                      _buildActionCard(
                        'Manage Hostels',
                        'View and edit your existing hostel listings',
                        Icons.edit_outlined,
                        const Color(0xFF2DCE89),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageHostelsScreen(),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // View Bookings Card
                      _buildActionCard(
                        'View Bookings',
                        'Manage all bookings for your hostels',
                        Icons.book_online,
                        const Color(0xFFFFA726),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OwnerBookingsScreen(),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
  'View Reviews',
  'Check customer reviews for your hostels',
  Icons.star_rate,
  const Color(0xFF8884D8),
  () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReviewsPage(),
      ),
    ).then((_) => _loadDashboardData());
  },
),
const SizedBox(height: 16),
                      
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF324054),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF324054).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324054),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF324054).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF324054),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}