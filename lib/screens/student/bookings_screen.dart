import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostel_connect/services/hostel_service.dart';
import 'package:intl/intl.dart';
// Import the HostelListScreen
import 'hostel_list_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({Key? key}) : super(key: key);

  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  String? _errorMessage;
  late TabController _tabController;
  TextEditingController _searchController = TextEditingController();
  final List<String> _tabLabels = ['All', 'Pending', 'Confirmed', 'Cancelled', 'Rejected'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchBookings();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      if (_searchController.text.isNotEmpty) {
        _searchBookings(_searchController.text);
      } else {
        _filterBookings(_tabLabels[_tabController.index]);
      }
    }
  }

  void _searchBookings(String query) {
    final String normalizedQuery = query.toLowerCase().trim();
    
    if (normalizedQuery.isEmpty) {
      _filterBookings(_tabLabels[_tabController.index]);
      return;
    }
    
    List<Map<String, dynamic>> baseList = _tabLabels[_tabController.index] == 'All' 
        ? List.from(_bookings)
        : _bookings.where(
            (booking) => booking['status']?.toString().toLowerCase() == 
                _tabLabels[_tabController.index].toLowerCase()
          ).toList();
    
    setState(() {
      _filteredBookings = baseList.where((booking) {
        final hostel = booking['hostel'] as Map<String, dynamic>? ?? {};
        final room = booking['room'] as Map<String, dynamic>? ?? {};
        
        if (hostel['name']?.toString().toLowerCase().contains(normalizedQuery) ?? false) {
          return true;
        }
        
        if (room['name']?.toString().toLowerCase().contains(normalizedQuery) ?? false) {
          return true;
        }
        
        if (hostel['location']?.toString().toLowerCase().contains(normalizedQuery) ?? false) {
          return true;
        }
        
        if ((booking['notes']?.toString().toLowerCase().contains(normalizedQuery) ?? false)) {
          return true;
        }
        
        if (booking['id'].toString().contains(normalizedQuery)) {
          return true;
        }
        
        return false;
      }).toList();
    });
  }

  void _filterBookings(String filter) {
    setState(() {
      if (filter == 'All') {
        _filteredBookings = List.from(_bookings);
      } else {
        _filteredBookings = _bookings.where(
          (booking) => booking['status']?.toString().toLowerCase() == filter.toLowerCase()
        ).toList();
      }
    });
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You need to be logged in to view bookings';
        });
        return;
      }

      final bookings = await HostelService.getUserBookings(userId);
      
      setState(() {
        _bookings = bookings;
        _filteredBookings = List.from(bookings);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load bookings: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF324054)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF324054)),
            tooltip: 'Refresh bookings',
            onPressed: _fetchBookings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A6FE3),
          unselectedLabelColor: const Color(0xFF324054).withOpacity(0.5),
          indicatorColor: const Color(0xFF4A6FE3),
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBookings,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A6FE3)))
            : _errorMessage != null
                ? _buildErrorView()
                : _filteredBookings.isEmpty
                    ? _buildEmptyView()
                    : _buildBookingsList(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _errorMessage!,
            style: TextStyle(
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchBookings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6FE3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 64,
            color: const Color(0xFF324054).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No bookings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t made any hostel bookings yet',
            style: TextStyle(
              color: const Color(0xFF324054).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to the HostelListScreen instead of using named route
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HostelListScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6FE3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Browse Hostels'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredBookings.length,
      itemBuilder: (context, index) {
        final booking = _filteredBookings[index];
        final hostel = booking['hostel'] as Map<String, dynamic>? ?? {};
        final room = booking['room'] as Map<String, dynamic>? ?? {};
        final moveInDate = booking['move_in_date'] != null 
            ? DateTime.parse(booking['move_in_date'].toString()) 
            : null;
        final createdAt = booking['created_at'] != null 
            ? DateTime.parse(booking['created_at'].toString()) 
            : DateTime.now();
        final updatedAt = booking['updated_at'] != null 
            ? DateTime.parse(booking['updated_at'].toString()) 
            : DateTime.now();
            
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: hostel['image_url'] != null
                    ? Image.network(
                        hostel['image_url'].toString(),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
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
                            hostel['name']?.toString() ?? 'Unknown Hostel',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF324054),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusBadge(booking['status']?.toString()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 16,
                          color: Color(0xFF4A6FE3),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          room['name']?.toString() ?? 'Unknown Room',
                          style: TextStyle(
                            color: const Color(0xFF324054).withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF4A6FE3),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hostel['location']?.toString() ?? 'Unknown location',
                          style: TextStyle(
                            color: const Color(0xFF324054).withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      height: 1,
                      color: const Color(0xFFEEEEEE),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem(
                          Icons.event_note,
                          'Created',
                          DateFormat('dd/MM/yyyy').format(createdAt),
                        ),
                        _buildInfoItem(
                          Icons.calendar_today,
                          'Move In Date',
                          moveInDate != null
                              ? DateFormat('dd/MM/yyyy').format(moveInDate)
                              : 'Not specified',
                        ),
                        _buildInfoItem(
                          Icons.update,
                          'Last Updated',
                          DateFormat('dd/MM/yyyy').format(updatedAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (booking['notes'] != null && booking['notes'].toString().isNotEmpty)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F3F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.notes,
                                    size: 16,
                                    color: Color(0xFF4A6FE3),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      booking['notes'].toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF324054),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '₵${booking['price']?.toString() ?? '0'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A6FE3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          _showBookingDetails(context, booking);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFFF1F3F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            color: Color(0xFF324054),
                          ),
                        ),
                      ),
                    ),
                    if (booking['status']?.toString() == 'pending')
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _showCancelConfirmation(context, booking['id']);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFFF5252)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel Booking',
                            style: TextStyle(
                              color: Color(0xFFFF5252),
                            ),
                          ),
                        ),
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

  void _showBookingDetails(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              const Text(
                'Booking Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324054),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              _buildDetailItem('Booking ID', '#${booking['id'].toString()}'),
              
              _buildDetailItem(
                'Status', 
                booking['status']?.toString() ?? 'Unknown',
                valueColor: _getStatusColor(booking['status']?.toString()),
              ),
              
              _buildDetailItem('Hostel', (booking['hostel'] as Map<String, dynamic>?)?['name']?.toString() ?? 'Unknown'),
              _buildDetailItem('Room', (booking['room'] as Map<String, dynamic>?)?['name']?.toString() ?? 'Unknown'),
              
              _buildDetailItem(
                'Move In Date', 
                booking['move_in_date'] != null 
                  ? DateFormat('dd MMMM, yyyy').format(DateTime.parse(booking['move_in_date'].toString()))
                  : 'Not specified'
              ),
              _buildDetailItem(
                'Created At', 
                booking['created_at'] != null 
                  ? DateFormat('dd MMMM, yyyy HH:mm').format(DateTime.parse(booking['created_at'].toString()))
                  : 'Unknown'
              ),
              _buildDetailItem(
                'Last Updated', 
                booking['updated_at'] != null 
                  ? DateFormat('dd MMMM, yyyy HH:mm').format(DateTime.parse(booking['updated_at'].toString()))
                  : 'Unknown'
              ),
              
              _buildDetailItem(
                'Price', 
                '₵${booking['price']?.toString() ?? '0'}',
                valueStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A6FE3),
                ),
              ),
              
              if (booking['notes'] != null && booking['notes'].toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking['notes'].toString(),
                        style: TextStyle(
                          color: const Color(0xFF324054).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 32),
              
              if (booking['status']?.toString() == 'pending')
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCancelConfirmation(context, booking['id']);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFFF5252)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel Booking',
                      style: TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF324054).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: valueStyle ?? TextStyle(
              color: valueColor ?? const Color(0xFF324054),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, dynamic bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await HostelService.cancelBooking(bookingId);
                _fetchBookings();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking cancelled successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to cancel booking: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 150,
      color: const Color(0xFFF1F3F6),
      child: Center(
        child: Icon(
          Icons.hotel,
          size: 48,
          color: const Color(0xFF324054).withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color badgeColor = _getStatusColor(status);
    IconData badgeIcon = _getStatusIcon(status);
    
    // Capitalize first letter of status for display
    String displayStatus = status != null 
        ? status[0].toUpperCase() + status.substring(1).toLowerCase() 
        : 'Unknown';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            displayStatus,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF4A6FE3),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF324054).withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF324054),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch(status?.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'rejected':
        return Colors.red.shade800;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String? status) {
    switch(status?.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      case 'rejected':
        return Icons.not_interested;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.help_outline;
    }
  }
}