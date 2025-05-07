import 'package:flutter/material.dart';
import 'package:hostel_connect/screens/student/room_selection_screen.dart';
import 'package:hostel_connect/widgets/hostel_card.dart';
import 'package:hostel_connect/widgets/offline_notification_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hostel_list_screen.dart';
import 'profile_screen.dart';
import 'offline_bookings_screen.dart';
import 'bookings_screen.dart';
import 'package:hostel_connect/screens/owner/owner_bookings_screen.dart';
import 'package:hostel_connect/screens/owner/analytics_screen.dart';
import 'package:hostel_connect/screens/student/favourites_screen.dart';
import 'package:hostel_connect/services/local_database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  bool _isOffline = false;
  bool _isOwner = false;
  
  
  
  // Database-backed variables
  List<Map<String, dynamic>> _allHostels = []; // Store all hostels
  List<Map<String, dynamic>> _filteredHostels = []; // Store filtered hostels
  List<Map<String, dynamic>> _roomTypes = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Add listener to search controller
    _searchController.addListener(_filterHostels);
  }

  @override
  void dispose() {
    // Remove listener before disposing
    _searchController.removeListener(_filterHostels);
    _searchController.dispose();
    super.dispose();
  }

  // Filter hostels based on search query
  void _filterHostels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredHostels = _allHostels;
      } else {
        _filteredHostels = _allHostels.where((hostel) {
          return hostel['name'].toString().toLowerCase().contains(query) ||
                 hostel['location'].toString().toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      await Future.wait([
        _checkUserType(),
        _loadUserData(),
        _loadAllHostels(),
        _loadRoomTypes(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkUserType() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('user_type')
            .eq('id', userId)
            .single();

        if (mounted && response != null) {
          setState(() {
            _isOwner = response['user_type'] == 'owner';
          });
        }
      } catch (e) {
        print('Error checking user type: $e');
      }
    }
  }

  Future<void> _loadUserData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .single();

        if (mounted && response != null) {
          setState(() {
            _userData = response;
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadAllHostels() async {
    try {
      print('Fetching all hostels...');
      final response = await Supabase.instance.client
          .from('hostels')
          .select('id, name, image_url, price, location, available_rooms')
          .order('created_at', ascending: false);

      print('Hostels response raw: ${response.toString()}');
      
      if (response == null || response.isEmpty) {
        print('No hostels found in database');
        return;
      }

      // Process each hostel - fetch ratings and prepare data
      final processedHostels = <Map<String, dynamic>>[];
      
      for (var hostel in response) {
        print('Processing hostel: ${hostel['name']}');
        
        try {
          // Check for available rooms in the rooms table
          final roomsResponse = await Supabase.instance.client
              .from('rooms')
              .select('id')
              .eq('hostel_id', hostel['id'])
              .eq('available', true);
          
          bool hasAvailableRooms = roomsResponse != null && roomsResponse.isNotEmpty;
          print('Hostel ${hostel['id']} has available rooms: $hasAvailableRooms');
          
          // Add ratings from reviews table with an average calculation
          final reviewsResponse = await Supabase.instance.client
              .from('reviews')
              .select('rating')
              .eq('hostel_id', hostel['id']);
          
          print('Reviews for ${hostel['id']}: ${reviewsResponse?.length ?? 0}');
          
          double averageRating = 0;
          if (reviewsResponse != null && reviewsResponse.isNotEmpty) {
            double totalRating = 0;
            for (var review in reviewsResponse) {
              totalRating += (review['rating'] as num).toDouble();
            }
            averageRating = totalRating / reviewsResponse.length;
          }
          
          // Copy and enhance hostel data
          final processedHostel = Map<String, dynamic>.from(hostel);
          processedHostel['rating'] = averageRating;
          processedHostel['available'] = hasAvailableRooms; // Use actual availability from rooms table
          processedHostel['image'] = hostel['image_url']; // Map to match the widget's expected property
          
          processedHostels.add(processedHostel);
        } catch (e) {
          print('Error processing hostel ${hostel['id']}: $e');
        }
      }

      print('Processed hostels: ${processedHostels.length}');
      
      if (mounted) {
        setState(() {
          _allHostels = processedHostels;
          _filteredHostels = processedHostels;
        });
      }
    } catch (e) {
      print('Error loading hostels: $e');
      setState(() {
        _errorMessage = 'Failed to load hostels: $e';
      });
    }
  }

  Future<void> _loadRoomTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select('name, description, price, image_url')
          .order('price')
          .limit(4);
      
      print('Room types response: ${response?.length ?? 0}');
      
      if (mounted && response != null) {
        setState(() {
          _roomTypes = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading room types: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Offline notification banner if not connected
                if (_isOffline) const OfflineNotificationBanner(),

                // Top Section with User Greeting and Profile
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, ${_userData != null ? _userData!['first_name'] ?? 'User' : 'User'}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF324054),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Find your perfect hostel room",
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
                            MaterialPageRoute(
                                builder: (context) => const ProfileScreen()),
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
                            child: _userData != null && _userData!['avatar_url'] != null
                                ? Image.network(
                                    _userData!['avatar_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Color(0xFF4A6FE3),
                                        size: 32,
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Color(0xFF4A6FE3),
                                    size: 32,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search hostels",
                        hintStyle: TextStyle(
                          color: const Color(0xFF324054).withOpacity(0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: const Color(0xFF324054).withOpacity(0.7),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: const Color(0xFF324054).withOpacity(0.7),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : Icon(
                                Icons.filter_list,
                                color: const Color(0xFF324054).withOpacity(0.7),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (value) {
                        // This will trigger the listener we added
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Featured Hostels Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSearching ? "Search Results" : "Featured Hostels",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      Row(
                        children: [
                          // Debug button
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                icon: const Icon(Icons.info_outline, color: Colors.red),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_errorMessage),
                                      duration: const Duration(seconds: 10),
                                      action: SnackBarAction(
                                        label: 'Retry',
                                        onPressed: _loadData,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HostelListScreen()),
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Featured Hostels Horizontal List
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4A6FE3),
                        ),
                      )
                    : SizedBox(
                        height: 220,
                        child: _filteredHostels.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isSearching 
                                          ? "No hostels match your search" 
                                          : "No hostels available",
                                      style: TextStyle(
                                        color: const Color(0xFF324054).withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (!_isSearching)
                                      ElevatedButton(
                                        onPressed: _loadData,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4A6FE3),
                                        ),
                                        child: const Text(
                                          "Retry",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                scrollDirection: Axis.horizontal,
                                itemCount: _filteredHostels.length,
                                itemBuilder: (context, index) {
                                  final hostel = _filteredHostels[index];
                                  return HostelCard(
                                    id: hostel['id'].toString(),
                                    name: hostel['name'] ?? 'Unnamed Hostel',
                                    image: hostel['image_url'] ?? 'assets/images/hostel_placeholder.jpg',
                                    rating: (hostel['rating'] ?? 0.0).toDouble(),
                                    location: hostel['location'] ?? 'Unknown',
                                    price: hostel['price'] ?? 0,
                                    available: hostel['available'] ?? false,
                                  );
                                },
                              ),
                      ),
                const SizedBox(height: 32),

                // Only show the rest of the UI if not searching
                if (!_isSearching) ...[
                  // Quick Actions Section
                  Padding(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             _buildQuickActionItem(
                              context,
                              Icons.bed_outlined,
                              "Browse Hostels",
                              const Color(0xFF6C63FF),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const HostelListScreen()),
                                );
                              },
                            ),
                            _buildQuickActionItem(
                              context,
                              Icons.calendar_today_outlined,
                              "My Bookings",
                              const Color(0xFF2DCE89),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => _isOwner
                                          ? const OwnerBookingsScreen()
                                          : const BookingsScreen()),
                                );
                              },
                            ),
                            _buildQuickActionItem(
                              context,
                              Icons.favorite_outline,
                              "Favorites",
                              const Color(0xFFFFA726),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                                );
                              },
                            ),
                            _isOwner
                                ? _buildQuickActionItem(
                                    context,
                                    Icons.analytics_outlined,
                                    "Analytics",
                                    const Color(0xFF4A6FE3),
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const AnalyticsScreen()),
                                      );
                                    },
                                  )
                                : _buildQuickActionItem(
                                    context,
                                    Icons.meeting_room_outlined,
                                    "Book Room",
                                    const Color(0xFFF75676),
                                    () {
                                      if (_allHostels.isNotEmpty) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                   RoomSelectionScreen(
                                                     hostelId: _allHostels.first['id'],
                                                   )),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('No hostels available for booking')),
                                        );
                                      }
                                    },
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Notifications or Announcements
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A6FE3), Color(0xFF6C63FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.campaign_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Hostel Registration Open",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Room selection for the new semester starts soon. Book early!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Room Types Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Room Types",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324054),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4A6FE3),
                                ),
                              )
                            : _roomTypes.isEmpty
                                ? Center(
                                    child: Text(
                                      "No room types available",
                                      style: TextStyle(
                                        color: const Color(0xFF324054).withOpacity(0.7),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.8,
                                    ),
                                    itemCount: _roomTypes.length,
                                    itemBuilder: (context, index) {
                                      final room = _roomTypes[index];
                                      return _buildRoomTypeCard(
                                        room['name'] ?? 'Room',
                                        room['description'] ?? 'No description',
                                        room['price']?.toString() ?? '0',
                                        room['image_url'] ?? 'assets/images/room_placeholder.jpg',
                                      );
                                    },
                                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
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

            // Handle navigation to different screens based on index
            if (index == 1) {
              // Explore tab
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HostelListScreen()),
              );
            } else if (index == 2) {
              // Bookings tab
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => _isOwner
                        ? const OwnerBookingsScreen()
                        : const BookingsScreen()),
              );
            } else if (index == 3) {
              // Profile tab
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            }
            // Index 0 is Home, no navigation needed since we're already here
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
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border_outlined),
              activeIcon: Icon(Icons.bookmark),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF324054),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTypeCard(
    String title,
    String description,
    String price,
    String imagePath,
  ) {
    return GestureDetector(
      onTap: () {
        // Navigate to RoomSelectionScreen when a room type is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoomSelectionScreen(
              hostelId: _allHostels.isNotEmpty ? _allHostels.first['id'] : 0, // Default or first hostel
              roomType: title,
            ),
          ),
        );
      },
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
          children: [
            // Room Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imagePath,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: const Color(0xFFF1F3F6),
                    child: Icon(
                      Icons.hotel,
                      size: 40,
                      color: const Color(0xFF324054).withOpacity(0.5),
                    ),
                  );
                },
              ),
            ),

            // Room Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324054),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF324054).withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "₵$price",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A6FE3),
                        ),
                      ),
                      const Text(
                        "per semester",
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF324054),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}