import 'package:flutter/material.dart';
import 'package:hostel_connect/screens/owner/hostel_room_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostel_connect/widgets/offline_notification_banner.dart';
import 'package:hostel_connect/screens/student/profile_screen.dart';
import 'package:hostel_connect/screens/owner/owner_bookings_screen.dart';
import 'package:hostel_connect/screens/owner/hostel_management_dashboard.dart';
import 'package:hostel_connect/screens/owner/manage_hostels_screen.dart';
import 'package:hostel_connect/screens/owner/manage_rooms_screen.dart';
import 'package:hostel_connect/screens/owner/room_management_screen.dart';
import 'package:hostel_connect/screens/owner/add_edit_hostel_screen.dart';
import 'package:hostel_connect/screens/owner/add_edit_room_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({Key? key}) : super(key: key);

  @override
  _OwnerHomeScreenState createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _selectedIndex = 0;
  bool _isOffline = false;
  String _userName = "Owner";
  bool _isLoading = true;
  List<Map<String, dynamic>> _ownerHostels = [];
  List<Map<String, dynamic>> _dashboardStats = [];
  final List<Map<String, dynamic>> _recentBookings = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Load user profile data
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('first_name, last_name')
            .eq('id', userId)
            .single();

        // Load hostels data
        final hostelsResponse = await Supabase.instance.client
            .from('hostels')
            .select('id, name, description, address, campus_location, location, price, available_rooms, image_url')
            .eq('owner_id', userId)
            .order('created_at', ascending: false);
        
        // Process each hostel to get its specific data
        List<Map<String, dynamic>> processedHostels = [];
        int totalRooms = 0;
        int totalOccupiedRooms = 0;
        
        for (var hostel in hostelsResponse) {
          final hostelId = hostel['id'];
          
          // Get all rooms for this hostel
          final roomsResponse = await Supabase.instance.client
              .from('rooms')
              .select('id, available')
              .eq('hostel_id', hostelId);
              
          final rooms = roomsResponse as List;
          final hostelRoomCount = rooms.length;
          totalRooms += hostelRoomCount;
          
          // Count non-available rooms as occupied
          final occupiedRooms = rooms.where((room) => room['available'] == false).length;
          totalOccupiedRooms += occupiedRooms;
          
          // Calculate occupancy rate for this specific hostel
          final occupancyRate = hostelRoomCount > 0 ? (occupiedRooms / hostelRoomCount) * 100 : 0;
          
          // Get pending bookings count
          final pendingBookingsResponse = await Supabase.instance.client
              .from('bookings')
              .select('id')
              .eq('hostel_id', hostelId)
              .eq('status', 'pending');
              
          final pendingBookings = (pendingBookingsResponse as List).length;
          
          // Add processed hostel data
          processedHostels.add({
            'id': hostel['id'].toString(),
            'name': hostel['name'],
            'image': hostel['image_url'] ?? 'assets/images/hostel_placeholder.jpg',
            'rating': 4.5, // Default rating or calculate from reviews if available
            'location': hostel['location'] ?? hostel['campus_location'],
            'price': hostel['price'],
            'available': hostel['available_rooms'] > 0,
            'occupancy_rate': '${occupancyRate.toStringAsFixed(0)}%',
            'pending_bookings': pendingBookings,
            'total_rooms': hostelRoomCount,
          });
        }
        
        // Calculate overall occupancy rate
        final overallOccupancyRate = totalRooms > 0 ? (totalOccupiedRooms / totalRooms) * 100 : 0;

        if (mounted) {
          setState(() {
            _userName = profileResponse['first_name'] ?? "Owner";
            _ownerHostels = processedHostels;
            _isLoading = false;
            
            // Update dashboard stats with the calculated values
            _dashboardStats = [
              {'label': 'Total Hostels', 'value': processedHostels.length.toString(), 'icon': Icons.domain, 'color': Color(0xFF6C63FF)},
              {'label': 'Total Rooms', 'value': totalRooms.toString(), 'icon': Icons.meeting_room, 'color': Color(0xFF4ECDC4)},
              {'label': 'Occupancy', 'value': '${overallOccupancyRate.toStringAsFixed(0)}%', 'icon': Icons.person, 'color': Color(0xFF2DCE89)},
            ];
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<int> _getHostelRoomCount(int hostelId) async {
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select('id')
          .eq('hostel_id', hostelId);
      
      return (response as List).length;
    } catch (e) {
      print('Error getting room count: $e');
      return 0;
    }
  }

  int _getOccupiedRoomCount(int totalRooms, String occupancyRateStr) {
    final occupancyStr = occupancyRateStr.replaceAll('%', '');
    final occupancyRate = double.tryParse(occupancyStr) ?? 0;
    return ((totalRooms * occupancyRate) / 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  if (_isOffline) const OfflineNotificationBanner(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderSection(),
                          const SizedBox(height: 24),
                          _buildDashboardStatsSection(),
                          const SizedBox(height: 24),
                          _buildQuickActionsSection(),
                          const SizedBox(height: 24),
                          _buildPropertiesSection(),
                          const SizedBox(height: 24),
                          _buildRecentBookingsSection(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $_userName",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324054),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Manage your hostel properties",
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF324054).withOpacity(0.7),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Container(
              width: 48,
              height: 48,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/profile.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      color: Color(0xFF4A6FE3),
                      size: 32,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Dashboard Overview",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: _dashboardStats.length,
            itemBuilder: (context, index) {
              final stat = _dashboardStats[index];
              return _buildStatCard(
                stat['label'],
                stat['value'],
                stat['icon'],
                stat['color'],
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HostelOwnerDashboardScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6FE3),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "View Full Dashboard",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
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
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
            children: [
              _buildQuickActionItem(
  Icons.add_business_outlined,
  "Add Hostel",
  const Color(0xFF6C63FF),
  () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditHostelScreen()),
    ).then((_) {
      _loadUserData();
    });
  },
),
              _buildQuickActionItem(
                Icons.add_circle_outline,
                "Add Room",
                const Color(0xFF4ECDC4),
                () {
                  if (_ownerHostels.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditRoomScreen(
                          hostelId: int.parse(_ownerHostels[0]['id']),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You need to create a hostel first'),
                      ),
                    );
                  }
                },
              ),
              _buildQuickActionItem(
                Icons.domain_outlined,
                "Manage Hostels",
                const Color(0xFFFFA726),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageHostelsScreen()),
                  );
                },
              ),
              _buildQuickActionItem(
                Icons.meeting_room_outlined,
                "Manage Rooms",
                const Color(0xFF2DCE89),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageRoomsScreen()),
                  );
                },
              ),
              _buildQuickActionItem(
                Icons.book_outlined,
                "Bookings",
                const Color(0xFFF75676),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OwnerBookingsScreen()),
                  );
                },
              ),
              _buildQuickActionItem(
                Icons.analytics_outlined,
                "Dashboard",
                const Color(0xFF9D65C9),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HostelOwnerDashboardScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF324054),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Your Properties",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324054),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageHostelsScreen()),
                  );
                },
                child: const Text(
                  "See All",
                  style: TextStyle(
                    color: Color(0xFF4A6FE3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ownerHostels.isEmpty
              ? _buildNoPropertiesMessage()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ownerHostels.length > 2 ? 2 : _ownerHostels.length,
                  itemBuilder: (context, index) {
                    final hostel = _ownerHostels[index];
                    return _buildPropertyCard(hostel);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildNoPropertiesMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.home_work_outlined,
            size: 48,
            color: Color(0xFF4A6FE3),
          ),
          const SizedBox(height: 16),
          const Text(
            "No properties added yet",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your first hostel property to start managing it here",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddEditHostelScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6FE3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Add Hostel"),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> hostel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HostelRoomsScreen(
                hostel: hostel,
              ),
            ),
          ).then((_) {
            _loadUserData();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: hostel['image'].startsWith('http') || hostel['image'].startsWith('assets')
                  ? Image.network(
                      hostel['image'].startsWith('assets') ? 'assets/images/hostel_placeholder.jpg' : hostel['image'],
                      width: 100,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder();
                      },
                    )
                  : Image.asset(
                      hostel['image'],
                      width: 100,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder();
                      },
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hostel['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324054),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Color(0xFF4A6FE3),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hostel['location'],
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF324054).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<int>(
                      future: _getHostelRoomCount(int.parse(hostel['id'])),
                      builder: (context, snapshot) {
                        final roomCount = snapshot.data ?? 0;
                        final occupiedCount = _getOccupiedRoomCount(roomCount, hostel['occupancy_rate']);
                        
                        return Row(
                          children: [
                            _buildPropertyStat("Occupancy", hostel['occupancy_rate']),
                            const SizedBox(width: 16),
                            _buildPropertyStat("Rooms", "$roomCount"),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFFFA726),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${hostel['rating']}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324054),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              "${hostel['price']}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A6FE3),
                              ),
                            ),
                            Text(
                              "/sem",
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF324054).withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 100,
      height: 120,
      color: const Color(0xFFF1F3F6),
      child: const Icon(
        Icons.domain,
        color: Color(0xFF4A6FE3),
        size: 40,
      ),
    );
  }

  Widget _buildPropertyStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBookingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Bookings",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324054),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OwnerBookingsScreen()),
                  );
                },
                child: const Text(
                  "See All",
                  style: TextStyle(
                    color: Color(0xFF4A6FE3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentBookings.length,
            itemBuilder: (context, index) {
              final booking = _recentBookings[index];
              return _buildRecentBookingItem(
                booking['student_name'],
                booking['room_details'],
                booking['date'],
                booking['status'],
                booking['status_color'],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBookingItem(
    String studentName,
    String roomDetails,
    String date,
    String status,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF4A6FE3),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324054),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roomDetails,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF324054).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF324054).withOpacity(0.6),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _handleNavigation(index);
        },
        selectedItemColor: const Color(0xFF4A6FE3),
        unselectedItemColor: const Color(0xFF324054).withOpacity(0.5),
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.domain_outlined),
            activeIcon: Icon(Icons.domain),
            label: 'Hostels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }

  void _handleNavigation(int index) {
    if (index == 0) {
      // Already on home screen, do nothing
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ManageHostelsScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OwnerBookingsScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HostelOwnerDashboardScreen()),
      );
    }
  }
}