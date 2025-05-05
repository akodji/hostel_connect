import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'room_selection_screen.dart';
import 'package:url_launcher/url_launcher.dart';

final supabase = Supabase.instance.client;

class HostelDetailScreen extends StatefulWidget {
  final int hostelId;

  const HostelDetailScreen({
    Key? key,
    required this.hostelId,
  }) : super(key: key);

  @override
  _HostelDetailScreenState createState() => _HostelDetailScreenState();
}

class _HostelDetailScreenState extends State<HostelDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFavorite = false;
  int _userRating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isLoading = true;

  // Data structure to hold all hostel information
  Map<String, dynamic> _hostelData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHostelData();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('hostel_id', widget.hostelId);

      setState(() {
        _isFavorite = response.isNotEmpty;
      });
    } catch (error) {
      print('Error checking favorite status: $error');
    }
  }

  // Fix for review query in _loadHostelData method
Future<void> _loadHostelData() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // 1. Fetch the hostel details with email and phone
    final hostelResponse = await supabase
        .from('hostels')
        .select('*, email, phone')
        .eq('id', widget.hostelId)
        .single();

    // 2. Fetch hostel images
    List<String> images = [];
    if (hostelResponse['image_url'] != null) {
      images.add(hostelResponse['image_url']);
    }

    // 3. Fetch amenities
    final amenitiesResponse = await supabase
        .from('hostel_amenities')
        .select('amenity')
        .eq('hostel_id', widget.hostelId);
    
    // Process amenities
    List<Map<String, dynamic>> amenities = [];
    for (var amenity in amenitiesResponse) {
      IconData iconData;
      switch (amenity['amenity']) {
        case 'WiFi':
          iconData = Icons.wifi;
          break;
        case 'Study Room':
          iconData = Icons.menu_book;
          break;
        case 'Kitchen':
          iconData = Icons.kitchen;
          break;
        case 'Laundry':
          iconData = Icons.local_laundry_service;
          break;
        case 'Security':
          iconData = Icons.security;
          break;
        case 'Parking':
          iconData = Icons.local_parking;
          break;
        case 'Water Supply':
          iconData = Icons.water_drop;
          break;
        case 'Electricity':
          iconData = Icons.bolt;
          break;
        default:
          iconData = Icons.check_circle;
      }
      
      amenities.add({
        'name': amenity['amenity'],
        'icon': iconData,
      });
    }

    // 4. Fetch hostel rules
    final rulesResponse = await supabase
        .from('hostel_rules')
        .select('rule')
        .eq('hostel_id', widget.hostelId);
    
    List<String> rules = rulesResponse.map<String>((rule) => rule['rule'] as String).toList();

    // 5. Fetch room types with capacity
    final roomsResponse = await supabase
        .from('rooms')
        .select('name, room_number, price, capacity, available, description, image_url')
        .eq('hostel_id', widget.hostelId);
    
    // Process room types
    Map<String, Map<String, dynamic>> roomTypeMap = {};
    for (var room in roomsResponse) {
      final type = room['name'];
      if (!roomTypeMap.containsKey(type)) {
        roomTypeMap[type] = {
          'type': type,
          'price': room['price'],
          'capacity': room['capacity'],
          'available': room['available'],
          'description': room['description'],
        };
      } else if (room['price'] < roomTypeMap[type]!['price']) {
        roomTypeMap[type]!['price'] = room['price'];
        if (room['available']) {
          roomTypeMap[type]!['available'] = true;
        }
      }
    }
    List<Map<String, dynamic>> roomTypes = roomTypeMap.values.toList();

    // 6. Fetch reviews - FIXED: Use separate queries for reviews and profile info
    final reviewsResponse = await supabase
        .from('reviews')
        .select('id, hostel_id, user_id, rating, comment, created_at')
        .eq('hostel_id', widget.hostelId)
        .order('created_at', ascending: false);
    
    List<Map<String, dynamic>> reviews = [];
    double totalRating = 0;
    
    for (var review in reviewsResponse) {
      // Use separate query to get the profile information for this review
      String firstName = 'Anonymous';
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('first_name')
            .eq('id', review['user_id'])
            .maybeSingle();
            
        if (profileResponse != null && profileResponse['first_name'] != null) {
          firstName = profileResponse['first_name'];
        }
      } catch (e) {
        print('Error fetching profile for review: $e');
      }
      
      final createdAt = DateTime.parse(review['created_at']);
      final now = DateTime.now();
      final difference = now.difference(createdAt);
      
      String dateText;
      if (difference.inDays > 30) {
        dateText = '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        dateText = '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        dateText = '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        dateText = '${difference.inMinutes} minutes ago';
      } else {
        dateText = 'Just now';
      }
      
      totalRating += review['rating'];
      
      reviews.add({
        'user': firstName,
        'rating': review['rating'],
        'comment': review['comment'] ?? '',
        'date': dateText,
      });
    }
    
    final rating = reviews.isEmpty ? 0.0 : (totalRating / reviews.length);

    // 7. Combine all data including email and phone
    setState(() {
      _hostelData = {
        'id': hostelResponse['id'],
        'name': hostelResponse['name'],
        'images': images.isEmpty ? ['assets/images/hostel_placeholder.jpg'] : images,
        'rating': rating.toStringAsFixed(1),
        'reviewCount': reviews.length,
        'description': hostelResponse['description'],
        'price': hostelResponse['price'],
        'available': hostelResponse['available_rooms'] > 0,
        'amenities': amenities,
        'rules': rules,
        'roomTypes': roomTypes,
        'reviews': reviews,
        'location': hostelResponse['location'] ?? 'Unknown location',
        'address': hostelResponse['address'],
        'contact_info': hostelResponse['contact_info'] ?? 'No contact information provided',
        'email': hostelResponse['email'],
        'phone': hostelResponse['phone'],
      };
      _isLoading = false;
    });
  } catch (error) {
    print('Error loading hostel data: $error');
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading hostel data: $error')),
    );
  }
}

  void _shareHostel() {
    Share.share(
      'Check out ${_hostelData['name']} on North Campus! Starting from GH₵${_hostelData['price']} with great amenities. #HostelLife',
      subject: 'Check out this hostel!',
    );
  }

  void _navigateToRoomSelection(String? roomType, [int? capacity]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomSelectionScreen(
          hostelId: _hostelData['id'],
          roomType: roomType,
          capacity: capacity,
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a rating")),
      );
      return;
    }
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to leave a review")),
        );
        return;
      }
      
      // Make sure the comment is not null
      final comment = _reviewController.text.isNotEmpty ? _reviewController.text : null;
      
      await supabase.from('reviews').insert({
        'hostel_id': widget.hostelId,
        'user_id': userId,
        'rating': _userRating.toDouble(),
        'comment': comment,
      });
      
      _reviewController.clear();
      setState(() {
        _userRating = 0;
      });
      
      // Reload data after submitting review
      await _loadHostelData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted successfully")),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting review: $error")),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to save favorites")),
        );
        return;
      }
      
      setState(() {
        _isFavorite = !_isFavorite;
      });
      
      if (_isFavorite) {
        await supabase.from('favorites').insert({
          'user_id': userId,
          'hostel_id': widget.hostelId,
        });
      } else {
        await supabase.from('favorites')
            .delete()
            .match({'user_id': userId, 'hostel_id': widget.hostelId});
      }
    } catch (error) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating favorites: $error")),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _hostelData.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF324054)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : const Color(0xFF324054),
              ),
              onPressed: _toggleFavorite,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: Color(0xFF324054)),
              onPressed: _shareHostel,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Hostel Image Gallery
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: _hostelData['images'].length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      _hostelData['images'][index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _hostelData['images'].length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Hostel Details
          Expanded(
            flex: 8,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Hostel Name and Rating
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hostelData['name'],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xFF6C63FF),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _hostelData['location'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF324054).withOpacity(0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFFFFA726),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${_hostelData['rating']}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF324054),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "(${_hostelData['reviewCount']} reviews)",
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF324054).withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Availability and Price
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Availability
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _hostelData['available']
                                ? const Color(0xFF2DCE89).withOpacity(0.1)
                                : const Color(0xFFF75676).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _hostelData['available'] ? "Available" : "Full",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _hostelData['available']
                                  ? const Color(0xFF2DCE89)
                                  : const Color(0xFFF75676),
                            ),
                          ),
                        ),

                        // Price
                        Row(
                          children: [
                            Text(
                              "Starting from ",
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF324054).withOpacity(0.7),
                              ),
                            ),
                            Text(
                              "GH₵${_hostelData['roomTypes'].isNotEmpty ? _hostelData['roomTypes'].map((room) => room['price']).reduce((a, b) => a < b ? a : b) : 0}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A6FE3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF4A6FE3),
                    labelColor: const Color(0xFF4A6FE3),
                    unselectedLabelColor: const Color(0xFF324054).withOpacity(0.7),
                    tabs: const [
                      Tab(text: "Overview"),
                      Tab(text: "Rooms"),
                      Tab(text: "Reviews"),
                    ],
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Overview Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Description
                              const Text(
                                "Description",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _hostelData['description'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF324054).withOpacity(0.7),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Address
                              if (_hostelData['address'] != null) ...[
                                const Text(
                                  "Address",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF324054),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _hostelData['address'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF324054).withOpacity(0.7),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Contact Information
                              if (_hostelData['phone'] != null || _hostelData['email'] != null) ...[
                                const Text(
                                  "Contact Information",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF324054),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_hostelData['phone'] != null) ...[
                                  InkWell(
                                    onTap: () {
                                      final Uri telUrl = Uri(
                                        scheme: 'tel',
                                        path: _hostelData['phone'],
                                      );
                                      launchUrl(telUrl);
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.phone,
                                          color: Color(0xFF4A6FE3),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _hostelData['phone'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: const Color(0xFF324054).withOpacity(0.7),
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (_hostelData['email'] != null) ...[
                                  InkWell(
                                    onTap: () {
                                      final Uri emailUrl = Uri(
                                        scheme: 'mailto',
                                        path: _hostelData['email'],
                                      );
                                      launchUrl(emailUrl);
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.email,
                                          color: Color(0xFF4A6FE3),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _hostelData['email'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: const Color(0xFF324054).withOpacity(0.7),
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                              ],

                              // Amenities
                              const Text(
                                "Amenities",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.5,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: _hostelData['amenities'].length,
                                itemBuilder: (context, index) {
                                  final amenity = _hostelData['amenities'][index];
                                  return Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFF4A6FE3).withOpacity(0.1),
                                        child: Icon(
                                          amenity['icon'],
                                          color: const Color(0xFF4A6FE3),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          amenity['name'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF324054),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // Hostel Rules
                              const Text(
                                "Hostel Rules",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _hostelData['rules'].length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF4A6FE3),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _hostelData['rules'][index],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: const Color(0xFF324054).withOpacity(0.7),
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Rooms Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Available Room Types",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _hostelData['roomTypes'].length,
                                itemBuilder: (context, index) {
                                  final roomType = _hostelData['roomTypes'][index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.withOpacity(0.2),
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      roomType['type'],
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF324054),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: roomType['available']
                                                            ? const Color(0xFF2DCE89).withOpacity(0.1)
                                                            : const Color(0xFFF75676).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        roomType['available'] ? "Available" : "Full",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: roomType['available']
                                                              ? const Color(0xFF2DCE89)
                                                              : const Color(0xFFF75676),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      "GH₵${roomType['price']}",
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF4A6FE3),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      "per semester",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: const Color(0xFF324054).withOpacity(0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (roomType['description'] != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 8),
                                                    child: Text(
                                                      roomType['description'],
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: const Color(0xFF324054).withOpacity(0.7),
                                                      ),
                                                    ),
                                                  ),
                                                Text(
                                                  "${roomType['capacity']} in a room",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: const Color(0xFF324054).withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: ElevatedButton(
                                              onPressed: roomType['available']
                                                  ? () => _navigateToRoomSelection(roomType['type'], roomType['capacity'])
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF4A6FE3),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 2,
                                                shadowColor: const Color(0xFF4A6FE3).withOpacity(0.5),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.bedroom_parent_outlined, size: 18),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Select Room",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Reviews Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Reviews",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _hostelData['reviews'].length,
                                itemBuilder: (context, index) {
                                  final review = _hostelData['reviews'][index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
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
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                review['user'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF324054),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Color(0xFFFFA726),
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "${review['rating']}",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF324054),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            review['comment'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: const Color(0xFF324054).withOpacity(0.7),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            review['date'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: const Color(0xFF324054).withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              // Add review form
                              const SizedBox(height: 24),
                              const Text(
                                "Leave a Review",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
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
                                    // Rating selection
                                    const Text("Rating"),
                                    const SizedBox(height: 8),
                                    // Rating stars
                                    Row(
                                      children: List.generate(
                                        5,
                                        (index) => IconButton(
                                          icon: Icon(
                                            Icons.star,
                                            color: _userRating > index 
                                                ? const Color(0xFFFFA726) 
                                                : Colors.grey.withOpacity(0.3),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _userRating = index + 1;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Comment field
                                    TextField(
                                      controller: _reviewController,
                                      decoration: const InputDecoration(
                                        hintText: "Write your review here...",
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    // Submit button
                                    ElevatedButton(
                                      onPressed: _submitReview,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4A6FE3),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        minimumSize: const Size(double.infinity, 48),
                                        elevation: 2,
                                        shadowColor: const Color(0xFF4A6FE3).withOpacity(0.3),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.rate_review, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Submit Review",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Contact button
            Expanded(
              flex: 1,
              child: TextButton.icon(
                onPressed: _hostelData['phone'] != null
                    ? () {
                        final Uri telUrl = Uri(
                          scheme: 'tel',
                          path: _hostelData['phone'],
                        );
                        launchUrl(telUrl);
                      }
                    : null,
                icon: const Icon(Icons.phone, color: Color(0xFF4A6FE3)),
                label: const Text(
                  "Contact",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A6FE3),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF4A6FE3).withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Book Now button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _hostelData['available']
                    ? () => _navigateToRoomSelection(null, null)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6FE3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Book Now",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}