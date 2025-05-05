import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// Import the AddEditHostelScreen
import 'add_edit_hostel_screen.dart';

class ManageHostelsScreen extends StatefulWidget {
  const ManageHostelsScreen({Key? key}) : super(key: key);

  @override
  State<ManageHostelsScreen> createState() => _ManageHostelsScreenState();
}

class _ManageHostelsScreenState extends State<ManageHostelsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _hostels = [];
  List<dynamic> _filteredHostels = []; // For search results
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHostels();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Search functionality
  void _onSearchChanged() {
    _filterHostels(_searchController.text);
  }

  void _filterHostels(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredHostels = List.from(_hostels);
      });
    } else {
      final lowercaseQuery = query.toLowerCase();
      setState(() {
        _filteredHostels = _hostels.where((hostel) {
          return hostel['name'].toString().toLowerCase().contains(lowercaseQuery) ||
              hostel['address'].toString().toLowerCase().contains(lowercaseQuery) ||
              hostel['campus_location'].toString().toLowerCase().contains(lowercaseQuery) ||
              hostel['description'].toString().toLowerCase().contains(lowercaseQuery);
        }).toList();
      });
    }
  }

  Future<void> _fetchHostels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = "User not logged in.";
          _isLoading = false;
        });
        return;
      }

      // Fetch hostels with owner_id matching the current user
      final response = await supabase
          .from('hostels')
          .select('*')
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _hostels = response;
        _filteredHostels = List.from(_hostels); // Initialize filtered list
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load hostels: $e";
        _isLoading = false;
      });
    }
  }

  // Navigate to the AddEditHostelScreen for creating a new hostel
  Future<void> _navigateToAddHostel() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditHostelScreen(),
      ),
    );
    
    // Refresh the list if a hostel was added
    if (result == true) {
      _fetchHostels();
    }
  }

  // Navigate to the AddEditHostelScreen for editing an existing hostel
  Future<void> _navigateToEditHostel(Map<String, dynamic> hostelData) async {
    // Check if current user is the owner of this hostel
    final user = supabase.auth.currentUser;
    if (user == null || hostelData['owner_id'] != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit hostels you own'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditHostelScreen(hostelData: hostelData),
      ),
    );
    
    // Refresh the list if the hostel was updated
    if (result == true) {
      _fetchHostels();
    }
  }

  // Delete hostel functionality
  Future<void> _deleteHostel(int hostelId) async {
    // Verify ownership before allowing deletion
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to delete hostels'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Find the hostel in our list
    final hostelIndex = _hostels.indexWhere((h) => h['id'] == hostelId);
    if (hostelIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hostel not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final hostel = _hostels[hostelIndex];
    
    // Check ownership
    if (hostel['owner_id'] != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete hostels you own'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hostel'),
        content: const Text('Are you sure you want to delete this hostel? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First delete amenities related to this hostel
      await supabase
          .from('hostel_amenities')
          .delete()
          .eq('hostel_id', hostelId);
      
      // Then delete the hostel
      await supabase
          .from('hostels')
          .delete()
          .eq('id', hostelId);
      
      // Update local state after successful deletion
      setState(() {
        _hostels.removeAt(hostelIndex);
        _filteredHostels = _filteredHostels.where((h) => h['id'] != hostelId).toList();
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting hostel: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting hostel: ${e.toString()}'),
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
          'Manage Hostels',
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
            onPressed: _fetchHostels,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
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
          
          // Hostels list or loading indicator
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
                              onPressed: _fetchHostels,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _hostels.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.home_work_outlined,
                                  size: 80,
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
                                  'Add a new hostel to get started',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _navigateToAddHostel,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Hostel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A6FE3),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
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
                                      'No hostels match your search',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                      child: const Text('Clear Search'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4A6FE3),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchHostels,
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
      floatingActionButton: _hostels.isNotEmpty
          ? FloatingActionButton(
              onPressed: _navigateToAddHostel,
              backgroundColor: const Color(0xFF4A6FE3),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildHostelCard(Map<String, dynamic> hostel) {
    final user = supabase.auth.currentUser;
    final isOwner = user != null && hostel['owner_id'] == user.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hostel image
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
                const SizedBox(height: 4),
                
                // Campus location
                Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hostel['campus_location'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
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
                
                const SizedBox(height: 16),
                
                // Action buttons - only show for hostels user owns
                if (isOwner)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit button
                      OutlinedButton.icon(
                        onPressed: () => _navigateToEditHostel(hostel),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4A6FE3),
                          side: const BorderSide(color: Color(0xFF4A6FE3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Delete button
                      OutlinedButton.icon(
                        onPressed: () => _deleteHostel(hostel['id']),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
}