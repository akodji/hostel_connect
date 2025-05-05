import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hostel_connect/screens/owner/add_edit_room_screen.dart';


final supabase = Supabase.instance.client;

class HostelRoomsScreen extends StatefulWidget {
  final Map<String, dynamic> hostel;

  const HostelRoomsScreen({
    Key? key,
    required this.hostel,
  }) : super(key: key);

  @override
  _HostelRoomsScreenState createState() => _HostelRoomsScreenState();
}

class _HostelRoomsScreenState extends State<HostelRoomsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];
  late Map<String, dynamic> _hostelData;

  @override
  void initState() {
    super.initState();
    _hostelData = widget.hostel;
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final roomsResponse = await supabase
          .from('rooms')
          .select('*')
          .eq('hostel_id', _hostelData['id'])
          .order('room_number', ascending: true);

      setState(() {
        _rooms = List<Map<String, dynamic>>.from(roomsResponse);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rooms: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load rooms: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRoomAvailability(int roomId, bool currentAvailability) async {
    try {
      await supabase
          .from('rooms')
          .update({
            'available': !currentAvailability,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', roomId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room availability updated'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadRooms();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update room availability: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToAddRoomScreen() {
  try {
    // Try to parse the hostel ID as an integer
    final hostelId = int.parse(_hostelData['id'].toString());
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditRoomScreen(
          hostelId: hostelId,
        ),
      ),
    ).then((_) {
      // Refresh the room list when returning from AddEditRoomScreen
      _loadRooms();
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error parsing hostel ID: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    print('Error navigating to add room screen: $e');
  }
}

  void _showEditRoomDialog(Map<String, dynamic> room) {
    final _nameController = TextEditingController(text: room['name']);
    final _roomNumberController = TextEditingController(text: room['room_number'].toString());
    final _priceController = TextEditingController(text: room['price'].toString());
    final _capacityController = TextEditingController(text: room['capacity'].toString());
    final _descriptionController = TextEditingController(text: room['description'] ?? '');
    final _imageUrlController = TextEditingController(text: room['image_url'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Room Name*'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number*'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (₵)*'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacity*'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate required fields
              if (_nameController.text.isEmpty ||
                  _roomNumberController.text.isEmpty ||
                  _priceController.text.isEmpty ||
                  _capacityController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await supabase
                    .from('rooms')
                    .update({
                      'name': _nameController.text,
                      'room_number': int.parse(_roomNumberController.text),
                      'price': double.parse(_priceController.text),
                      'capacity': int.parse(_capacityController.text),
                      'description': _descriptionController.text,
                      'image_url': _imageUrlController.text,
                      'updated_at': DateTime.now().toIso8601String()
                    })
                    .eq('id', room['id']);

                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                _loadRooms();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update room: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update Room'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoom(int roomId) async {
    try {
      // Check if room has active bookings
      final bookings = await supabase
          .from('bookings')
          .select('id')
          .eq('room_id', roomId)
          .inFilter('status', ['pending', 'confirmed', 'active'])
          .limit(1);

      if (bookings.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete room with active bookings'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await supabase
          .from('rooms')
          .delete()
          .eq('id', roomId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadRooms();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete room: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          "${_hostelData['name']} Rooms",
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
          : RefreshIndicator(
              onRefresh: _loadRooms,
              child: _rooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 80,
                            color: Color(0xFFCCCCCC),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No rooms found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF324054),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _navigateToAddRoomScreen,
                            icon: const Icon(Icons.add),
                            label: const Text("Add Room"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A6FE3),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final room = _rooms[index];
                        final price = room['price'] is String
                            ? double.tryParse(room['price']) ?? 0.0
                            : (room['price'] as num?)?.toDouble() ?? 0.0;
                        final isAvailable = room['available'] ?? true;

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
                              // Room image if available
                              if (room['image_url'] != null &&
                                  room['image_url'].toString().isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    room['image_url'],
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      height: 150,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Header with room name and price
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A6FE3).withOpacity(0.05),
                                  borderRadius: room['image_url'] != null &&
                                          room['image_url'].toString().isNotEmpty
                                      ? null
                                      : const BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            room['name'] ?? 'Unnamed Room',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF324054),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Room ${room['room_number']}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? const Color(0xFF2DCE89).withOpacity(0.1)
                                            : const Color(0xFFF75676).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isAvailable ? "AVAILABLE" : "UNAVAILABLE",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isAvailable
                                              ? const Color(0xFF2DCE89)
                                              : const Color(0xFFF75676),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Room details
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Capacity
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outlined,
                                          size: 16,
                                          color: Color(0xFF666666),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Capacity: ${room['capacity'] ?? 'N/A'} ${int.parse(room['capacity'].toString()) > 1 ? 'persons' : 'person'}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF324054),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Price
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.payments_outlined,
                                          size: 16,
                                          color: Color(0xFF666666),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "₵${price.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4A6FE3),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Description if available
                                    if (room['description'] != null &&
                                        room['description'].toString().isNotEmpty)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Description:",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            room['description'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF324054),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      ),

                                    // Action buttons
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _toggleRoomAvailability(
                                                room['id'], isAvailable),
                                            icon: Icon(isAvailable
                                                ? Icons.do_not_disturb_on_outlined
                                                : Icons.check_circle_outline),
                                            label: Text(isAvailable
                                                ? "Mark Unavailable"
                                                : "Mark Available"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isAvailable
                                                  ? const Color(0xFFF75676)
                                                  : const Color(0xFF2DCE89),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () => _showEditRoomDialog(room),
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: "Edit Room",
                                          color: const Color(0xFF4A6FE3),
                                        ),
                                        IconButton(
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Room'),
                                              content: const Text(
                                                  'Are you sure you want to delete this room? This action cannot be undone.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _deleteRoom(room['id']);
                                                  },
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        const Color(0xFFF75676),
                                                  ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          ),
                                          icon: const Icon(Icons.delete_outline),
                                          tooltip: "Delete Room",
                                          color: const Color(0xFFF75676),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddRoomScreen,
        backgroundColor: const Color(0xFF4A6FE3),
        child: const Icon(Icons.add),
      ),
    );
  }
}