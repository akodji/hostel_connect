import 'package:flutter/material.dart';
import 'package:hostel_connect/services/supabase_service.dart';
import 'package:hostel_connect/screens/auth/login_screen.dart';
import 'dart:async';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Step tracker for the password reset flow
  // 1: Enter email, 2: Enter OTP, 3: Enter new password
  int _currentStep = 1;
  
  // Timer for OTP resend cooldown
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // Send OTP to the email address
  Future<void> _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await SupabaseService.sendPasswordResetOTP(_emailController.text.trim());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent to your email address'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Move to the next step
          setState(() {
            _currentStep = 2;
            _isLoading = false;
          });
          
          // Start the cooldown timer
          _startResendCooldown();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  // Verify OTP and move to the next step
  Future<void> _verifyOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final isValid = await SupabaseService.verifyPasswordResetOTP(
          email: _emailController.text.trim(),
          otp: _otpController.text.trim(),
        );
        
        if (mounted) {
          if (isValid) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP verified successfully'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Move to the next step
            setState(() {
              _currentStep = 3;
              _isLoading = false;
            });
          } else {
            setState(() {
              _errorMessage = 'Invalid or expired OTP. Please try again.';
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  // Reset password with OTP verification
  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await SupabaseService.resetPasswordWithOTP(
          email: _emailController.text.trim(),
          newPassword: _newPasswordController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password has been reset successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to login screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } catch (e) {
        String errorMessage = e.toString();
        
        // Check if this is our special message about email reset
        if (errorMessage.contains('Password reset initiated')) {
          // Show a more helpful message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset email sent. Please check your email to complete the process.'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 8),
              ),
            );
            
            // Navigate back to login screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
          return;
        }
        
        // Otherwise, show the error
        if (mounted) {
          setState(() {
            _errorMessage = errorMessage;
            _isLoading = false;
          });
        }
      }
    }
  }

  // Start the cooldown timer for OTP resend
  void _startResendCooldown() {
    setState(() {
      _resendSeconds = 60; // 1 minute cooldown
    });
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _resendTimer?.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF324054)),
          onPressed: () {
            if (_currentStep > 1) {
              // Go back to previous step
              setState(() {
                _currentStep--;
                _errorMessage = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Color(0xFF324054)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                
                // Progress indicator
                _buildStepIndicator(),
                
                // Error Message if any
                if (_errorMessage != null) _buildErrorMessage(),
                
                // Content based on current step
                _currentStep == 1
                    ? _buildEmailStep()
                    : _currentStep == 2
                        ? _buildOTPStep()
                        : _buildPasswordStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = "Reset Password";
    String subtitle = "";
    IconData icon = Icons.lock_reset;
    
    switch (_currentStep) {
      case 1:
        subtitle = "Enter your email to receive a one-time password";
        break;
      case 2:
        subtitle = "Enter the OTP sent to your email";
        icon = Icons.pin;
        break;
      case 3:
        subtitle = "Create a new secure password";
        icon = Icons.lock_open;
        break;
    }
  
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 70,
          color: Theme.of(context).primaryColor.withOpacity(0.7),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF324054),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: const Color(0xFF324054).withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          _buildStepCircle(1, "Email"),
          _buildStepConnector(1),
          _buildStepCircle(2, "OTP"),
          _buildStepConnector(2),
          _buildStepCircle(3, "Password"),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
              border: isCurrent 
                  ? Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                      width: 4,
                    )
                  : null,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive 
                  ? const Color(0xFF324054) 
                  : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int beforeStep) {
    final isActive = _currentStep > beforeStep;
    
    return Expanded(
      child: Container(
        height: 3,
        color: isActive 
            ? Theme.of(context).primaryColor 
            : Colors.grey.shade300,
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
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Email Address",
            hintText: "Enter your registered email",
            prefixIcon: Icon(Icons.email_outlined),
          ),
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
        ),
        const SizedBox(height: 32),
        
        ElevatedButton(
          onPressed: _isLoading ? null : _sendOTP,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                  "Send OTP",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOTPStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: "One-Time Password",
            hintText: "Enter the 6-digit code sent to your email",
            prefixIcon: Icon(Icons.pin),
            counterText: "",
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the OTP';
            }
            if (value.length != 6) {
              return 'OTP must be 6 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextButton(
          onPressed: _resendSeconds > 0 ? null : () {
            _sendOTP();
          },
          child: Text(
            _resendSeconds > 0 
                ? "Resend OTP in $_resendSeconds seconds" 
                : "Resend OTP",
            style: TextStyle(
              color: _resendSeconds > 0 
                  ? Colors.grey 
                  : Theme.of(context).primaryColor,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOTP,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                  "Verify OTP",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // New Password
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: "New Password",
            hintText: "Enter your new password",
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a new password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        
        // Confirm New Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: "Confirm New Password",
            hintText: "Confirm your new password",
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your new password';
            }
            if (value != _newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 32),
        
        ElevatedButton(
          onPressed: _isLoading ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                  "Reset Password",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}