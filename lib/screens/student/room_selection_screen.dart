import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:hostel_connect/services/hive_models.dart';
import 'package:hostel_connect/services/connectivity_service.dart';

class RoomSelectionScreen extends StatefulWidget {
  final int? hostelId;
  final String? roomType;
  final int? capacity;
  final bool isOfflineMode;

  const RoomSelectionScreen({
    Key? key,
    this.hostelId,
    this.roomType,
    this.capacity,
    this.isOfflineMode = false,
  }) : super(key: key);

  @override
  _RoomSelectionScreenState createState() => _RoomSelectionScreenState();
}

class _RoomSelectionScreenState extends State<RoomSelectionScreen> {
  int _selectedRoomIndex = -1;
  DateTime? _selectedMoveInDate;
  final TextEditingController _notesController = TextEditingController();
  int? _selectedCapacity;
  bool _isLoading = true;
  bool _hasConnectivity = true; // Track connectivity status
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _hostels = [];
  int? _selectedHostelId;

  @override
  void initState() {
    super.initState();
    _selectedCapacity = widget.capacity;
    _selectedHostelId = widget.hostelId;
    _checkConnectivityAndFetchData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivityAndFetchData() async {
    try {
      // First check if we have connectivity
      bool isConnected = ConnectivityService().isConnected;
      
      setState(() {
        _hasConnectivity = isConnected;
      });
      
      // Always try to fetch data regardless of connectivity status
      _fetchHostels();
      _fetchRooms();
    } catch (error) {
      print('Error checking connectivity: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHostels() async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('hostels')
          .select('id, name')
          .order('name');
      
      if (mounted) {
        setState(() {
          _hostels = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching hostels: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRooms() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final supabase = Supabase.instance.client;
      
      if (_selectedHostelId == null) {
        if (mounted) {
          setState(() {
            _rooms = [];
            _isLoading = false;
          });
        }
        return;
      }
      
      // Enhanced query to check room availability based on bookings count and capacity
      final response = await supabase.rpc('get_available_rooms', params: {
        'hostel_id_param': _selectedHostelId,
        'room_type_param': widget.roomType,
        'capacity_param': _selectedCapacity,
      });
      
      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching rooms: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onHostelChanged(int? hostelId) {
    if (hostelId != null && hostelId != _selectedHostelId) {
      setState(() {
        _selectedHostelId = hostelId;
        _selectedRoomIndex = -1; // Reset room selection when hostel changes
      });
      _fetchRooms();
    }
  }

  void _filterByCapacity(int capacity) {
    setState(() {
      _selectedCapacity = _selectedCapacity == capacity ? null : capacity;
    });
    _fetchRooms();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedMoveInDate) {
      setState(() {
        _selectedMoveInDate = picked;
      });
    }
  }

  Future<void> _saveBookingToDatabase() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to book a room')),
        );
        return;
      }
      
      if (_selectedRoomIndex == -1 || _selectedMoveInDate == null || _selectedHostelId == null) {
        return;
      }

      final selectedRoom = _rooms[_selectedRoomIndex];
      
      // Check room availability again before booking
      final availabilityCheck = await supabase.rpc('check_room_availability', params: {
        'room_id_param': selectedRoom['id'],
      });
      
      if (!availabilityCheck) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sorry, this room is no longer available')),
        );
        // Refresh rooms to get updated availability
        _fetchRooms();
        return;
      }
      
      // Fetch hostel name
      final hostelResponse = await supabase
          .from('hostels')
          .select('name')
          .eq('id', _selectedHostelId!)
          .single();
      
      // Create booking
      final bookingData = {
        'user_id': user.id,
        'hostel_id': _selectedHostelId,
        'room_id': selectedRoom['id'],
        'move_in_date': _selectedMoveInDate!.toIso8601String(),
        'status': 'pending',
        'notes': _notesController.text.trim(),
        'price': selectedRoom['price'],
      };
      
      final response = await supabase
          .from('bookings')
          .insert(bookingData)
          .select();
      
      if (response != null && response.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmationScreen(
              hostelName: hostelResponse['name'],
              roomNumber: selectedRoom['room_number'].toString(),
              roomType: selectedRoom['name'],
              price: selectedRoom['price'].toDouble(),
              moveInDate: _selectedMoveInDate!,
            ),
          ),
        );
      }
    } catch (error) {
      print('Error saving booking: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error occurred while booking. Please try again.')),
      );
    }
  }

  void _submitBooking() {
    if (_selectedHostelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hostel')),
      );
      return;
    }

    if (_selectedRoomIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room')),
      );
      return;
    }

    if (_selectedMoveInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a move-in date')),
      );
      return;
    }
    
    _saveBookingToDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Room'),
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hostel Dropdown
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Hostel:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedHostelId,
                              isExpanded: true,
                              hint: const Text('Select a hostel'),
                              items: _hostels.map<DropdownMenuItem<int>>((hostel) {
                                return DropdownMenuItem<int>(
                                  value: hostel['id'],
                                  child: Text(hostel['name']),
                                );
                              }).toList(),
                              onChanged: _onHostelChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (widget.roomType != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Available ${widget.roomType}s',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter by Capacity:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [1, 2, 3, 4].map((capacity) {
                              final isSelected = _selectedCapacity == capacity;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text('$capacity in a room'),
                                  selected: isSelected,
                                  onSelected: (_) => _filterByCapacity(capacity),
                                  backgroundColor: Colors.grey[200],
                                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                  checkmarkColor: Theme.of(context).primaryColor,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_rooms.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bedroom_parent_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedHostelId == null 
                                ? 'Please select a hostel to see available rooms'
                                : 'No rooms available with the selected filters',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      final isSelected = _selectedRoomIndex == index;
                      final spotsLeft = room['capacity'] - (room['bookings_count'] ?? 0);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRoomIndex = index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Room ${room['room_number']}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            room['name'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            '${room['capacity']} in a room',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          // Display available spots
                                          Text(
                                            '$spotsLeft ${spotsLeft == 1 ? 'spot' : 'spots'} left',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: spotsLeft <= 1 ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'GH₵${room['price']}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                if (room['description'] != null && room['description'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      room['description'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                
                                if (room['image_url'] != null)
                                  Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(room['image_url']),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[300],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Select Move-in Date',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedMoveInDate == null
                                ? 'Select a date'
                                : '${_selectedMoveInDate!.day}/${_selectedMoveInDate!.month}/${_selectedMoveInDate!.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedMoveInDate == null
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Additional Notes (Optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Any special requests or notes...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitBooking,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Book Now',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class BookingConfirmationScreen extends StatelessWidget {
  final String hostelName;
  final String roomNumber;
  final String roomType;
  final double price;
  final DateTime moveInDate;

  const BookingConfirmationScreen({
    Key? key,
    required this.hostelName,
    required this.roomNumber,
    required this.roomType,
    required this.price,
    required this.moveInDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Hostel', hostelName),
            _buildDetailRow('Room Number', roomNumber),
            _buildDetailRow('Room Type', roomType),
            _buildDetailRow('Price', 'GH₵$price'),
            _buildDetailRow(
              'Move-in Date',
              '${moveInDate.day}/${moveInDate.month}/${moveInDate.year}',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}