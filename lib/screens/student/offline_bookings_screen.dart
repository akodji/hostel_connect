import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:hostel_connect/services/hive_models.dart';

class OfflineBookingsScreen extends StatefulWidget {
  @override
  _OfflineBookingsScreenState createState() => _OfflineBookingsScreenState();
}

class _OfflineBookingsScreenState extends State<OfflineBookingsScreen> {
  late Box<BookingModel> bookingsBox;
  List<BookingModel> offlineBookings = [];

  @override
  void initState() {
    super.initState();
    _loadOfflineBookings();
  }

  Future<void> _loadOfflineBookings() async {
    bookingsBox = await Hive.openBox<BookingModel>('bookings');
    setState(() {
      offlineBookings = bookingsBox.values
          .where((booking) => booking.isOfflineBooking)
          .toList();
    });
  }

  Future<void> _syncBooking(BookingModel booking) async {
    // TODO: Replace with your real API call to sync booking
    await Future.delayed(Duration(seconds: 1)); // Simulate network delay

    booking.syncStatus = 'synced';
    booking.save();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking synced successfully')),
    );

    _loadOfflineBookings();
  }

  Future<void> _deleteBooking(BookingModel booking) async {
    await booking.delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking deleted')),
    );

    _loadOfflineBookings();
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Offline Bookings')),
      body: offlineBookings.isEmpty
          ? Center(child: Text('No offline bookings found.'))
          : ListView.builder(
              itemCount: offlineBookings.length,
              itemBuilder: (context, index) {
                final booking = offlineBookings[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Hostel ID: ${booking.hostelId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Room ID: ${booking.roomId}'),
                        Text('Price: \$${booking.price}'),
                        Text('Move-in: ${formatDate(booking.moveInDate)}'),
                        Text('Status: ${booking.status}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.cloud_upload),
                          onPressed: () => _syncBooking(booking),
                          tooltip: 'Sync',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteBooking(booking),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
