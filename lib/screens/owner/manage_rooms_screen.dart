import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_edit_room_screen.dart';

class ManageRoomsScreen extends StatefulWidget {
  const ManageRoomsScreen({Key? key}) : super(key: key);
  
  @override
  State createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  List<Map<String, dynamic>> _hostels = [];
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;
  int _selectedHostelIndex = 0; // For "All Hostels" tab
  static const int ALL_HOSTELS_TAB = 0;
  
  @override
  void initState() {
    super.initState();
    _fetchRoomsAndHostels();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }
  
  Future<void> _fetchRoomsAndHostels() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = "User not logged in.";
          _isLoading = false;
        });
        return;
      }
      
      // Step 1: Get all hostels owned by this user
      final hostelsResponse = await supabase
          .from('hostels')
          .select('*')
          .eq('owner_id', user.id)
          .order('name', ascending: true);
          
      if (hostelsResponse.isEmpty) {
        setState(() {
          _error = "You don't have any hostels yet.";
          _isLoading = false;
        });
        return;
      }
      
      _hostels = List<Map<String, dynamic>>.from(hostelsResponse);
      
      // Setup tab controller for hostels (including "All Hostels" tab)
      _tabController = TabController(
        length: _hostels.length + 1, // +1 for "All Hostels" tab
        vsync: this,
      );
      
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {
            _selectedHostelIndex = _tabController!.index;
            _filterRoomsBySelectedHostel();
          });
        }
      });
      
      // Step 2: Get all room IDs from these hostels
      final hostelIds = _hostels.map((hostel) => hostel['id']).toList();
      
      // Step 3: Fetch all rooms for these hostels
      final roomsResponse = await supabase
          .from('rooms')
          .select('*, hostels(name)')
          .inFilter('hostel_id', hostelIds)
          .order('hostel_id');
      
      setState(() {
        _rooms = List<Map<String, dynamic>>.from(roomsResponse);
        _filterRoomsBySelectedHostel(); // Apply initial filtering
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load rooms: $e";
        _isLoading = false;
      });
    }
  }
  
  void _filterRoomsBySelectedHostel() {
    if (_selectedHostelIndex == ALL_HOSTELS_TAB) {
      // "All Hostels" tab - show all rooms (but still apply search filter)
      _filteredRooms = _rooms;
    } else {
      // Filter rooms by selected hostel
      final selectedHostelId = _hostels[_selectedHostelIndex - 1]['id']; // -1 because of "All Hostels" tab
      _filteredRooms = _rooms.where((room) => room['hostel_id'] == selectedHostelId).toList();
    }
    
    // Apply search filter if there's a search query
    if (_searchQuery.isNotEmpty) {
      _performSearch(_searchQuery);
    }
  }
  
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      
      // First filter by selected hostel
      List<Map<String, dynamic>> hostelFilteredRooms;
      if (_selectedHostelIndex == ALL_HOSTELS_TAB) {
        hostelFilteredRooms = _rooms;
      } else {
        final selectedHostelId = _hostels[_selectedHostelIndex - 1]['id'];
        hostelFilteredRooms = _rooms.where((room) => room['hostel_id'] == selectedHostelId).toList();
      }
      
      // Then apply search filter if query exists
      if (_searchQuery.isEmpty) {
        _filteredRooms = hostelFilteredRooms;
      } else {
        _filteredRooms = hostelFilteredRooms.where((room) {
          final roomName = (room['name'] ?? '').toString().toLowerCase();
          final roomNumber = (room['room_number'] ?? '').toString().toLowerCase();
          final hostelName = _getHostelName(room).toLowerCase();
          final price = (room['price'] ?? '').toString().toLowerCase();
          final description = (room['description'] ?? '').toString().toLowerCase();
          
          return roomName.contains(_searchQuery) ||
                 roomNumber.contains(_searchQuery) ||
                 hostelName.contains(_searchQuery) ||
                 price.contains(_searchQuery) ||
                 description.contains(_searchQuery);
        }).toList();
      }
    });
  }
  
  void _clearSearch() {
    _searchController.clear();
    _performSearch('');
  }
  
  void _navigateToAddRoom() async {
    // Navigate to Add Room Screen with pre-selected hostel if applicable
    final Map<String, dynamic>? preSelectedHostel = _selectedHostelIndex != ALL_HOSTELS_TAB 
        ? _hostels[_selectedHostelIndex - 1] 
        : null;
    
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AddEditRoomScreen(
          hostelId: preSelectedHostel != null ? preSelectedHostel['id'] : null,
        ),
      ),
    );
    
    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      await _fetchRoomsAndHostels();
    }
  }
  
  void _navigateToEditRoom(Map<String, dynamic> room) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditRoomScreen(
          roomData: room,
          hostelId: room['hostel_id'],
        ),
      ),
    );
    
    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      await _fetchRoomsAndHostels();
    }
  }
  
  Future<void> _deleteRoom(int roomId, int hostelId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: const Text('Are you sure you want to delete this room?'),
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
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await supabase
          .from('rooms')
          .delete()
          .eq('id', roomId);
          
      await _updateHostelRoomCount(hostelId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _fetchRoomsAndHostels();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting room: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _updateHostelRoomCount(int hostelId) async {
    try {
      final result = await supabase
          .from('rooms')
          .select()
          .eq('hostel_id', hostelId)
          .eq('available', true);
      
      final availableRooms = result.length;
      
      await supabase
          .from('hostels')
          .update({'available_rooms': availableRooms})
          .eq('id', hostelId);
    } catch (e) {
      print('Error updating hostel room count: $e');
    }
  }
  
  String _getHostelName(Map<String, dynamic> room) {
    if (room['hostels'] != null && room['hostels']['name'] != null) {
      return room['hostels']['name'];
    }
    return 'Unknown Hostel';
  }

  Widget _buildRoomImagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F3F6),
      child: const Center(
        child: Icon(
          Icons.meeting_room_outlined,
          size: 50,
          color: Color(0xFF4A6FE3),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Rooms'),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF324054)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_error!.contains("don't have any hostels")) 
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6FE3),
                  ),
                  child: const Text('Add Hostel First'),
                ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'Manage Rooms',
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
          isScrollable: true,
          labelColor: const Color(0xFF4A6FE3),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4A6FE3),
          tabs: [
            const Tab(text: 'All Hostels'),
            ..._hostels.map((hostel) => Tab(text: hostel['name'])).toList(),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  hintText: _selectedHostelIndex == ALL_HOSTELS_TAB
                      ? 'Search across all hostels...'
                      : 'Search in ${_hostels[_selectedHostelIndex - 1]['name']}...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF4A6FE3)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF324054)),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Found ${_filteredRooms.length} ${_filteredRooms.length == 1 ? "room" : "rooms"}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          
          if (_selectedHostelIndex != ALL_HOSTELS_TAB && _searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      'In: ${_hostels[_selectedHostelIndex - 1]['name']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFF4A6FE3),
                    deleteIcon: const Icon(Icons.filter_list, color: Colors.white, size: 18),
                    onDeleted: null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredRooms.length} ${_filteredRooms.length == 1 ? "room" : "rooms"}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        size: 80,
                        color: Color(0xFF4A6FE3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No Rooms Added Yet",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Add your first room to get started",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _navigateToAddRoom,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Your First Room"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A6FE3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _filteredRooms.isEmpty
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
                        Text(
                          _searchQuery.isNotEmpty
                            ? 'No rooms match "$_searchQuery"'
                            : 'No rooms in this hostel',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_searchQuery.isNotEmpty)
                          OutlinedButton(
                            onPressed: _clearSearch,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A6FE3),
                            ),
                            child: const Text('Clear Search'),
                          ),
                        if (_selectedHostelIndex != ALL_HOSTELS_TAB && _searchQuery.isEmpty)
                          ElevatedButton(
                            onPressed: _navigateToAddRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A6FE3),
                            ),
                            child: Text('Add Room to ${_hostels[_selectedHostelIndex - 1]['name']}'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = _filteredRooms[index];
                      final isAvailable = room['available'] ?? false;
                      
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: SizedBox(
                                height: 150,
                                width: double.infinity,
                                child: room['image_url'] != null
                                    ? Image.network(
                                        room['image_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _buildRoomImagePlaceholder(),
                                      )
                                    : _buildRoomImagePlaceholder(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          room['name'] ?? 'Unnamed Room',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF324054),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isAvailable ? const Color(0xFFE6F7ED) : const Color(0xFFFEE6E6),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isAvailable ? 'Available' : 'Occupied',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isAvailable ? const Color(0xFF28A745) : const Color(0xFFDC3545),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.numbers,
                                        size: 16,
                                        color: Color(0xFF4A6FE3),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Room ${room['room_number'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: const Color(0xFF324054).withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.people_outline,
                                        size: 16,
                                        color: Color(0xFF4A6FE3),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Capacity: ${room['capacity'] ?? 1}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: const Color(0xFF324054).withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      '₵${room['price'] ?? 0}/semester',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4A6FE3),
      ),
    ),
    Row(
      children: [
        TextButton.icon(
          onPressed: () => _navigateToEditRoom(room),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4A6FE3),
          ),
        ),
        TextButton.icon(
          onPressed: () => _deleteRoom(room['id'], room['hostel_id']),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Delete'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      ],
    ),
  ],
),
                                  
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddRoom,
        backgroundColor: const Color(0xFF4A6FE3),
        child: const Icon(Icons.add),
        tooltip: _selectedHostelIndex == ALL_HOSTELS_TAB 
            ? 'Add Room'
            : 'Add Room to ${_hostels[_selectedHostelIndex - 1]['name']}',
      ),
    );
  }
}