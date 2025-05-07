import 'package:flutter/material.dart';
import 'package:hostel_connect/screens/student/bookings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import 'package:hostel_connect/services/supabase_service.dart';

final supabase = Supabase.instance.client;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _userData = {
    'name': 'User',
    'email': 'No email provided',
    'phone': 'No phone provided',
    'profileImage': 'assets/images/profile.jpg',
    'role': 'user',
  };
  bool _isLoading = true;

  // Profile editing controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isUpdatingProfile = false;

  // Password change controllers
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _deleteAccountPasswordController = TextEditingController();
  
  // Visibility toggles
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureDeletePassword = true;
  
  // Loading states
  bool _isChangingPassword = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deleteAccountPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.currentUser;
      
      if (user != null) {
        // Load profile data from Supabase
        final profileData = await SupabaseService.getCurrentUserProfile();
        
        if (profileData != null) {
          // Fix: Proper null handling for phone value and additional debug info
          String phoneValue = profileData['phone'] ?? '';
          print('Raw phone value: "$phoneValue", Type: ${phoneValue.runtimeType}');
          
          // Ensure trimming and proper null handling
          phoneValue = phoneValue.toString().trim();
          if (phoneValue.isEmpty) {
            phoneValue = 'No phone provided';
          }
          
          setState(() {
            _userData = {
              'name': '${profileData['first_name'] ?? ''} ${profileData['last_name'] ?? ''}'.trim(),
              'email': profileData['email'] ?? user.email ?? 'No email provided',
              'phone': phoneValue,
              'profileImage': profileData['avatar_url'] ?? 'assets/images/profile.jpg',
              'role': _getRoleDisplayName(profileData['role'] ?? 'user'),
            };
          });
          
          // Debug log to check phone value
          print('Phone from database after processing: ${_userData['phone']}');
        } else {
          // Fallback to auth user data if no profile exists
          final userMetadata = user.userMetadata;
          setState(() {
            _userData = {
              'name': userMetadata?['full_name'] ?? 'User',
              'email': user.email ?? 'No email provided',
              'phone': userMetadata?['phone'] ?? 'No phone provided',
              'profileImage': 'assets/images/profile.jpg',
              'role': _getRoleDisplayName(userMetadata?['role'] ?? 'user'),
            };
          });
          
          // Debug log for metadata
          print('User metadata: $userMetadata');
        }
      }
    } catch (e) {
      // Fallback if any error occurs
      final user = SupabaseService.currentUser;
      if (user != null && mounted) {
        setState(() {
          _userData = {
            'name': user.userMetadata?['full_name'] ?? 'User',
            'email': user.email ?? 'No email provided',
            'phone': user.userMetadata?['phone'] ?? 'No phone provided',
            'profileImage': 'assets/images/profile.jpg',
            'role': 'user',
          };
        });
      }
      _showSnackBar('Failed to load user data: ${e.toString()}', isError: true);
      print('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'owner':
        return 'Hostel Owner';
      default:
        return role.isNotEmpty ? role : 'User';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final user = SupabaseService.currentUser;
    
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    // Get current profile data to preserve other fields
    final currentProfile = await SupabaseService.getCurrentUserProfile();
    
    // Update profile in Supabase
    await supabase.from('profiles').upsert({
      'id': user.id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': user.email,
      'role': currentProfile?['role'] ?? 'user',
      'avatar_url': currentProfile?['avatar_url'],
      'updated_at': DateTime.now().toIso8601String(),
    }).match({'id': user.id});
  }

  void _showEditProfileDialog() {
    // Initialize the controllers with current values
    _firstNameController.text = _userData['name'].toString().split(' ')[0];
    if (_userData['name'].toString().split(' ').length > 1) {
      _lastNameController.text = _userData['name'].toString().split(' ').sublist(1).join(' ');
    } else {
      _lastNameController.text = '';
    }
    _phoneController.text = _userData['phone'] != 'No phone provided' ? _userData['phone'] : '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _firstNameController.clear();
                  _lastNameController.clear();
                  _phoneController.clear();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isUpdatingProfile
                    ? null
                    : () async {
                        if (_firstNameController.text.isEmpty) {
                          _showSnackBar('First name cannot be empty', isError: true);
                          return;
                        }

                        setState(() {
                          _isUpdatingProfile = true;
                        });

                        try {
                          await _updateProfile(
                            firstName: _firstNameController.text,
                            lastName: _lastNameController.text,
                            phone: _phoneController.text,
                          );
                          
                          if (!mounted) return;
                          
                          Navigator.pop(context);
                          
                          _firstNameController.clear();
                          _lastNameController.clear();
                          _phoneController.clear();
                          
                          _showSnackBar('Profile updated successfully');
                          
                          // Reload user data to reflect changes
                          await _loadUserData();
                          
                        } catch (e) {
                          _showSnackBar('Failed to update profile: ${e.toString()}', isError: true);
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isUpdatingProfile = false;
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6FE3),
                ),
                child: _isUpdatingProfile
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text.isEmpty) {
      _showSnackBar('Please enter a new password', isError: true);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      await SupabaseService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      
      _showSnackBar('Password updated successfully. Please login with your new password.');
      Navigator.pop(context);
      
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      
      await _logoutAfterDelay();
      
    } catch (e) {
      _showSnackBar('Failed to update password: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _logoutAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    try {
      await SupabaseService.signOut();
      
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to logout: ${e.toString()}', isError: true);
      }
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrentPassword,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Note: You'll be logged out automatically after changing your password.",
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
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
                onPressed: _isChangingPassword ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6FE3),
                ),
                child: _isChangingPassword
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Update Password'),
              ),
            ],
          );
        }
      ),
    );
  }

  // Update this method in your ProfileScreen class
