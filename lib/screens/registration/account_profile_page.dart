import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'firebase_service.dart';
import '../../utils/models.dart';
import 'auth_service.dart';
import '/utils/validation_utils.dart';
import 'email_verification_screen.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('AccountProfilePage');

class AccountProfilePage extends StatefulWidget {
  final String? selectedRole;
  final String? returnRoute;
  final String? pendingAction;

  // Use const constructor with key parameter using super
  const AccountProfilePage({
    super.key,
    this.selectedRole,
    this.returnRoute,
    this.pendingAction,
  });

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Controllers for text fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _selectedGender;
  String? _selectedRole;

  // For additional validation feedback
  String? _passwordStrengthFeedback;
  bool _showPasswordStrength = false;
  Color _passwordStrengthColor = Colors.grey;
  
  // For email validation
  bool _isCheckingEmail = false;
  bool _isEmailValid = false;
  String? _emailError;
  Timer? _emailDebounce;
  bool _isRolePreselected = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.selectedRole;
    _isRolePreselected = widget.selectedRole != null;
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dateOfBirthController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // Password strength indicator
  void _updatePasswordStrength(String password) {
    setState(() {
      _showPasswordStrength = password.isNotEmpty;
      
      if (password.isEmpty) {
        _passwordStrengthFeedback = null;
        _passwordStrengthColor = Colors.grey;
        return;
      }
      
      if (password.length < 8) {
        _passwordStrengthFeedback = 'Weak';
        _passwordStrengthColor = Colors.red;
        return;
      }
      
      bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
      bool hasDigits = password.contains(RegExp(r'[0-9]'));
      bool hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      bool hasMinLength = password.length >= 8;
      
      if (hasUppercase && hasDigits && hasSpecialChars && hasMinLength) {
        _passwordStrengthFeedback = 'Strong';
        _passwordStrengthColor = Colors.green;
      } else if ((hasUppercase || hasSpecialChars) && hasDigits && hasMinLength) {
        _passwordStrengthFeedback = 'Moderate';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrengthFeedback = 'Weak';
        _passwordStrengthColor = Colors.red;
      }
    });
  }
  
