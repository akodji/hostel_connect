import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class to handle all Supabase related operations
class SupabaseService {
  /// Get the Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Get the current user
  static User? get currentUser => client.auth.currentUser;

  /// Check if a user is signed in
  static bool get isSignedIn => currentUser != null;

  /// Sign up a new user with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      // Create the user authentication
      final AuthResponse response = await client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        
        // Update the profile with additional data
        // The trigger will have created a basic profile already
        await client.from('profiles').update({
          'first_name': userData['first_name'],
          'last_name': userData['last_name'],
          'phone': userData['phone'],
          'role': userData['role'],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }

      return response;
    } catch (e) {
      print('Error during signup: $e');
      rethrow;
    }
  }

  /// Sign in a user with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // Verify user exists in profiles table as well
      if (response.user != null) {
        final profile = await client
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();
            
        if (profile == null) {
          // This should not happen with the trigger in place, but just in case
          throw Exception('User profile not found');
        }
      }
      
      return response;
    } catch (e) {
      print('Error during sign in: $e');
      rethrow;
    }
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Get the current user profile data from profiles table
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (currentUser == null) return null;

    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile data
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (currentUser == null) throw Exception('User not authenticated');

    data['updated_at'] = DateTime.now().toIso8601String();

    await client
        .from('profiles')
        .update(data)
        .eq('id', currentUser!.id);
  }

  /// Update user password
  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUser == null) throw Exception('User not authenticated');
    
    // First verify the current password by attempting to reauthenticate
    try {
      final email = currentUser!.email;
      if (email == null) throw Exception('User email not available');
      
      await client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      
      // If authentication succeeded, update the password
      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Current password is incorrect');
      }
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

 /// Delete user account
/// This completely deletes the user from both auth.users and profiles tables
static Future<bool> deleteAccount({
  required String password,
}) async {
  if (currentUser == null) throw Exception('User not authenticated');
  
  try {
    // Step 1: Verify the password by attempting to reauthenticate
    final email = currentUser!.email;
    if (email == null) throw Exception('User email not available');
    
    await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Get the user ID for reference
    final userId = currentUser!.id;
    
    // Step 2: Update related data first (soft delete)
    try {
      await client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      print('Note: Could not update bookings: $e');
      // Continue with deletion even if this step fails
    }
    
    // Step 3: PRIMARY DELETION METHOD - Use admin API (most direct method)
    try {
      // This is the most straightforward way to delete from auth.users
      await client.auth.admin.deleteUser(userId);
      print('User successfully deleted via admin API');
      
      // The user should be deleted from auth.users table at this point
      // Due to RLS triggers, the profiles record may also be deleted automatically
      
      // Sign out the user after deletion
      await signOut();
      return true;
    } catch (adminError) {
      print('Admin API deletion failed: $adminError');
      
      // Step 4: FALLBACK - Use PostgreSQL function via RPC
      try {
        // This RPC should execute a SQL function with permissions to delete from auth.users
        // Note: You need to create this function in your Supabase database
        final response = await client.rpc(
          'delete_user_account',
          params: {'user_id': userId},
        );
        
        print('RPC deletion response: $response');
        await signOut();
        return true;
      } catch (rpcError) {
        print('RPC deletion failed: $rpcError');
        
        // Step 5: LAST RESORT - Use Edge Function
        try {
          final response = await client.functions.invoke(
            'delete-user-account', 
            body: {
              'user_id': userId,
              'email': email,
            }
          );
          
          print('Edge function response: ${response.status}');
          await signOut();
          return response.status == 200;
        } catch (functionError) {
          print('Edge function deletion failed: $functionError');
          
          // If all deletion methods fail, inform the user
          throw Exception('Unable to delete account. Please contact support.');
        }
      }
    }
  } catch (e) {
    if (e is AuthException) {
      throw Exception('Password is incorrect');
    }
    throw Exception('Failed to delete account: ${e.toString()}');
  }
}

static Future<bool> checkEmailExists(String email) async {
  try {
    // Check in profiles table
    final data = await client
        .from('profiles')
        .select('email')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();
    
    return data != null;
  } catch (e) {
    print('Error checking email existence: $e');
    rethrow;
  }
}

  /// Generate and send OTP to user's email for password reset
  static Future<void> sendPasswordResetOTP(String email) async {
    try {
      // First check if the email exists
      final exists = await checkEmailExists(email);
      
      if (!exists) {
        throw Exception('No account found with this email address');
      }
      
      // Create a random 6-digit OTP
      final otp = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
      
      // Store the OTP in the database with an expiration time (15 minutes from now)
      final expiresAt = DateTime.now().add(const Duration(minutes: 15)).toIso8601String();
      
      // Check if there's an existing OTP for the user and update it
      final existingOtp = await client
          .from('password_reset_otps')
          .select()
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      
      if (existingOtp != null) {
        // Update the existing OTP
        await client
            .from('password_reset_otps')
            .update({
              'otp': otp,
              'expires_at': expiresAt,
              'used': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('email', email.toLowerCase().trim());
      } else {
        // Insert a new OTP
        await client
            .from('password_reset_otps')
            .insert({
              'email': email.toLowerCase().trim(),
              'otp': otp,
              'expires_at': expiresAt,
              'used': false,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
      }
      
     await client.functions.invoke(
  'send-password-reset-otp',
  body: {
    'email': email,
    'otp': otp,
  },
);


      
    } catch (e) {
      print('Error sending password reset OTP: $e');
      rethrow;
    }
  }

  /// Verify OTP for password reset
  static Future<bool> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      // Get the OTP entry from the database
      final otpEntry = await client
          .from('password_reset_otps')
          .select()
          .eq('email', email.toLowerCase().trim())
          .eq('otp', otp)
          .eq('used', false)
          .maybeSingle();
      
      if (otpEntry == null) {
        return false;
      }
      
      // Check if the OTP has expired
      final expiresAt = DateTime.parse(otpEntry['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        return false;
      }
      
      // Mark the OTP as used
      await client
          .from('password_reset_otps')
          .update({
            'used': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', otpEntry['id']);
      
      return true;
    } catch (e) {
      print('Error verifying password reset OTP: $e');
      return false;
    }
  }

  /// Reset password with OTP verification
  static Future<void> resetPasswordWithOTP({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Get user from profiles table
      final userData = await client
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      
      if (userData == null) {
        throw Exception('User not found');
      }
      
      // Try using the admin API for password reset
      try {
        final userId = userData['id'];
        await client.auth.admin.updateUserById(
          userId,
          attributes: AdminUserAttributes(
            password: newPassword,
          ),
        );
        
        // Update the profiles table to mark that the password was updated
        await client
            .from('profiles')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);
            
        return;
      } catch (adminError) {
        print('Admin API failed: $adminError');
        // Fall back to alternative method
      }
      
      // If admin API fails, use the password reset flow
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutterquickstart://reset-callback/',
      );
      
      throw Exception('Password reset initiated. A reset link has been sent to your email. Since we cannot access the reset link directly in the app, please check your email to complete the process.');
      
    } catch (e) {
      print('Error resetting password with OTP: $e');
      rethrow;
    }
  }
}