void _showDeleteAccountDialog() {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Color(0xFFF75676)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Warning: This action cannot be undone. All your data will be permanently deleted.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please enter your password to confirm account deletion:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _deleteAccountPasswordController,
                  obscureText: _obscureDeletePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureDeletePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureDeletePassword = !_obscureDeletePassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _deleteAccountPasswordController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isDeleting
                  ? null
                  : () async {
                      if (_deleteAccountPasswordController.text.isEmpty) {
                        _showSnackBar('Please enter your password', isError: true);
                        return;
                      }

                      setState(() {
                        _isDeleting = true;
                      });

                      try {
                        // Show a confirmation dialog first
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Deletion'),
                            content: const Text(
                              'Are you absolutely sure you want to delete your account? '
                              'This action cannot be undone and all your data will be permanently lost.',
                              style: TextStyle(fontSize: 16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFF75676),
                                ),
                                child: const Text('Yes, Delete My Account'),
                              ),
                            ],
                          ),
                        ) ?? false;

                        if (!shouldDelete || !mounted) {
                          setState(() {
                            _isDeleting = false;
                          });
                          Navigator.pop(context); // Close dialog
                          return;
                        }

                        // Proceed with deletion
                        await SupabaseService.deleteAccount(
                          password: _deleteAccountPasswordController.text,
                        );
                        
                        if (!mounted) return;
                        
                        Navigator.pop(context); // Close dialog
                        _deleteAccountPasswordController.clear();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your account has been deleted successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        
                        // Redirect to login screen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                        
                      } catch (e) {
                        if (!mounted) return;
                        
                        String errorMessage = 'Failed to delete account';
                        if (e.toString().contains('Password is incorrect')) {
                          errorMessage = 'Password is incorrect';
                        } else {
                          errorMessage = '${errorMessage}: ${e.toString()}';
                        }
                        
                        Navigator.pop(context); // Close dialog
                        _showSnackBar(errorMessage, isError: true);
                        
                        setState(() {
                          _isDeleting = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF75676),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Delete Account'),
            ),
          ],
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF324054)),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadUserData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4A6FE3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: (_userData['profileImage'] as String).startsWith('assets/')
                              ? Image.asset(
                                  _userData['profileImage'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFF1F3F6),
                                      child: const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Color(0xFF4A6FE3),
                                      ),
                                    );
                                  },
                                )
                              : Image.network(
                                  _userData['profileImage'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFF1F3F6),
                                      child: const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Color(0xFF4A6FE3),
                                      ),
                                    );
                                  },
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData['name'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324054),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userData['email'],
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color(0xFF324054).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoItem('Full Name', _userData['name'], Icons.person_outlined),
                        const Divider(),
                        _buildInfoItem('Email', _userData['email'], Icons.email_outlined),
                        const Divider(),
                        _buildInfoItem('Phone', _userData['phone'], Icons.phone_outlined),
                        const Divider(),
                        _buildInfoItem('Role', _userData['role'], Icons.verified_user_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Account Settings",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324054),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsItem(
                          'Change Password',
                          'Update your account password',
                          Icons.lock_outline,
                          _showChangePasswordDialog,
                        ),
                        _buildSettingsItem(
                          'My Bookings',
                          'View your active and past hostel bookings',
                          Icons.bookmark_outlined,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => BookingsScreen()),
                            );
                          },
                        ),
                        
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Logout button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF75676), Color(0xFFE83A5D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF75676).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            // Show a stylish dialog with animation
                            final bool? shouldLogout = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext dialogContext) => Dialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF75676).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.logout_rounded,
                                          color: Color(0xFFF75676),
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Confirm Logout',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF324054),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Are you sure you want to logout from your account?',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => Navigator.pop(dialogContext, false),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                side: const BorderSide(color: Color(0xFF4A6FE3)),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF4A6FE3),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.pop(dialogContext, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFF75676),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text(
                                                'Logout',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            
                            if (shouldLogout == true) {
                              try {
                                await SupabaseService.signOut();
                                
                                if (!mounted) return;
                                
                                // Add a quick fade out animation before navigating
                                Navigator.of(context).pushAndRemoveUntil(
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                  (route) => false,
                                );
                              } catch (e) {
                                if (mounted) {
                                  _showSnackBar('Failed to logout: ${e.toString()}', isError: true);
                                }
                              }
                            }
                          },
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Add space between buttons
                  const SizedBox(height: 16),
                  
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF4A6FE3),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF324054).withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF324054),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4A6FE3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4A6FE3),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF324054),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF324054).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }
}