  // Email availability checker
  Future<void> _checkEmailAvailability() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _isEmailValid = false;
        _emailError = null;
      });
      return;
    }
    
    // Use the comprehensive format validation
    bool isFormatValid = ValidationUtils.isEmailFormatValid(email);
    if (!isFormatValid) {
      setState(() {
        _isEmailValid = false;
        _emailError = null; // Don't show error yet, validator will show it on submission
      });
      return;
    }
    
    setState(() => _isCheckingEmail = true);
    
    try {
      // Check if email is already registered
      bool isRegistered = await _authService.isEmailRegistered(email);
      
      if (!mounted) return;
      
      setState(() {
        _emailError = isRegistered ? 
            'This email is already registered. Please try logging in or use a different email.' : 
            null;
        _isEmailValid = !isRegistered && isFormatValid;  // Only valid if properly formatted AND not registered
        _isCheckingEmail = false;
      });
    } catch (e) {
      _logger.severe('Error checking email availability: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isEmailValid = false;
        _isCheckingEmail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Create Your Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Picture Placeholder
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Theme.of(context).primaryColor.withAlpha(26), // Using withAlpha(26) instead of withOpacity(0.1)
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  size: 50,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form Fields with improved validation
                        _buildTextField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: ValidationUtils.validateName,
                        ),
                        const SizedBox(height: 16),

                        // Email field with real-time availability check
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: ValidationUtils.validateEmail,
                          errorText: _emailError,
                          suffix: _isCheckingEmail 
                            ? const SizedBox(
                                height: 16, 
                                width: 16, 
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ) 
                            : _emailController.text.isNotEmpty && 
                              _isEmailValid && 
                              _emailError == null && 
                              ValidationUtils.isEmailFormatValid(_emailController.text.trim())
                              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                              : _emailController.text.isNotEmpty && 
                                (!_isEmailValid || _emailError != null || !ValidationUtils.isEmailFormatValid(_emailController.text.trim()))
                                ? const Icon(Icons.error, color: Colors.red, size: 20)
                                : null,
                          onChanged: (value) {
                            // Clear previous validations
                            if (_emailError != null || _isEmailValid) {
                              setState(() {
                                _emailError = null;
                                _isEmailValid = false;  // Reset validation state when email changes
                              });
                            }
                            
                            // Debounce the check to avoid too many requests
                            if (_emailDebounce?.isActive ?? false) _emailDebounce!.cancel();
                            _emailDebounce = Timer(const Duration(milliseconds: 800), () {
                              _checkEmailAvailability();
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          validator: ValidationUtils.validatePassword,
                          onChanged: _updatePasswordStrength,
                        ),
                        
                        // Password strength indicator
                        if (_showPasswordStrength)
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  'Password Strength: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  _passwordStrengthFeedback ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _passwordStrengthColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value!.isEmpty) return 'Required';
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Date of Birth with improved validation
                        GestureDetector(
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null && mounted) {
                              setState(() {
                                _dateOfBirthController.text =
                                    "${pickedDate.toLocal()}".split(' ')[0];
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: _buildTextField(
                              controller: _dateOfBirthController,
                              label: 'Date of Birth',
                              prefixIcon: Icons.calendar_today_rounded,
                              validator: ValidationUtils.validateDateOfBirth,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Gender Dropdown
                        _buildDropdownField(
                          value: _selectedGender,
                          label: 'Gender',
                          prefixIcon: Icons.person_outline_rounded,
                          items: const ['Male', 'Female', 'Other'],
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          },
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Role Dropdown
                        _buildDropdownField(
                          value: _selectedRole,
                          label: 'Role',
                          prefixIcon: Icons.work_outline_rounded,
                          items: const ['Medical Professional', 'Student'],
                          onChanged: _isRolePreselected ? null : (value) {
                            setState(() {
                              _selectedRole = value;
                            });
                          },
                          validator: (value) => value == null ? 'Required' : null,
                          isPreselected: _isRolePreselected,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: ValidationUtils.validatePhoneNumber,
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build consistent text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    Widget? suffix,
    String? errorText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon, color: Colors.grey[600], size: 22),
        suffixIcon: suffixIcon,
        suffix: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.white,
        errorText: errorText,
      ),
      validator: validator,
    );
  }

  // Helper method to build consistent dropdown fields
  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData prefixIcon,
    required List<String> items,
    required void Function(String?)? onChanged,
    required String? Function(String?)? validator,
    bool isPreselected = false,  // Parameter to indicate if this field was pre-selected
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon, color: Colors.grey[600], size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isPreselected ? Theme.of(context).primaryColor : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: isPreselected ? Colors.grey[50] : Colors.white,
        // Add a suffix icon to indicate it's preselected
        suffixIcon: isPreselected 
            ? const Tooltip(
                message: 'Role pre-selected',
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ) 
            : null,
      ),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: isPreselected ? null : onChanged,  // Disable dropdown if preselected
      validator: validator,
    );
  }

  // Submit form logic with improved error handling
  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      // Form validation failed - show a message to fix errors
      _showErrorMessage('Please correct the errors in the form.');
      return;
    }
    
    // Check for email error
    if (_emailError != null) {
      _showErrorMessage(_emailError!);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Double check if email is already registered
      try {
        bool isRegistered = await _authService.isEmailRegistered(email);
        
        if (!mounted) return;
        
        if (isRegistered) {
          _showErrorMessage('This email is already registered. Please try logging in or use a different email.');
          setState(() => _isLoading = false);
          return;
        }
        
        // Proceed with registration
        final user = await _authService.register(email, password);

        if (!mounted) return;
        
        if (user != null) {
          // Format phone number
          String formattedPhone = ValidationUtils.formatPhoneNumber(_phoneNumberController.text);
          
          User newUser = User(
            fullName: _fullNameController.text.trim(),
            email: email,
            password: password, // Consider not storing the password in the database
            dateOfBirth: _dateOfBirthController.text,
            gender: _selectedGender!,
            role: _selectedRole!,
            phoneNumber: formattedPhone,
            uid: user.uid,
          );

          await _firebaseService.saveUser(newUser);

          if (!mounted) return;
          
          _formKey.currentState!.reset();
          _showSuccessMessage('Account created successfully! Please verify your email.');

          // Check if we need to return to murmur record
          final returnToMurmurRecord = widget.returnRoute == 'murmur_record';
          
          if (returnToMurmurRecord) {
            // Pop back through the navigation stack with success result
            Navigator.of(context).pop(true);  // Pop AccountProfilePage
          } else {
            // Navigate to email verification screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(email: email),
              ),
            );
          }
        }
      } on firebase_auth.FirebaseAuthException catch (e) {
        _logger.severe('Firebase auth exception: ${e.code}');
        
        if (!mounted) return;
        
        String errorMessage;
        
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'This email is already registered. Please try logging in or use a different email.';
            break;
          case 'invalid-email':
            errorMessage = 'Please provide a valid email address.';
            break;
          case 'weak-password':
            errorMessage = 'The password you provided is too weak. Please choose a stronger password.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Account creation is currently disabled. Please try again later.';
            break;
          default:
            errorMessage = 'Registration failed: ${e.message}';
        }
        
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _logger.severe('Unexpected error during registration: $e');
      
      if (!mounted) return;
      _showErrorMessage('Registration failed. Please check your information and try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}