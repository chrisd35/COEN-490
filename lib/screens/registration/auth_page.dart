import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'package:coen_490/screens/dashboard/dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart'; // For custom fonts


class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => AuthPageState();
}

class AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Create smooth fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    // Create subtle slide animation for buttons
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    // Create refined scale animation for logo
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack),
      ),
    );
    
    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method to handle guest sign-in with async safety
  Future<void> _handleGuestSignIn() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInAsGuest();
      
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Modern snackbar with less intrusive design
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Unable to access guest mode'),
            ],
          ),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for better sizing
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Logo color constant
    const logoBlue = Color(0xFF1D557E);
    
    return Scaffold(
      backgroundColor: const Color(0xFFE6EDF7), // Light blue that matches logo and screenshot
      extendBodyBehindAppBar: true, // Ensure content can go edge-to-edge
      body: Stack(
        children: [
          // Decorative element (circle) in top right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD6E1EF), // Slightly darker shade of background
              ),
            ),
          ),
          
          // Content Layer
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: MediaQuery.of(context).padding.bottom > 0 ? 16.0 : 24.0
              ), // Add different padding for devices with/without bottom notch
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0), // Add bottom padding
                child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // App Logo/Name Section moved higher on screen
                  Expanded(
                    flex: 5, // Increased flex for more central positioning
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // Center in the space
                      children: [
                        // Perfectly centered logo
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: child,
                            );
                          },
                          child: Center(
                            child: Container(
                              width: screenWidth, // Full screen width
                              alignment: Alignment.center, // Ensure center alignment
                              child: Image.asset(
                                'assets/images/respirhythm_logo.png',
                                width: screenWidth * 0.95, // 85% of screen width
                                height: screenWidth * 0.95, // Adjusted height ratio
                                fit: BoxFit.contain, // Preserve aspect ratio
                              ),
                            ),
                          ),
                        ),
                        // Space after logo - significantly reduced
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  
                  // Buttons Section moved lower
                  Expanded(
                    flex: 4, // Adjusted flex ratio
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end, // Position at bottom of space
                          children: [
                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                    transitionDuration: const Duration(milliseconds: 250),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: logoBlue, // Matches screenshot blue
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Log In',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Create Account button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => RegisterPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                    transitionDuration: const Duration(milliseconds: 250),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: logoBlue, // Matches screenshot blue
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: logoBlue, width: 1.0),
                                  ),
                                ),
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 34),
                            
                            // Guest sign-in option
                            GestureDetector(
                              onTap: _handleGuestSignIn,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 16,
                                    color: logoBlue.withAlpha(204),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Continue as Guest',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: logoBlue.withAlpha(204),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom Padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
      ),],
      ),
    );
  }
}