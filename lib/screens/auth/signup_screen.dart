import 'package:flutter/material.dart';
import 'package:hostel_connect/screens/auth/login_screen.dart';
import 'package:hostel_connect/services/supabase_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _selectedRole = 'student'; // Default role
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Prepare user data for the profiles table
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      
      final userData = {
        'first_name': firstName,
        'last_name': lastName,
        'display_name': '$firstName $lastName',
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
      };
      
      // Sign up with updated SupabaseService
      await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userData: userData,
      );

      // Handle successful signup
      if (mounted) {
        _showSuccessMessage();
        
        // Navigate to login after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred during signup: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _getRoleName(String role) {
    return role == 'owner' ? 'Hostel Owner' : 'Student';
  }

  @override
  Widget build(BuildContext context) {
    // The rest of the widget build method remains unchanged
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF324054)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and Welcome Text
                    _buildHeader(),
                    
                    // Error Message if any
                    if (_errorMessage != null) _buildErrorMessage(),
                    
                    // Form Fields
                    _buildNameFields(),
                    const SizedBox(height: 16),
                    _buildContactFields(),
                    const SizedBox(height: 24),
                    _buildRoleSelector(),
                    const SizedBox(height: 24),
                    _buildPasswordFields(),
                    const SizedBox(height: 24),
                    _buildRoleIndicator(),
                    const SizedBox(height: 24),
                    
                    // Sign Up Button
                    _buildSignUpButton(),
                    const SizedBox(height: 40),
                    
                    // Login Link
                    _buildLoginLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Rest of the widget methods remain the same...
  // Including _buildHeader(), _buildErrorMessage(), etc.
  
  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.home_work_rounded,
              size: 40,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Create Account",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please fill in the details to create your account",
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF324054).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildNameFields() {
    return Row(
      children: [
        // First Name Field
        Expanded(
          child: TextFormField(
            controller: _firstNameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your first name';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: "First Name",
              hintText: "Enter your first name",
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Last Name Field
        Expanded(
          child: TextFormField(
            controller: _lastNameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your last name';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: "Last Name",
              hintText: "Enter your last name",
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactFields() {
    return Column(
      children: [
        // Email Field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegExp.hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
          decoration: const InputDecoration(
            labelText: "Email Address",
            hintText: "Enter your email",
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        // Phone Field
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
          decoration: const InputDecoration(
            labelText: "Phone Number",
            hintText: "Enter your phone number",
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRole,
                isExpanded: true,
                hint: const Text("Select your role"),
                items: [
                  DropdownMenuItem(
                    value: 'student',
                    child: const Text("Student"),
                  ),
                  DropdownMenuItem(
                    value: 'owner',
                    child: const Text("Hostel Owner"),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      children: [
        // Password Field
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: "Password",
            hintText: "Create a password",
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Confirm Password Field
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: "Confirm Password",
            hintText: "Confirm your password",
            prefixIcon: const Icon(Icons.lock_outline),
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
      ],
    );
  }

  Widget _buildRoleIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _selectedRole == 'owner' ? Icons.business : Icons.school,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Text(
            "Signing up as: ${_getRoleName(_selectedRole)}",
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signUp,
      style: ElevatedButton.styleFrom(
        disabledBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.6),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              "Sign Up",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: TextStyle(
            color: const Color(0xFF324054).withOpacity(0.7),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          },
          child: Text(
            "Log In",
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}