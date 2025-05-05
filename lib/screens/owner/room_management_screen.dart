import 'package:flutter/material.dart';
//import '../services/supabase_service.dart';
import 'add_edit_room_screen.dart';

class RoomManagementScreen extends StatefulWidget {
  final Map<String, dynamic> hostel;

  const RoomManagementScreen({
    Key? key,
    required this.hostel,
  }) : super(key: key);

  @override
  _RoomManagementScreenState createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];
  
  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Fetch rooms for this hostel
      final response = await supabase
          .from('rooms')
          .select('*, bookings:bookings(id, student_id, status)')
          .eq('hostel_id', widget.hostel['id']);
      
      setState(() {
        _rooms = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      _showErrorMessage('Failed to load rooms: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _deleteRoom(int roomId) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Room'),
          content: const Text('Are you sure you want to delete this room? This action cannot be undone.'),
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
      
      if (confirm != true) {
        return;
      }
      
      // Delete room
      await supabase
          .from('rooms')
          .delete()
          .eq('id', roomId);
      
      // Reload rooms
      _loadRooms();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorMessage('Failed to delete room: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          'Rooms - ${widget.hostel['name']}',
          style: const TextStyle(
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
          : _rooms.isEmpty
              ? _buildEmptyState()
              : _buildRoomsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditRoomScreen(hostelId: widget.hostel['id']),
            ),
          ).then((_) => _loadRooms()); // Refresh list when returning
        },
        backgroundColor: const Color(0xFF4A6FE3),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF4A6FE3).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              size: 60,
              color: Color(0xFF4A6FE3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Rooms Added Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add rooms to your hostel to start accepting bookings",
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditRoomScreen(hostelId: widget.hostel['id']),
                ),
              ).then((_) => _loadRooms());
            },
            icon: const Icon(Icons.add),
            label: const Text("Add Your First Room"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        final isBooked = (room['bookings'] as List).any((booking) => 
            booking['status'] == 'active' || booking['status'] == 'pending');
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room image or placeholder
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[300],
                  image: room['image_url'] != null
                      ? DecorationImage(
                          image: NetworkImage(room['image_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: room['image_url'] == null
                    ? const Icon(
                        Icons.meeting_room_outlined,
                        size: 48,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              // Room details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Room number and type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Room ${room['room_number']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324054),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                room['room_type'] ?? 'Standard Room',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF324054).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Price and status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₦${room['price']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A6FE3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBooked
                                    ? const Color(0xFFF75676).withOpacity(0.1)
                                    : const Color(0xFF2DCE89).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isBooked ? 'Occupied' : 'Available',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isBooked
                                      ? const Color(0xFFF75676)
                                      : const Color(0xFF2DCE89),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Room features
                    Row(
                      children: [
                        _buildFeatureItem(
                          icon: Icons.people_outline,
                          value: room['capacity'].toString(),
                          label: 'Capacity',
                        ),
                        _buildFeatureItem(
                          icon: Icons.balcony,
                          value: room['has_balcony'] ? 'Yes' : 'No',
                          label: 'Balcony',
                        ),
                        _buildFeatureItem(
                          icon: Icons.bathtub_outlined,
                          value: room['has_bathroom'] ? 'Yes' : 'No',
                          label: 'Bathroom',
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEditRoomScreen(
                                    hostelId: widget.hostel['id'],
                                    roomData: room,
                                  ),
                                ),
                              ).then((_) => _loadRooms());
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A6FE3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteRoom(room['id']),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
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
      },
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4A6FE3), size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF324054),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}