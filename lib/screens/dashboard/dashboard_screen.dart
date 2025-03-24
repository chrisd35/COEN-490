import 'package:coen_490/screens/registration/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '/utils/ble_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '..//registration/firebase_service.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';


final _logger = logging.Logger('DashboardScreen');

// Design constants to maintain consistency throughout the app
class AppTheme {
  // Main color palette - refining the blue scheme and removing purple tones
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Status colors - we're keeping these standard but refining them slightly
  static const Color successColor = Color(0xFF2E7D32); // Darker green for better contrast
  static const Color warningColor = Color(0xFFF57F17); // Amber shade
  static const Color errorColor = Color(0xFFD32F2F);   // Dark red for better readability
  
  // Text colors - improved for readability
  static const Color textPrimary = Color(0xFF263238);   // Darker for better contrast
  static const Color textSecondary = Color(0xFF546E7A); // Medium dark for subtext
  static const Color textLight = Color(0xFF78909C);     // Light text for tertiary info
  
  // Card colors for feature cards - a cohesive blue-centric palette
  static final List<Color> featureCardColors = [
    const Color(0xFF1D557E),  // Primary blue
    const Color(0xFF2E86C1),  // Medium blue
    const Color(0xFF3498DB),  // Light blue
    const Color(0xFF0D47A1),  // Deep blue
    const Color(0xFF039BE5),  // Sky blue
    const Color(0xFF0097A7),  // Teal blue
    const Color(0xFF00796B),  // Teal green
  ];
  
  // Shadows - refined for better depth perception
  static final cardShadow = BoxShadow(
    color: Colors.black.withAlpha(18),  
    blurRadius: 12,
    spreadRadius: 0,
    offset: const Offset(0, 3),
  );
  
  static final subtleShadow = BoxShadow(
    color: Colors.black.withAlpha(10), 
    blurRadius: 6,
    spreadRadius: 0,
    offset: const Offset(0, 2),
  );
  
  // Text styles - improved for better readability
  static final TextStyle headingStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  static final TextStyle subheadingStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: -0.2,
    height: 1.4,
  );
  
  static final TextStyle cardTitleStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  static final TextStyle buttonTextStyle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );
  
  // Animation durations
  static const Duration defaultAnimDuration = Duration(milliseconds: 300);
  static const Duration quickAnimDuration = Duration(milliseconds: 150);
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
  
  // Apply system-wide UI settings for better text rendering
  static void applyOptimizedTextRendering() {
    // Set preferred text scale factor for better rendering
    // We don't need this method anymore since Paint.enableDithering is not available
    // This method is kept as a placeholder in case we want to add other text optimizations later
  }
}


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _wasConnected = false;
  final FirebaseService _firebaseService = FirebaseService();
  String _userName = '';
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

 @override
