import 'package:hostel_connect/services/connectivity_service.dart';
import 'package:hostel_connect/services/local_database_service.dart';
import 'package:hostel_connect/services/hive_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService {
  final SupabaseClient client = Supabase.instance.client;

  Future<void> syncBookings() async {
    final isConnected = await ConnectivityService().checkConnectivity();
    if (!isConnected) return;

    final List<BookingModel> unsyncedBookings = await LocalDatabaseService().getUnsyncedBookings();

    for (final booking in unsyncedBookings) {
      try {
        // Send the booking to Supabase
        final response = await client.from('bookings').insert({
          'user_id': booking.userId,
          'hostel_id': booking.hostelId,
          'room_id': booking.roomId,
          'move_in_date': booking.moveInDate.toIso8601String(),
          'status': booking.status,
          'notes': booking.notes,
          'price': booking.price,
          'created_at': booking.createdAt.toIso8601String(),
          'updated_at': booking.updatedAt.toIso8601String(),
        });

        // Mark booking as synced
        final localDb = LocalDatabaseService(); // ✅ Get instance
        await localDb.markBookingAsSynced(booking.id); // ✅ Now valid

      } catch (e) {
        print('Failed to sync booking ${booking.id}: $e');
        // You may want to log or retry depending on your logic
      }
    }
  }
}
