import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'package:coen_490/screens/dashboard/dashboard_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => AuthPageState();
}

// Changed from private to public class
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
      duration: const Duration(milliseconds: 1500),
    );
    
    // Create fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    // Create slide animation for buttons
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    // Create scale animation for logo
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error accessing guest mode. Please try again.'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image with Gradient Overlay
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/homepage.jpg'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(26), // Using withAlpha instead of withOpacity(0.1)
                      Colors.black.withAlpha(153), // Using withAlpha instead of withOpacity(0.6)
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Content Layer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // App Logo/Name Section
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Logo
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: child,
                            );
                          },
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1800),
                            builder: (context, value, child) {
                              return Transform.rotate(
                                angle: (1.0 - value) * 0.3,
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 90,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Animated App Name
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            'RespiRhythm',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withAlpha(128), // Using withAlpha instead of withOpacity(0.5)
                                  offset: const Offset(1, 1),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Animated Tagline
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.5),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
                            ),
                          ),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              'All-in-one medical tool',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withAlpha(230), // Using withAlpha instead of withOpacity(0.9)
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Buttons Section
                  Expanded(
                    flex: 2,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Login Button with hover effect
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.95 + (0.05 * value),
                                  child: child,
                                );
                              },
                              child: SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        var begin = const Offset(1.0, 0.0);
                                        var end = Offset.zero;
                                        var curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        return SlideTransition(position: animation.drive(tween), child: child);
                                      },
                                      transitionDuration: const Duration(milliseconds: 300),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    elevation: 2,
                                    shadowColor: Colors.black.withAlpha(77), // Using withAlpha instead of withOpacity(0.3)
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Sign Up Button with animation
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.95 + (0.05 * value),
                                  child: child,
                                );
                              },
                              child: SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => RegisterPage(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        var begin = const Offset(1.0, 0.0);
                                        var end = Offset.zero;
                                        var curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        return SlideTransition(position: animation.drive(tween), child: child);
                                      },
                                      transitionDuration: const Duration(milliseconds: 300),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: Colors.white, width: 2),
                                    ),
                                  ),
                                  child: const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Guest Button with animation
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 200),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: 0.7 + (0.3 * value),
                                  child: child,
                                );
                              },
                              child: TextButton(
                                onPressed: _handleGuestSignIn,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Continue as Guest',
                                      style: TextStyle(
                                        fontSize: 16,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white.withAlpha(128), // Using withAlpha instead of withOpacity(0.5)
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom Padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}