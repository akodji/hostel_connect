import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:hostel_connect/services/hostel_service.dart';

import 'hostel_detail_screen.dart';

class HostelListScreen extends StatefulWidget {
  const HostelListScreen({Key? key}) : super(key: key);

  @override
  _HostelListScreenState createState() => _HostelListScreenState();
}

class _HostelListScreenState extends State<HostelListScreen> {
  List<Map<String, dynamic>> _hostels = [];
  List<Map<String, dynamic>> _filteredHostels = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _campusFilter = 'All'; // Options: 'All', 'On Campus', 'Off Campus'
  
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadHostels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHostels() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final hostels = await HostelService.getAllHostels();
      setState(() {
        _hostels = hostels;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load hostels: $e'))
      );
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _hostels;
    
    // Apply campus filter
    if (_campusFilter != 'All') {
      filtered = filtered.where((hostel) => 
        hostel['campus_location'] == _campusFilter
      ).toList();
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((hostel) {
        final name = hostel['name'].toString().toLowerCase();
        final description = hostel['description'].toString().toLowerCase();
        final location = hostel['location'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        return name.contains(query) || 
               description.contains(query) || 
               location.contains(query);
      }).toList();
    }
    
    setState(() {
      _filteredHostels = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _setCampusFilter(String? filterValue) {
    if (filterValue != null) {
      setState(() {
        _campusFilter = filterValue;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Hostels'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHostels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No hostels found',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : _buildHostelList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for hostels...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          
          // Filter options
          Row(
            children: [
              const Text('Filter by:'),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _campusFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Locations')),
                    DropdownMenuItem(value: 'On Campus', child: Text('On Campus')),
                    DropdownMenuItem(value: 'Off Campus', child: Text('Off Campus')),
                  ],
                  onChanged: _setCampusFilter,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostelList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredHostels.length,
      itemBuilder: (context, index) {
        final hostel = _filteredHostels[index];
        return _buildHostelCard(hostel);
      },
    );
  }

  Widget _buildHostelCard(Map<String, dynamic> hostel) {
    // Extract hostel amenities
    List<dynamic> amenitiesList = [];
    if (hostel['hostel_amenities'] != null && hostel['hostel_amenities'] is List) {
      amenitiesList = hostel['hostel_amenities'];
    }
    
    // Get actual available rooms count from our new field
    final int actualAvailableRooms = hostel['actual_available_rooms'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HostelDetailScreen(hostelId: hostel['id']),
            ),
          ).then((value) {
            // Refresh the list when returning from detail screen
            if (value == true) {
              _loadHostels();
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hostel Image
            hostel['image_url'] != null
                ? Image.network(
                    hostel['image_url'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 48),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  )
                : Container(
                    height: 180,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.home, size: 48, color: Colors.grey),
                    ),
                  ),
                  
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Campus Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hostel['name'] ?? 'Unnamed Hostel',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hostel['campus_location'] == 'On Campus'
                              ? Colors.green[100]
                              : Colors.orange[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          hostel['campus_location'] ?? 'Unknown',
                          style: TextStyle(
                            color: hostel['campus_location'] == 'On Campus'
                                ? Colors.green[800]
                                : Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hostel['location'] ?? 'Unknown location',
                          style: TextStyle(color: Colors.grey[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Price and availability
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₵${hostel['price'] ?? 0}/semester',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        '$actualAvailableRooms ${actualAvailableRooms == 1 ? 'room' : 'rooms'} available',
                        style: TextStyle(
                          color: actualAvailableRooms > 0
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Amenities
                  if (amenitiesList.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: amenitiesList.take(3).map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            amenity['amenity'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
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