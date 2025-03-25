import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for LengthLimitingTextInputFormatter
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';
import '../../utils/models.dart';
import 'auth_service.dart';
import '/utils/validation_utils.dart';
import 'email_verification_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('AccountProfilePage');

class AccountProfilePage extends StatefulWidget {
  final String? selectedRole;
  final String? returnRoute;
  final String? pendingAction;

  const AccountProfilePage({
    super.key,
    this.selectedRole,
    this.returnRoute,
    this.pendingAction,
  });

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  late AnimationController _animationController;

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
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Start the animation
    _animationController.forward();
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
    _animationController.dispose();
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
  
  // Enhanced date of birth validator to ensure user is at least 18 years old
  String? validateDateOfBirth(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date of birth is required';
    }
    
    try {
      final date = DateTime.parse(value);
      final today = DateTime.now();
      final age = today.year - date.year - 
          (today.month < date.month || (today.month == date.month && today.day < date.day) ? 1 : 0);
      
      if (age < 18) {
        return 'You must be at least 18 years old';
      }
    } catch (e) {
      return 'Invalid date format';
    }
    
    return null;
  }
  
  // Enhanced phone number validator to limit to 15 digits maximum
  String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.isEmpty) {
      return 'Please enter a valid phone number';
    }
    
    if (digitsOnly.length > 15) {
      return 'Phone number should not exceed 15 digits';
    }
    
    return null;
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
    // App theme colors for consistency
    const Color primaryColor = Color(0xFF1D557E);
    const Color secondaryColor = Color(0xFFE6EDF7);
    const Color textPrimary = Color(0xFF263238);
    const Color textSecondary = Color(0xFF546E7A);
    const Color textLight = Color(0xFF78909C);
    
    return Scaffold(
      backgroundColor: secondaryColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative element (circle) in top left
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD6E1EF), // Slightly darker shade of background
                ),
              ),
            ),
            
            Column(
              children: [
                // Custom App Bar with refined styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Back button with refined styling
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      
                      Expanded(
                        child: Text(
                          'Create Your Profile',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 500.ms),
                      ),
                      
                      // Empty container to balance the back button
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Section with refined typography
                            Center(
                              child: Text(
                                'Your Information',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: -0.5,
                                ),
                              ).animate(controller: _animationController)
                                .fadeIn(duration: 500.ms, delay: 100.ms)
                                .slideY(begin: -0.2, end: 0),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Center(
                              child: Text(
                                'Please fill in your details to create your account',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ).animate(controller: _animationController)
                                .fadeIn(duration: 500.ms, delay: 200.ms)
                                .slideY(begin: -0.1, end: 0),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Form Fields with animations and consistent styling
                            _buildTextField(
                              controller: _fullNameController,
                              label: 'Full Name',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: ValidationUtils.validateName,
                              delay: 300,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryColor,
                                    ),
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
                              delay: 400,
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: !_isPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible 
                                    ? Icons.visibility_off_rounded 
                                    : Icons.visibility_rounded,
                                  color: textLight,
                                  size: 20,
                                ),
                                splashRadius: 24,
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              validator: ValidationUtils.validatePassword,
                              onChanged: _updatePasswordStrength,
                              delay: 500,
                            ),
                            
                            // Password strength indicator with improved styling
                            if (_showPasswordStrength)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0, top: 6.0),
                                child: Row(
                                  children: [
                                    Text(
                                      'Password Strength: ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _passwordStrengthFeedback ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: _passwordStrengthColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate()
                                .fadeIn(duration: 300.ms),
                                
                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: !_isConfirmPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible 
                                    ? Icons.visibility_off_rounded 
                                    : Icons.visibility_rounded,
                                  color: textLight,
                                  size: 20,
                                ),
                                splashRadius: 24,
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
                              delay: 600,
                            ),
                            const SizedBox(height: 16),

                            // Date of Birth with improved styling and age verification
                            GestureDetector(
                              onTap: () async {
                                final DateTime eighteenYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 18));
                                
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: eighteenYearsAgo,
                                  firstDate: DateTime(1900),
                                  lastDate: eighteenYearsAgo, // Limit to dates at least 18 years ago
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: primaryColor,
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: textPrimary,
                                        ),
                                        dialogBackgroundColor: Colors.white,
                                      ),
                                      child: child!,
                                    );
                                  },
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
                                  validator: validateDateOfBirth,
                                  delay: 700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Gender Dropdown with enhanced styling
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
                              delay: 800,
                            ),
                            const SizedBox(height: 16),

                            // Role Dropdown with enhanced styling
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
                              delay: 900,
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: _phoneNumberController,
                              label: 'Phone Number',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: validatePhoneNumber,
                              delay: 1000,
                            ),
                            const SizedBox(height: 40),

                            // Submit Button with enhanced styling
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withAlpha(40),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: primaryColor.withAlpha(153), // 0.6 * 255 = 153
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ).animate(controller: _animationController)
                              .fadeIn(duration: 500.ms, delay: 1100.ms)
                              .slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
// Helper method to build consistent text fields with animations
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
    required int delay,
  }) {
    const Color textLight = Color(0xFF78909C);
    const Color primaryColor = Color(0xFF1D557E);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: onChanged,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFF263238),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: textLight,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFB0BEC5),
          ),
          prefixIcon: Icon(
            prefixIcon, 
            color: textLight, 
            size: 20,
          ),
          suffixIcon: suffixIcon,
          suffix: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          filled: true,
          fillColor: Colors.white,
          errorText: errorText,
          errorStyle: GoogleFonts.inter(
            color: Colors.redAccent,
            fontSize: 12,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        validator: validator,
      ),
    ).animate(controller: _animationController)
      .fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay))
      .slideY(begin: 0.2, end: 0);
  }

  // Helper method to build consistent dropdown fields with animations
  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData prefixIcon,
    required List<String> items,
    required void Function(String?)? onChanged,
    required String? Function(String?)? validator,
    bool isPreselected = false,
    required int delay,
  }) {
    const Color textLight = Color(0xFF78909C);
    const Color primaryColor = Color(0xFF1D557E);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFF263238),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: textLight,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            prefixIcon, 
            color: textLight, 
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: isPreselected 
                ? const BorderSide(color: primaryColor, width: 1) 
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
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
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: textLight,
          size: 24,
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(controller: _animationController)
      .fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay))
      .slideY(begin: 0.2, end: 0);
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

  // Refined success message with modern styling
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Refined error message with modern styling
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
  