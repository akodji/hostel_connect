import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../student/hostel_detail_screen.dart';
import 'add_edit_hostel_screen.dart';

class SearchHostelsScreen extends StatefulWidget {
  const SearchHostelsScreen({Key? key}) : super(key: key);

  @override
  State<SearchHostelsScreen> createState() => _SearchHostelsScreenState();
}

class _SearchHostelsScreenState extends State<SearchHostelsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<dynamic> _hostels = [];
  List<dynamic> _filteredHostels = [];
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCampusLocation = 'All';
  RangeValues _priceRange = const RangeValues(0, 5000);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchAllHostels();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredHostels = _hostels.where((hostel) {
        // Apply text search
        final matchesQuery = query.isEmpty ||
            hostel['name'].toString().toLowerCase().contains(query) ||
            hostel['address'].toString().toLowerCase().contains(query) ||
            hostel['description'].toString().toLowerCase().contains(query);
        
        // Apply campus location filter
        final matchesCampus = _selectedCampusLocation == 'All' ||
            hostel['campus_location'] == _selectedCampusLocation;
        
        // Apply price range filter
        final price = hostel['price'] as int;
        final matchesPrice = price >= _priceRange.start && price <= _priceRange.end;
        
        return matchesQuery && matchesCampus && matchesPrice;
      }).toList();
    });
  }

  Future<void> _fetchAllHostels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Fetch all hostels - public data endpoint
      final response = await supabase
          .from('hostels')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _hostels = response;
        _filteredHostels = List.from(_hostels);
        
        // Find max price for range slider
        if (_hostels.isNotEmpty) {
          double maxPrice = 0;
          for (var hostel in _hostels) {
            if (hostel['price'] > maxPrice) {
              maxPrice = (hostel['price'] as int).toDouble();
            }
          }
          // Add some buffer to the max price
          _priceRange = RangeValues(0, maxPrice * 1.2);
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load hostels: $e";
        _isLoading = false;
      });
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Wrap(
                children: [
                  // Title
                  const Center(
                    child: Text(
                      'Filter Hostels',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324054),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  
                  // Campus Location Filter
                  const Text(
                    'Campus Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324054),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      _buildLocationChip('All', setModalState),
                      _buildLocationChip('On Campus', setModalState),
                      _buildLocationChip('Off Campus', setModalState),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Price Range Filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Price Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      Text(
                        '₵${_priceRange.start.round()} - ₵${_priceRange.end.round()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A6FE3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 10000, // Adjust based on your data
                    divisions: 20,
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        _priceRange = values;
                      });
                    },
                    activeColor: const Color(0xFF4A6FE3),
                    inactiveColor: const Color(0xFF4A6FE3).withOpacity(0.2),
                  ),
                  const SizedBox(height: 24),
                  
                  // Apply Filter Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A6FE3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Reset Filters Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedCampusLocation = 'All';
                          _priceRange = RangeValues(0, 5000);
                        });
                      },
                      child: const Text(
                        'Reset Filters',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationChip(String location, StateSetter setModalState) {
    final isSelected = _selectedCampusLocation == location;
    
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedCampusLocation = location;
        });
      },
      child: Chip(
        label: Text(location),
        backgroundColor: isSelected ? const Color(0xFF4A6FE3) : Colors.grey[200],
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Navigate to hostel details screen
  void _navigateToHostelDetails(Map<String, dynamic> hostel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostelDetailScreen(hostelId: hostel['id']),
      ),
    );
  }

  // Navigate to edit hostel screen if user is the owner
  Future<void> _navigateToEditHostel(Map<String, dynamic> hostel) async {
    final currentUser = supabase.auth.currentUser;
    
    // Check if user is logged in and is the owner of the hostel
    if (currentUser == null || currentUser.id != hostel['owner_id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit hostels you own.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditHostelScreen(hostelData: hostel),
      ),
    );
    
    // Refresh the list if the hostel was updated
    if (result == true) {
      _fetchAllHostels();
    }
  }

  // Check if current user is the owner of a hostel
  bool _isHostelOwner(Map<String, dynamic> hostel) {
    final currentUser = supabase.auth.currentUser;
    return currentUser != null && currentUser.id == hostel['owner_id'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'Find Hostels',
          style: TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF324054)),
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search hostels...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF4A6FE3)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        isDense: true,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6FE3),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: _showFilterDialog,
                  ),
                ),
              ],
            ),
          ),
          
          // Results count and info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Found ${_filteredHostels.length} hostels',
                  style: const TextStyle(
                    color: Color(0xFF324054),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _fetchAllHostels,
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 16, color: Color(0xFF4A6FE3)),
                      SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          color: Color(0xFF4A6FE3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Hostels list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchAllHostels,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _filteredHostels.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No hostels found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Try adjusting your filters',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchAllHostels,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredHostels.length,
                              itemBuilder: (context, index) {
                                final hostel = _filteredHostels[index];
                                return _buildHostelCard(hostel);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostelCard(Map<String, dynamic> hostel) {
    final isOwner = _isHostelOwner(hostel);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToHostelDetails(hostel),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hostel image
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    image: hostel['image_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(hostel['image_url']),
                            fit: BoxFit.cover,
                          )
                        : const DecorationImage(
                            image: AssetImage('assets/images/placeholder.png'),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                // Campus location badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hostel['campus_location'] == 'On Campus' 
                        ? const Color(0xFF4A6FE3) 
                        : const Color(0xFFFF7E42),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hostel['campus_location'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Owner badge (if owner)
                if (isOwner)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Owner',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Hostel details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hostel name and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hostel['name'] ?? 'Unnamed Hostel',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324054),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₵${hostel['price'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A6FE3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Address
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hostel['address'] ?? 'No address',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Available rooms
                  Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${hostel['available_rooms'] ?? 0} available rooms',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  
                  // If owner, show edit button
                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToEditHostel(hostel),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Hostel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4A6FE3),
                          side: const BorderSide(color: Color(0xFF4A6FE3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}