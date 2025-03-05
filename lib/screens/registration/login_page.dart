import 'package:coen_490/screens/registration/email_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import '/utils/validation_utils.dart'; // Import the new validation utilities
import '../dashboard/dashboard_screen.dart';
import 'auth_service.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('LoginPage');

class LoginPage extends StatefulWidget {
  // Use super parameter syntax for key
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>(); // Add form key for validation
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  // Logo or App Name
                  Center(
                    child: Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Sign in to continue',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Email Field with validation
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
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
                      errorText: _emailError,
                    ),
                    validator: ValidationUtils.validateEmail,
                    onChanged: (value) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Password Field with validation
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
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
                      errorText: _passwordError,
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
                  const SizedBox(height: 24),
                  // Login Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Sign In',
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
        // Check if email is verified
        if (!userCredential!.user!.emailVerified) {
          // Email is not verified, send them to verification screen
          _logger.info("Email not verified, redirecting to verification screen");
          setState(() => _isLoading = false);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(email: email),
            ),
          );
          return;
        }
        
        // Email is verified, proceed with normal flow
        _logger.info("Login successful, email verified");
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

        if (args != null) {
          if (args['returnRoute'] == 'murmur_record' && args['pendingAction'] == 'save_recording') {
            Navigator.pop(context, true);
            return; // exit _login
          } else if (args['returnRoute'] == 'recording_playback' && args['pendingAction'] == 'view_recordings') {
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
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
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