void initState() {
  super.initState();
  _loadUserName();
  _animationController = AnimationController(
    vsync: this,
    duration: AppTheme.defaultAnimDuration,
  );
  
  // Apply optimized text rendering
  AppTheme.applyOptimizedTextRendering();
}

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
      // Check if in guest mode
      final isGuest = await authService.isGuest();
      
      if (!mounted) return;
      
      if (isGuest) {
        setState(() {
          _userName = 'Guest';
        });
        return;
      }

      if (user != null) {
        final userData = await _firebaseService.getUser(user.uid, user.email ?? '');
        
        if (!mounted) return;
        
        if (userData != null) {
          setState(() {
            _userName = userData.fullName.split(' ')[0];
          });
        }
      }
    } catch (e) {
      _logger.warning('Error loading user name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleManager = Provider.of<BLEManager>(context, listen: true);
    final connectedDevice = bleManager.connectedDevice;
    final screenSize = MediaQuery.of(context).size;

    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.doubleTapToExit,
      snackBarMessage: 'Press back again to exit the app',
      child: Scaffold(
        backgroundColor: AppTheme.secondaryColor,
        body: SafeArea(
          child: Column(
            children: [
              // Redesigned App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [AppTheme.cardShadow],
                ),
                child: Row(
                  children: [
                    Text(
                      'Dashboard',
                      style: AppTheme.headingStyle,
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideX(begin: -0.2, end: 0),
                    const Spacer(),
                    // Logout Button with improved visual
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.logout_rounded, color: AppTheme.primaryColor),
                        tooltip: 'Logout',
                        onPressed: () => _showLogoutDialog(),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section with improved typography and layout
                       Container(
  margin: const EdgeInsets.only(bottom: 32),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _userName.isEmpty ? 'Welcome' : 'Hello, $_userName',
        style: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
          letterSpacing: -0.5,
          height: 1.2, // Improved line height
          shadows: [   // Add subtle text shadow for better readability
            Shadow(
              color: Colors.black.withAlpha(13),  
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: -0.2, end: 0),
      const SizedBox(height: 8),
      Text(
        'What would you like to do today?',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
          letterSpacing: -0.2,
          height: 1.4,
        ),
      ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: -0.1, end: 0),
    ],
  ),
),

                        // Redesigned BLE Connection Status Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppTheme.borderRadius,
                            boxShadow: [AppTheme.cardShadow],
                          ),
                          child: ClipRRect(
                            borderRadius: AppTheme.borderRadius,
                            child: connectedDevice != null
                              ? StreamBuilder<BluetoothConnectionState>(
                                  stream: bleManager.getDeviceState(connectedDevice),
                                  builder: (context, snapshot) {
                                    final isConnected = snapshot.data == BluetoothConnectionState.connected;

                                    if (!isConnected && _wasConnected) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _showDisconnectionDialog();
                                      });
                                      _wasConnected = false;
                                    } else if (isConnected) {
                                      _wasConnected = true;
                                    }

                                    return _buildConnectionStatus(
                                      isConnected: isConnected,
                                      deviceName: connectedDevice.platformName.isEmpty
                                          ? "Unknown Device"
                                          : connectedDevice.platformName,
                                    );
                                  },
                                )
                              : _buildConnectionStatus(
                                  isConnected: false,
                                  deviceName: "No device connected",
                                ),
                          ),
                        ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

                        // Section Title for Features
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16, left: 4),
                          child: Text(
                            'Features',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
                        ),

                        // Feature Grid with improved layout and responsiveness
                        FutureBuilder<bool>(
                          future: Provider.of<AuthService>(context, listen: false).isGuest(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                ).animate()
                                  .fadeIn(duration: 300.ms)
                                  .shimmer(delay: 1000.ms, duration: 1000.ms),
                              );
                            }

                            final isGuest = snapshot.data ?? false;
                            
                            // Responsive layout based on screen width
                            final crossAxisCount = screenSize.width > 600 ? 3 : 2;
                            
                            // Calculate appropriate aspect ratio for different screen sizes
                            final childAspectRatio = screenSize.width > 600 ? 1.3 : 1.1;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: isGuest ? 4 : 7,
                              itemBuilder: (context, index) {
                                // Determine which set of cards to use based on user type
                                final cards = isGuest
                                    ? _buildGuestFeatureCards()
                                    : _buildUserFeatureCards();
                                
                                if (index < cards.length) {
                                  // Add staggered animations to each card
                                  return cards[index]
                                    .animate()
                                    .fadeIn(
                                      duration: 400.ms, 
                                      delay: Duration(milliseconds: 600 + (index * 100))
                                    )
                                    .slideY(begin: 0.2, end: 0);
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUserFeatureCards() {
    final List<FeatureCardData> features = [
      FeatureCardData(
        title: 'Patient Folders',
        icon: Icons.folder_rounded,
        color: AppTheme.featureCardColors[0],
        route: AppRoutes.patientCard,
      ),
      FeatureCardData(
        title: 'AI Murmur',
        icon: Icons.analytics_rounded,
        color: AppTheme.featureCardColors[3],
        route: AppRoutes.murmurChart,
      ),
      FeatureCardData(
        title: 'Murmur Record',
        icon: Icons.mic_rounded,
        color: AppTheme.featureCardColors[6],
        route: AppRoutes.murmurRecord,
      ),
      FeatureCardData(
        title: 'View Recordings',
        icon: Icons.playlist_play,
        color: AppTheme.featureCardColors[4],
        onTap: () => _handleViewRecordings(),
      ),
      FeatureCardData(
        title: 'ECG Monitoring',
        icon: Icons.monitor_heart_outlined,
        color: AppTheme.featureCardColors[5],
        route: AppRoutes.ecgMonitoring,
      ),
      FeatureCardData(
        title: 'Oxygen Monitoring',
        icon: Icons.air,
        color: AppTheme.featureCardColors[2],
        route: AppRoutes.oxygenMonitoring,
      ),
      FeatureCardData(
        title: 'Learning Center',
        icon: Icons.school,
        color: AppTheme.featureCardColors[1],
        route: AppRoutes.learningCenter,
      ),
    ];
    
    return features.map((feature) => FeatureCard(
      title: feature.title,
      icon: feature.icon,
      color: feature.color,
      onTap: feature.onTap ?? () => NavigationService.navigateTo(feature.route!),
    )).toList();
  }

  List<Widget> _buildGuestFeatureCards() {
    final List<FeatureCardData> features = [
      FeatureCardData(
        title: 'Murmur Record',
        icon: Icons.mic_rounded,
        color: AppTheme.featureCardColors[6],
        route: AppRoutes.murmurRecord,
      ),
      FeatureCardData(
        title: 'ECG Monitoring',
        icon: Icons.monitor_heart_outlined,
        color: AppTheme.featureCardColors[5],
        route: AppRoutes.ecgMonitoring,
      ),
      FeatureCardData(
        title: 'Oxygen Monitoring',
        icon: Icons.air,
        color: AppTheme.featureCardColors[2],
        route: AppRoutes.oxygenMonitoring,
      ),
      FeatureCardData(
        title: 'View Recordings',
        icon: Icons.playlist_play,
        color: AppTheme.featureCardColors[3],
        onTap: () => _showPlaybackLoginPrompt(),
      ),
    ];
    
    return features.map((feature) => FeatureCard(
      title: feature.title,
      icon: feature.icon,
      color: feature.color,
      onTap: feature.onTap ?? () => NavigationService.navigateTo(feature.route!),
    )).toList();
  }

  Widget _buildConnectionStatus({required bool isConnected, required String deviceName}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(
        left: BorderSide(
          color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
          width: 6,
        ),
      ),
    ),
    child: Row(
      children: [
        // Status indicator
        AnimatedContainer(
          duration: AppTheme.defaultAnimDuration,
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
               color: (isConnected ? AppTheme.successColor : AppTheme.errorColor).withAlpha(77), 
                blurRadius: 6,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Status text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected ? 'Connected' : 'Not Connected',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
                  height: 1.3, // Improved line height
                ),
              ),
              if (deviceName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  deviceName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Redesigned Connect button - blue scheme with better visual design
        if (!isConnected)
          Container(
            decoration: BoxDecoration(
              borderRadius: AppTheme.buttonRadius,
              boxShadow: [AppTheme.subtleShadow],
            ),
            child: ClipRRect(
              borderRadius: AppTheme.buttonRadius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => NavigationService.navigateTo(AppRoutes.bleScreen),
                  splashColor: AppTheme.primaryColor.withAlpha(26),  
                  highlightColor: AppTheme.primaryColor.withAlpha(13),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          Color(0xFF23689B), // Slightly darker shade for depth
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connect',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
      ],
    ),
  );
}

  // Method to handle view recordings flow with async operations
  Future<void> _handleViewRecordings() async {
    if (!mounted) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final uid = user.uid;
      final patients = await _firebaseService.getPatientsForUser(uid);
      
      if (!mounted) return;
      
      if (patients.isEmpty) {
        _showSnackBar(
          'Create a patient and save a recording to access playback history',
          action: SnackBarAction(
            label: 'CREATE',
            onPressed: () => NavigationService.navigateTo(AppRoutes.patientCard),
          ),
        );
        return;
      }
      
      NavigationService.navigateTo(AppRoutes.recordingPlayback);
    } catch (e) {
      if (!mounted) return;
      
      _showSnackBar(
        'Failed to check recordings: $e',
        isError: true,
      );
    }
  }

  // Redesigned SnackBar
  void _showSnackBar(String message, {SnackBarAction? action, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Redesigned disconnection dialog with improved visual appeal
  void _showDisconnectionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26), 
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withAlpha(26), 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled_rounded,
                      color: AppTheme.errorColor,
                      size: 50,
                    ).animate().shake(duration: 700.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Lost',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Please reconnect your device to continue monitoring.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Later',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          NavigationService.navigateTo(AppRoutes.bleScreen);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Connect',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Redesigned logout dialog
  Future<void> _showLogoutDialog() async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final isGuest = await authService.isGuest();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26), 
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGuest ? Icons.person_off_outlined : Icons.logout_rounded,
                size: 40,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                isGuest ? 'Exit Guest Mode' : 'Logout',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isGuest 
                  ? 'Are you sure you want to exit guest mode?' 
                  : 'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          Navigator.pop(dialogContext); // Close dialog
                          if (isGuest) {
                            // Simply navigate back to auth page for guests
                            NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                          } else {
                            // Full logout for registered users
                            await authService.logout();
                            NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                          }
                        } catch (e) {
                          if (!mounted) return;
                          
                          _showSnackBar(
                            'Error logging out. Please try again.',
                            isError: true,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isGuest ? 'Exit' : 'Logout',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
  }
// Redesigned playback login prompt
  void _showPlaybackLoginPrompt() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26), 
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Login Required',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You need to be logged in to view recorded murmurs.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          NavigationService.navigateTo(
                            AppRoutes.login,
                            arguments: {
                              'returnRoute': 'recording_playback',
                              'pendingAction': 'view_recordings',
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }
}

// Helper class to store feature card data
class FeatureCardData {
  final String title;
  final IconData icon;
  final Color color;
  final String? route;
  final Function()? onTap;

  FeatureCardData({
    required this.title,
    required this.icon,
    required this.color,
    this.route,
    this.onTap,
  }) : assert(route != null || onTap != null, 'Either route or onTap must be provided');
}

// Redesigned Feature Card
class FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppTheme.subtleShadow],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withAlpha(26), 
          highlightColor: color.withAlpha(13),  
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon container with refined styling
                AnimatedContainer(
                  duration: AppTheme.defaultAnimDuration,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(26),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28, // Slightly smaller for better proportion
                    color: color,
                  ),
                ),
                const SizedBox(height: 16),
                // Improved text rendering for better readability
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
