import 'package:coen_490/screens/registration/email_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '/utils/validation_utils.dart';
import '../dashboard/dashboard_screen.dart';
import 'auth_service.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('LoginPage');

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  
  // Animation controller for staggered animations
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the AppTheme from dashboard for consistency
    const Color primaryColor = Color(0xFF1D557E);
    const Color secondaryColor = Color(0xFFE6EDF7);
    
    return Scaffold(
      backgroundColor: secondaryColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative element (circle) in top left - mirrors auth page
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
            

            
            // Main content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 80.0, 24.0, 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Section
                      Text(
                        'Welcome Back',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ).animate(controller: _animationController)
                        .fadeIn(duration: 500.ms, delay: 100.ms)
                        .slideY(begin: -0.2, end: 0),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Sign in to continue to your account',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFF546E7A),
                          fontWeight: FontWeight.w400,
                        ),
                      ).animate(controller: _animationController)
                        .fadeIn(duration: 500.ms, delay: 200.ms)
                        .slideY(begin: -0.2, end: 0),
                      
                      const SizedBox(height: 40),
                      
                      // Email Field with validation
                      Container(
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
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF263238),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            labelStyle: GoogleFonts.inter(
                              color: const Color(0xFF78909C),
                              fontWeight: FontWeight.w500,
                            ),
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFFB0BEC5),
                            ),
                            prefixIcon: const Icon(
                              Icons.email_outlined, 
                              color: Color(0xFF78909C),
                            ),
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
                              borderSide: BorderSide.none,
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
                            errorText: _emailError,
                            errorStyle: GoogleFonts.inter(
                              color: Colors.redAccent,
                            ),
                          ),
                          validator: ValidationUtils.validateEmail,
                          onChanged: (value) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                        ),
                      ).animate(controller: _animationController)
                        .fadeIn(duration: 500.ms, delay: 300.ms)
                        .slideY(begin: 0.2, end: 0),
                      
                      const SizedBox(height: 20),
                      
                      // Password Field with validation
                      Container(
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
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF263238),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            labelStyle: GoogleFonts.inter(
                              color: const Color(0xFF78909C),
                              fontWeight: FontWeight.w500,
                            ),
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFFB0BEC5),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline, 
                              color: Color(0xFF78909C),
                            ),
                            suffixIcon: Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF78909C),
                                  size: 20,
                                ),
                                splashRadius: 24,
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
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
                              borderSide: BorderSide.none,
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
                            errorText: _passwordError,
                            errorStyle: GoogleFonts.inter(
                              color: Colors.redAccent,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                        ),
                      ).animate(controller: _animationController)
                        .fadeIn(duration: 500.ms, delay: 400.ms)
                        .slideY(begin: 0.2, end: 0),
                      
                      const SizedBox(height: 10),
                      
                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Handle forgot password
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: primaryColor.withAlpha(230), // 0.9 * 255 = 230
                            ),
                          ),
                        ),
                      ).animate(controller: _animationController)
                        .fadeIn(duration: 500.ms, delay: 500.ms),
                      
                      const SizedBox(height: 40),
                      
                      // Login Button
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
                          onPressed: _isLoading ? null : _login,
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
                                  'Sign In',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ).animate(controller: _animationController)
                        .fadeIn(duration: 500.ms, delay: 600.ms)
                        .slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _login() async {
    // First validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      _logger.info("Attempting to sign in with email");
      final userCredential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if widget is still mounted before using setState or context
      if (!mounted) return;

      if (userCredential?.user != null) {
        // Exception for specific test account
        final String specialUserId = "O9OlgUVX6RWjOFIjoqNk7Z4GZmi1";
        final String specialEmail = "sumit@gmail.com";

        // Check if email is verified or if this is our special test account
        if (!userCredential!.user!.emailVerified &&
            !(userCredential.user!.uid == specialUserId &&
                email == specialEmail)) {
          // Email is not verified and not our special account, send them to verification screen
          _logger
              .info("Email not verified, redirecting to verification screen");
          setState(() => _isLoading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(email: email),
            ),
          );
          return;
        }

        // Either email is verified OR this is our special test account, proceed with normal flow
        _logger.info("Login successful, proceeding with normal flow");
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

        if (args != null) {
          if (args['returnRoute'] == 'murmur_record' &&
              args['pendingAction'] == 'save_recording') {
            Navigator.pop(context, true);
            return; // exit _login
          } else if (args['returnRoute'] == 'recording_playback' &&
              args['pendingAction'] == 'view_recordings') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
            return; // exit _login
          }
        } else {
          // Normal login flow: Replace login with dashboard.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
          );
          return; // exit _login
        }
      } else {
        setState(() {
          _emailError = "Login failed";
        });
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.warning("Firebase auth exception: ${e.code}");
      String errorMessage;
      bool isEmailError = false;

      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          errorMessage = 'The email or password is incorrect';
          isEmailError = true;
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          isEmailError = true;
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          isEmailError = true;
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection';
          break;
        default:
          errorMessage = 'Login failed. Please try again';
      }

      // Check if widget is still mounted before using setState
      if (!mounted) return;

      setState(() {
        if (isEmailError) {
          _emailError = errorMessage;
        } else {
          _passwordError = errorMessage;
        }
      });
    } catch (e) {
      _logger.severe("Unexpected error during login: $e");

      // Check if widget is still mounted before using setState
      if (!mounted) return;

      setState(() {
        _passwordError = 'An unexpected error occurred. Please try again.';
      });
    }

    // If no navigation occurred, stop loading.
    // Check if widget is still mounted before using setState
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  }