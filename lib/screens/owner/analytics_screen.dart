import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

final supabase = Supabase.instance.client;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _hostels = [];
  int _totalBookings = 0;
  double _occupancyRate = 0;

  final DateFormat _monthFormat = DateFormat('MMM');
  final DateFormat _dayFormat = DateFormat('dd');
  //final DateFormat _yearFormat = DateFormat('yyyy');

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
  try {
    setState(() {
      _isLoading = true;
    });

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    // Get all hostels owned by the user
    final hostelsResponse = await supabase
        .from('hostels')
        .select('*')
        .eq('owner_id', userId);

    final hostels = hostelsResponse as List;
    _hostels = hostels.map((hostel) => hostel as Map<String, dynamic>).toList();

    final hostelIds = _hostels.map((hostel) => hostel['id']).toList();

    if (hostelIds.isNotEmpty) {
      // Get all bookings for these hostels
      final bookingsResponse = await supabase
          .from('bookings')
          .select('*, hostels:hostel_id(name)')
          .eq('hostel_id', hostelIds)  // Changed contains() to in_()
          .order('move_in_date', ascending: false);

      _bookings = (bookingsResponse as List)
          .map((booking) => booking as Map<String, dynamic>)
          .toList();

      // Calculate summary metrics
      _totalBookings = _bookings.length;

      // Calculate occupancy rate
      int totalRooms = 0;
      int occupiedRooms = 0;

      for (final hostelId in hostelIds) {
        // Get all rooms for this hostel
        final roomsResponse = await supabase
            .from('rooms')
            .select('id, available')
            .eq('hostel_id', hostelId);

        final rooms = roomsResponse as List;
        totalRooms += rooms.length;

        // Count non-available rooms as occupied
        occupiedRooms += rooms.where((room) => room['available'] == false).length;
      }

      _occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms) * 100 : 0;
    }

    setState(() {
      _isLoading = false;
    });
  } catch (e) {
    print('Error loading analytics data: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading analytics: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          "Analytics",
          style: TextStyle(
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      _buildSummaryCard(
                        "Total Bookings",
                        _totalBookings.toString(),
                        Icons.book_online,
                        const Color(0xFF6C63FF),
                      ),
                      const SizedBox(width: 16),
                      _buildSummaryCard(
                        "Occupancy Rate",
                        "${_occupancyRate.toStringAsFixed(1)}%",
                        Icons.hotel,
                        const Color(0xFFFFA726),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSummaryCard(
                        "Hostels",
                        _hostels.length.toString(),
                        Icons.apartment,
                        const Color(0xFF4A6FE3),
                      ),
                      const SizedBox(width: 16),
                      // This space is intentionally left empty to maintain the grid layout
                      Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF324054),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF324054).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}