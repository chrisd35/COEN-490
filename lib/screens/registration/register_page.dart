import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'account_profile_page.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('RegisterPage');

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
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
    _animationController.dispose();
    super.dispose();
  }
  
  // Navigation method
  void _navigateToProfile(String role, Map<String, dynamic>? args) {
    _logger.info('$role role selected');
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          AccountProfilePage(
            selectedRole: role,
            returnRoute: args?['returnRoute'],
            pendingAction: args?['pendingAction'],
          ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((result) {
      // This code runs after the future completes, but in a sync context
      if (mounted && result == true && args?['returnRoute'] == 'murmur_record') {
        _logger.info('Registration successful, returning to murmur record');
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // App theme colors for consistency
    const Color primaryColor = Color(0xFF1D557E);
    const Color secondaryColor = Color(0xFFE6EDF7);
    
    // Get the route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    return Scaffold(
      backgroundColor: secondaryColor, // Match login page background
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative element (circle) in top right - consistent with other screens
            Positioned(
              top: -80,
              right: -80,
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
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      
                      Expanded(
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF263238),
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 500.ms),
                      ),
                      
                      // Empty container to balance the back button
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          
                          // Header Section with refined typography
                          Text(
                            'Choose Your Role',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: -0.5,
                            ),
                          ).animate(controller: _animationController)
                            .fadeIn(duration: 500.ms, delay: 100.ms)
                            .slideY(begin: -0.2, end: 0),
                          
                          const SizedBox(height: 12),
                          
                          Text(
                            'Select the role that best describes you',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF546E7A),
                              fontWeight: FontWeight.w400,
                            ),
                          ).animate(controller: _animationController)
                            .fadeIn(duration: 500.ms, delay: 200.ms)
                            .slideY(begin: -0.1, end: 0),
                          
                          const SizedBox(height: 48),

                          // Medical Professional Card with enhanced design
                          _RoleCard(
                            title: 'Medical Professional',
                            description: 'Healthcare providers, doctors, and medical staff',
                            icon: Icons.medical_services_rounded,
                            color: primaryColor,
                            onTap: () => _navigateToProfile('Medical Professional', args),
                            delay: 300,
                          ),
                          
                          const SizedBox(height: 20),

                          // Student Card with enhanced design
                          _RoleCard(
                            title: 'Student',
                            description: 'Medical students and healthcare learners',
                            icon: Icons.school_rounded,
                            color: primaryColor,
                            onTap: () => _navigateToProfile('Student', args),
                            delay: 400,
                          ),
                        ],
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
}

// Redesigned Role Selection Card Widget
class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int delay;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withAlpha(26),
          highlightColor: color.withAlpha(13),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon container with refined styling
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(15),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Text content with refined typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF263238),
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF78909C),
                          height: 1.4,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon with refined styling
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: const Color(0xFFB0BEC5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay))
      .slideY(begin: 0.2, end: 0);
  }
}